import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product.dart';
import '../models/nota.dart';
import '../models/settings.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'nota_tulis.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL,
            name TEXT NOT NULL,
            price REAL NOT NULL,
            category TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE notas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL,
            number TEXT NOT NULL,
            customerName TEXT,
            date INTEGER NOT NULL,
            items TEXT NOT NULL,
            total REAL NOT NULL,
            bayarTunai REAL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            storeName TEXT,
            address TEXT,
            phone TEXT,
            logo TEXT,
            showLogo INTEGER NOT NULL DEFAULT 1,
            headerText TEXT,
            footerText TEXT,
            paperSize TEXT NOT NULL DEFAULT '58',
            printerId TEXT,
            printerName TEXT,
            lastNotaNumber INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  // ---------------- Settings ----------------

  Future<Settings> ensureSettingsExist() async {
    final db = await database;
    final rows = await db.query('settings', limit: 1);
    if (rows.isNotEmpty) return Settings.fromMap(rows.first);
    final defaults = Settings.defaults();
    final id = await db.insert('settings', defaults.toMap()..remove('id'));
    return Settings.fromMap({...defaults.toMap(), 'id': id});
  }

  Future<Settings> getSettings() async {
    return ensureSettingsExist();
  }

  Future<void> updateSettings(int id, Map<String, dynamic> patch) async {
    final db = await database;
    await db.update('settings', patch, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceAllSettings(List<Map<String, dynamic>> rows) async {
    final db = await database;
    await db.delete('settings');
    for (final row in rows) {
      final copy = Map<String, dynamic>.from(row)..remove('id');
      await db.insert('settings', copy);
    }
  }

  // ---------------- Products ----------------

  Future<List<Product>> searchProducts(String query, {int limit = 5}) async {
    final db = await database;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final rows = await db.query('products');
    final all = rows.map((r) => Product.fromMap(r)).toList();
    final filtered = all.where((p) => p.name.toLowerCase().contains(q)).toList();
    filtered.sort((a, b) {
      final aStarts = a.name.toLowerCase().startsWith(q) ? 0 : 1;
      final bStarts = b.name.toLowerCase().startsWith(q) ? 0 : 1;
      if (aStarts != bStarts) return aStarts - bStarts;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return filtered.take(limit).toList();
  }

  Future<Product?> findProductByName(String name) async {
    final db = await database;
    final rows = await db.query(
      'products',
      where: 'LOWER(TRIM(name)) = ?',
      whereArgs: [name.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<void> upsertProduct(Product product) async {
    final db = await database;
    if (product.id != null) {
      await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
    } else {
      await db.insert('products', product.toMap()..remove('id'));
    }
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final rows = await db.query('products', orderBy: 'name ASC');
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  Future<void> replaceAllProducts(List<Map<String, dynamic>> rows) async {
    final db = await database;
    await db.delete('products');
    for (final row in rows) {
      final copy = Map<String, dynamic>.from(row)..remove('id');
      await db.insert('products', copy);
    }
  }

  // ---------------- Notas ----------------

  Future<String> nextNotaNumber() async {
    final settings = await ensureSettingsExist();
    final next = settings.lastNotaNumber + 1;
    await updateSettings(settings.id!, {'lastNotaNumber': next});
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'NT-$datePart-${next.toString().padLeft(4, '0')}';
  }

  Future<Nota> insertNota(Nota nota) async {
    final db = await database;
    final id = await db.insert('notas', nota.toMap()..remove('id'));
    return nota.copyWith(id: id);
  }

  Future<void> updateNota(int id, Nota nota) async {
    final db = await database;
    await db.update('notas', nota.toMap(), where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteNota(int id) async {
    final db = await database;
    await db.delete('notas', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllNotas() async {
    final db = await database;
    await db.delete('notas');
  }

  Future<List<Nota>> searchNotas({String search = '', int? dateFrom, int? dateTo}) async {
    final db = await database;
    final rows = await db.query('notas', orderBy: 'date DESC');
    var all = rows.map((r) => Nota.fromMap(r)).toList();

    if (dateFrom != null) all = all.where((n) => n.date >= dateFrom).toList();
    if (dateTo != null) all = all.where((n) => n.date <= dateTo).toList();

    if (search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      all = all
          .where((n) =>
              n.number.toLowerCase().contains(q) ||
              n.items.any((i) => i.name.toLowerCase().contains(q)))
          .toList();
    }
    return all;
  }

  Future<List<Nota>> getNotasFrom(int startTimestamp) async {
    final db = await database;
    final rows = await db.query(
      'notas',
      where: 'date >= ?',
      whereArgs: [startTimestamp],
    );
    return rows.map((r) => Nota.fromMap(r)).toList();
  }

  Future<List<Nota>> getAllNotas() async {
    final db = await database;
    final rows = await db.query('notas', orderBy: 'date DESC');
    return rows.map((r) => Nota.fromMap(r)).toList();
  }

  Future<void> replaceAllNotas(List<Map<String, dynamic>> rows) async {
    final db = await database;
    await db.delete('notas');
    for (final row in rows) {
      final copy = Map<String, dynamic>.from(row)..remove('id');
      await db.insert('notas', copy);
    }
  }
}
