import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'finance.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _ensureSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _ensureSchema(db);
      },
      onOpen: (db) async {
        await _ensureSchema(db);
      },
    );
  }

  static Future<void> _ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    final columnsInfo = await db.rawQuery('PRAGMA table_info(transactions)');
    final existingColumns = columnsInfo
        .map((c) => (c['name'] ?? '').toString())
        .toSet();

    if (!existingColumns.contains('type')) {
      await db.execute(
        "ALTER TABLE transactions ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'",
      );
    }

    if (!existingColumns.contains('category')) {
      await db.execute(
        "ALTER TABLE transactions ADD COLUMN category TEXT NOT NULL DEFAULT 'Otros'",
      );
    }

    if (!existingColumns.contains('date')) {
      await db.execute(
        "ALTER TABLE transactions ADD COLUMN date TEXT NOT NULL DEFAULT '2026-01-01T00:00:00.000'",
      );
    }
  }
  static Future<int> insertTransaction(AppTransaction t) async {
    final db = await database;
    return db.insert('transactions', t.toMap());
  }

  static Future<List<AppTransaction>> getTransactions() async {
    final db = await database;
    final maps = await db.query('transactions', orderBy: 'date DESC');
    return maps.map((m) => AppTransaction.fromMap(m)).toList();
  }

  static Future<int> deleteTransaction(int id) async {
    final db = await database;
    return db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }
}
