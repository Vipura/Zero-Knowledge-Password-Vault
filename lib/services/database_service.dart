import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/password_entry.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('vault.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE config (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE vault (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        username TEXT NOT NULL,
        ciphertext TEXT NOT NULL,
        nonce TEXT NOT NULL,
        mac TEXT NOT NULL
      )
    ''');
  }

  Future<void> saveSalt(List<int> salt) async {
    final db = await instance.database;
    await db.insert('config', {'key': 'app_salt', 'value': base64Encode(salt)}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<int>?> getSalt() async {
    final db = await instance.database;
    final results = await db.query('config', where: 'key = ?', whereArgs: ['app_salt']);
    if (results.isNotEmpty) return base64Decode(results.first['value'] as String);
    return null;
  }

  Future<void> saveConfig(String key, String value) async {
    final db = await instance.database;
    await db.insert('config', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getConfig(String key) async {
    final db = await instance.database;
    final results = await db.query('config', where: 'key = ?', whereArgs: [key]);
    if (results.isNotEmpty) return results.first['value'] as String;
    return null;
  }

  Future<PasswordEntry> create(PasswordEntry entry) async {
    final db = await instance.database;
    final id = await db.insert('vault', entry.toMap());
    return PasswordEntry(
      id: id,
      title: entry.title,
      username: entry.username,
      ciphertext: entry.ciphertext,
      nonce: entry.nonce,
      mac: entry.mac,
    );
  }

  Future<List<PasswordEntry>> readAllEntries() async {
    final db = await instance.database;
    final result = await db.query('vault', orderBy: 'title ASC');
    return result.map((map) => PasswordEntry.fromMap(map)).toList();
  }

  Future<int> update(PasswordEntry entry) async {
    final db = await instance.database;
    return await db.update('vault', entry.toMap(), where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete('vault', where: 'id = ?', whereArgs: [id]);
  }
}
