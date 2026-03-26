import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../widgets/chat_interface.dart';

class ChatHistoryDatabase {
  static const _databaseName = 'chat_history.db';
  static const _databaseVersion = 1;
  static const _tableName = 'messages';

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = p.join(documentsDirectory.path, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT NOT NULL,
            is_user INTEGER NOT NULL,
            timestamp TEXT NOT NULL,
            text_color INTEGER
          )
        ''');
      },
    );
  }

  Future<void> insertMessage(ChatMessage message) async {
    final db = await database;
    await db.insert(_tableName, {
      'text': message.text,
      'is_user': message.isUser ? 1 : 0,
      'timestamp': message.timestamp.toIso8601String(),
      'text_color': message.textColor?.toARGB32(),
    });
  }

  Future<List<ChatMessage>> getMessages() async {
    final db = await database;
    final rows = await db.query(_tableName, orderBy: 'id ASC');

    return rows.map((row) {
      final colorValue = row['text_color'] as int?;

      return ChatMessage(
        text: row['text'] as String,
        isUser: (row['is_user'] as int) == 1,
        timestamp: DateTime.parse(row['timestamp'] as String),
        textColor: colorValue != null ? Color(colorValue) : null,
      );
    }).toList();
  }

  Future<void> clearMessages() async {
    final db = await database;
    await db.delete(_tableName);
  }
}
