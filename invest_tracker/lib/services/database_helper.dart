// lib/services/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
// Importamos nuestro modelo con el prefijo 'model'
import '../models/transaction.dart' as model;

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;
  static const _databaseName = "investment_db.db";
  static const _databaseVersion = 1;

  DatabaseHelper._privateConstructor();

  // Getter para la base de datos
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // --- AGREGA O MODIFICA ESTA FUNCIÓN ---
  Future<void> closeDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null; // ¡ESTO ES CRÍTICO!
      // Si no hacemos esto null, la app cree que sigue abierta y falla al reabrir.
    }
  }

  // Inicializa la base de datos
  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName); // Usar join para seguridad
    // String path = join(await getDatabasesPath(), 'investments.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  // Crea la tabla de transacciones
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
CREATE TABLE transactions(
id INTEGER PRIMARY KEY AUTOINCREMENT,
assetName TEXT,
type INTEGER,
price REAL,
quantity REAL,
totalValue REAL,
date TEXT
)
''');
  }

  // --- Operaciones CRUD ---

  // CREATE: Insertar una nueva transacción
  Future<int> insertTransaction(model.Transaction transaction) async {
    // <-- CORREGIDO: Añadido 'model.'
    Database db = await instance.database;
    return await db.insert(
      'transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // READ: Obtener todas las transacciones
  Future<List<model.Transaction>> getAllTransactions() async {
    // <-- CORREGIDO: Añadido 'model.'
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return model.Transaction.fromMap(
        maps[i],
      ); // <-- CORREGIDO: Añadido 'model.'
    });
  }

  // UPDATE: Actualizar una transacción
  Future<int> updateTransaction(model.Transaction transaction) async {
    // <-- CORREGIDO: Añadido 'model.'
    Database db = await instance.database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  // DELETE: Eliminar una transacción
  Future<int> deleteTransaction(int id) async {
    Database db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Leer nombres de activos únicos para autocompletar/lista de proventos
  Future<List<String>> getUniqueAssetNames() async {
    Database db = await instance.database;
    // Selecciona solo los nombres de activos distintos de las COMPRAS
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT assetName FROM transactions WHERE type = ?',
      [model.TransactionType.purchase.index], // <-- CORREGIDO: Añadido 'model.'
    );

    return maps.map((map) => map['assetName'] as String).toList();
  }
}
