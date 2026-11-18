

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

class HistoryService {
  HistoryService._();

  static final HistoryService instance = HistoryService._();

  static const String _databaseName = 'inkora_history.db';
  static const int _databaseVersion = 1;
  static const String _tableName = 'history';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final databasePath = await getDatabasesPath();
    final fullPath = p.join(databasePath, _databaseName);

    _database = await openDatabase(
      fullPath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            pageCount INTEGER,
            wordPath TEXT,
            pdfPath TEXT,
            score REAL,
            feedback TEXT
          )
        ''');

        await db.execute('''
          CREATE INDEX history_createdAt_index
          ON history(createdAt)
        ''');
      },
    );

    return _database!;
  }

  Future<int> saveConversion({
    required String title,
    required int pageCount,
    required String wordPath,
    required String pdfPath,
  }) async {
    final db = await database;

    return db.insert(_tableName, {
      'type': 'conversion',
      'title': title,
      'createdAt': DateTime.now().toIso8601String(),
      'pageCount': pageCount,
      'wordPath': wordPath,
      'pdfPath': pdfPath,
    });
  }
  Future<int> saveEvaluation({
    required String title,
    required String pdfPath,
    required double score,
    required String feedback,
  }) async {
    final db = await database;

    return db.insert(_tableName, {
      'type': 'evaluation',
      'title': title,
      'createdAt': DateTime.now().toIso8601String(),
      'pdfPath': pdfPath,
      'score': score,
      'feedback': feedback,
    });
  }
  Future<void> deleteEvaluationItem(int id) async {
    final db = await database;

    final records = await db.query(
      _tableName,
      columns: ['type', 'pdfPath'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (records.isEmpty) return;

    final record = records.first;

    if (record['type'] != 'evaluation') {
      throw StateError('This record is not an evaluation.');
    }

    final pdfPath = record['pdfPath'] as String?;

    // Delete the PDF if it exists.
    if (pdfPath != null && pdfPath.isNotEmpty) {
      final pdfFile = File(pdfPath);

      if (await pdfFile.exists()) {
        await pdfFile.delete();
      }
    }

    // Delete the database record after file deletion.
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }


  Future<List<Map<String, Object?>>> getHistory({
    String filter = 'all',
    String searchQuery = '',
  }) async {
    final db = await database;

    final conditions = <String>[];
    final arguments = <Object?>[];

    if (filter != 'all') {
      conditions.add('type = ?');
      arguments.add(filter);
    }

    final query = searchQuery.trim();
    if (query.isNotEmpty) {
      conditions.add('title LIKE ?');
      arguments.add('%$query%');
    }

    return db.query(
      _tableName,
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'createdAt DESC, id DESC',
    );
  }


  Future<void> deleteHistoryItem(int id) async {
    final db = await database;

    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete(_tableName);
  }
}
