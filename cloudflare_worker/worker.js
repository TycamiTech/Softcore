/**
 * Softcore Cloudflare Audio Relay Worker
 * Bertindak sebagai stream relay & proxy cerdas antara ExoPlayer HP dan YouTube CDN.
 * Mendukung Range request (HTTP 206 Partial Content), mem-bypass silent throttling & CORS.
 */

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Tangani Preflight CORS
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
          'Access-Control-Allow-Headers': '*',
        },
      });
    }

    // Health check endpoint
    if (url.pathname === '/' || url.pathname === '/health') {
      return new Response(JSON.stringify({ status: 'ok', service: 'Softcore Audio Relay' }), {
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      });
    }

    // Endpoint 1: Relay audio stream langsung dari URL googlevideo
    // Contoh pemanggilan: https://worker.workers.dev/relay?url=<encoded_googlevideo_url>
    if (url.pathname === '/relay') {
      const targetUrl = url.searchParams.get('url');
      if (!targetUrl) {
        return new Response('Missing "url" query parameter', { status: 400 });
      }

      try {
        const decodedUrl = decodeURIComponent(targetUrl);
        const rangeHeader = request.headers.get('Range') || 'bytes=0-';

        const forwardHeaders = new Headers();
        forwardHeaders.set('User-Agent', 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36');
        forwardHeaders.set('Range', rangeHeader);
        forwardHeaders.set('Accept', '*/*');
        forwardHeaders.set('Accept-Encoding', 'identity');

        const response = await fetch(decodedUrl, {
          method: 'GET',
          headers: forwardHeaders,
          redirect: 'follow',
        });

        const responseHeaders = new Headers(response.headers);
        responseHeaders.set('Access-Control-Allow-Origin', '*');
        responseHeaders.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
        responseHeaders.set('Access-Control-Expose-Headers', 'Content-Range, Content-Length, Accept-Ranges');
        responseHeaders.set('Cache-Control', 'public, max-age=3600');

        return new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers: responseHeaders,
        });
      } catch (err) {
        return new Response('Relay error: ' + err.message, { status: 500 });
      }
    }

    return new Response('Endpoint not found', { status: 404 });
  },
};
