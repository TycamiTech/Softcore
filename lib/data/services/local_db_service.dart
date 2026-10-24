import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/track_model.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'softcore_music.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tabel Lagu Favorit
        await db.execute('''
          CREATE TABLE favorites (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            album TEXT,
            durationMs INTEGER,
            artworkUrl TEXT,
            youtubeVideoId TEXT NOT NULL,
            createdAt INTEGER NOT NULL
          )
        ''');

        // Tabel Riwayat Lagu yang Baru Diputar (Recently Played)
        await db.execute('''
          CREATE TABLE recently_played (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            album TEXT,
            durationMs INTEGER,
            artworkUrl TEXT,
            youtubeVideoId TEXT NOT NULL,
            playedAt INTEGER NOT NULL
          )
        ''');

        // Tabel Riwayat Pencarian
        await db.execute('''
          CREATE TABLE search_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            query TEXT UNIQUE NOT NULL,
            searchedAt INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // ==========================
  // FAVORITES OPERATIONS
  // ==========================

  Future<List<TrackModel>> getFavorites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favorites',
      orderBy: 'createdAt DESC',
    );

    return maps.map((map) => _trackFromMap(map)).toList();
  }

  Future<void> saveFavorite(TrackModel track) async {
    final db = await database;
    await db.insert(
      'favorites',
      {
        'id': track.id,
        'title': track.title,
        'artist': track.artist,
        'album': track.album,
        'durationMs': track.duration.inMilliseconds,
        'artworkUrl': track.artworkUrl,
        'youtubeVideoId': track.youtubeVideoId,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(String trackId) async {
    final db = await database;
    await db.delete(
      'favorites',
      where: 'id = ?',
      whereArgs: [trackId],
    );
  }

  Future<bool> isFavorite(String trackId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favorites',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [trackId],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // ==========================
  // RECENTLY PLAYED OPERATIONS
  // ==========================

  Future<List<TrackModel>> getRecentlyPlayed({int limit = 30}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'recently_played',
      orderBy: 'playedAt DESC',
      limit: limit,
    );

    return maps.map((map) => _trackFromMap(map)).toList();
  }

  Future<void> addRecentlyPlayed(TrackModel track) async {
    final db = await database;
    await db.insert(
      'recently_played',
      {
        'id': track.id,
        'title': track.title,
        'artist': track.artist,
        'album': track.album,
        'durationMs': track.duration.inMilliseconds,
        'artworkUrl': track.artworkUrl,
        'youtubeVideoId': track.youtubeVideoId,
        'playedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearRecentlyPlayed() async {
    final db = await database;
    await db.delete('recently_played');
  }

  // ==========================
  // SEARCH HISTORY OPERATIONS
  // ==========================

  Future<List<String>> getSearchHistory({int limit = 10}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'search_history',
      columns: ['query'],
      orderBy: 'searchedAt DESC',
      limit: limit,
    );
    return maps.map((m) => m['query'] as String).toList();
  }

  Future<void> addSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final db = await database;
    await db.insert(
      'search_history',
      {
        'query': trimmed,
        'searchedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearSearchHistory() async {
    final db = await database;
    await db.delete('search_history');
  }

  // Helper
  TrackModel _trackFromMap(Map<String, dynamic> map) {
    return TrackModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      artist: map['artist'] as String? ?? '',
      album: map['album'] as String? ?? 'Unknown Album',
      duration: Duration(milliseconds: map['durationMs'] as int? ?? 0),
      artworkUrl: map['artworkUrl'] as String? ?? '',
      youtubeVideoId: map['youtubeVideoId'] as String? ?? map['id'] as String? ?? '',
    );
  }
}
