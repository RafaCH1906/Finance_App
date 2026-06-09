import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction.dart';

class DBHelper {
  static const List<String> defaultCategories = [
    'Comida',
    'Transporte',
    'Entretenimiento',
    'Salud',
    'Educación',
    'Servicios',
    'Ropa',
  ];

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
      version: 3,
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        is_custom INTEGER NOT NULL DEFAULT 0
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

    await _ensureDefaultCategories(db);
  }

  static Future<void> _ensureDefaultCategories(Database db) async {
    for (final category in defaultCategories) {
      await db.insert(
        'categories',
        {'name': category, 'is_custom': 0},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static Future<List<String>> getSavedCategories() async {
    final db = await database;
    final rows = await db.query(
      'categories',
      columns: ['name'],
      where: 'is_custom = ?',
      whereArgs: [1],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map((row) => row['name'].toString()).toList();
  }

  static Future<String?> addCustomCategory(String categoryName) async {
    final normalized = categoryName.trim();
    if (normalized.isEmpty) return null;

    final db = await database;
    await db.insert(
      'categories',
      {'name': normalized, 'is_custom': 1},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    final rows = await db.query(
      'categories',
      columns: ['name'],
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [normalized],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['name'].toString();
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
