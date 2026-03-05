import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static bool _webInitialized = false;
  static final List<Map<String, dynamic>> _webProducts = [];
  static final List<Map<String, dynamic>> _webCartItems = [];
  static final List<Map<String, dynamic>> _webCards = [];
  static final List<Map<String, dynamic>> _webOrders = [];
  static final List<Map<String, dynamic>> _webPayments = [];

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('checkout.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onOpen: (db) async {
        await _seed(db);
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,price REAL NOT NULL)');
    await db.execute('CREATE TABLE cart_items(id INTEGER PRIMARY KEY AUTOINCREMENT,product_id INTEGER NOT NULL,qty INTEGER NOT NULL,FOREIGN KEY(product_id) REFERENCES products(id))');
    await db.execute('CREATE TABLE cards(id INTEGER PRIMARY KEY AUTOINCREMENT,holder TEXT NOT NULL,brand TEXT,last4 TEXT,exp_month INTEGER,exp_year INTEGER)');
    await db.execute('CREATE TABLE orders(id INTEGER PRIMARY KEY AUTOINCREMENT,total REAL NOT NULL,created_at TEXT NOT NULL)');
    await db.execute('CREATE TABLE payments(id INTEGER PRIMARY KEY AUTOINCREMENT,order_id INTEGER NOT NULL,method TEXT NOT NULL,card_id INTEGER,promo_code TEXT,amount REAL NOT NULL,FOREIGN KEY(order_id) REFERENCES orders(id),FOREIGN KEY(card_id) REFERENCES cards(id))');
  }

  Future<void> _seed(Database db) async {
    final pCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products')) ?? 0;
    if (pCount == 0) {
      await db.insert('products', {'name': 'Sneakers', 'price': 1140.0});
      await db.insert('products', {'name': 'Jacket', 'price': 350.0});
      await db.insert('products', {'name': 'T-Shirt', 'price': 90.0});
    }
    final cCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM cart_items')) ?? 0;
    if (cCount == 0) {
      final sneakersId = Sqflite.firstIntValue(await db.rawQuery('SELECT id FROM products WHERE name=? LIMIT 1', ['Sneakers'])) ?? 1;
      await db.insert('cart_items', {'product_id': sneakersId, 'qty': 2});
    }
  }

  Future<int> insertProduct(Map<String, dynamic> row) async {
    if (kIsWeb) {
      _ensureWebInit();
      final id = (_webProducts.isNotEmpty ? (_webProducts.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b)) : 0) + 1;
      final record = {'id': id, ...row};
      _webProducts.add(record);
      return id;
    } else {
      final db = await instance.database;
      return await db.insert('products', row);
    }
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      if (kIsWeb) {
        _ensureWebInit();
        return List<Map<String, dynamic>>.from(_webProducts);
      } else {
        final db = await instance.database;
        return await db.query('products');
      }
    } catch (_) {
      _ensureWebInit();
      return List<Map<String, dynamic>>.from(_webProducts);
    }
  }

  Future<double> getCartTotal() async {
    if (kIsWeb) {
      _ensureWebInit();
      double t = 0;
      for (final c in _webCartItems) {
        final pid = c['product_id'] as int;
        final qty = c['qty'] as int;
        final p = _webProducts.firstWhere((e) => e['id'] == pid);
        t += (p['price'] as num).toDouble() * qty;
      }
      return t;
    } else {
      final db = await instance.database;
      final res = await db.rawQuery('SELECT SUM(p.price * c.qty) AS total FROM cart_items c JOIN products p ON c.product_id=p.id');
      final total = (res.first['total'] as num?)?.toDouble() ?? 0.0;
      return total;
    }
  }
  Future<List<Map<String, dynamic>>> getCartItemsDetailed() async {
    if (kIsWeb) {
      _ensureWebInit();
      return _webCartItems.map((c) {
        final p = _webProducts.firstWhere((e) => e['id'] == c['product_id']);
        return {
          'id': c['id'],
          'product_id': p['id'],
          'name': p['name'],
          'price': p['price'],
          'qty': c['qty'],
        };
      }).toList();
    } else {
      final db = await instance.database;
      return await db.rawQuery('SELECT c.id,p.id AS product_id,p.name,p.price,c.qty FROM cart_items c JOIN products p ON c.product_id=p.id');
    }
  }
  Future<void> clearCart() async {
    if (kIsWeb) {
      _ensureWebInit();
      _webCartItems.clear();
      return;
    } else {
      final db = await instance.database;
      await db.delete('cart_items');
    }
  }
  Future<void> setCartItems(List<Map<String, int>> items) async {
    if (kIsWeb) {
      _ensureWebInit();
      _webCartItems.clear();
      int id = 1;
      for (final it in items) {
        final pid = it['product_id'] ?? 0;
        final qty = it['qty'] ?? 0;
        if (pid > 0 && qty > 0) {
          _webCartItems.add({'id': id++, 'product_id': pid, 'qty': qty});
        }
      }
      return;
    } else {
      final db = await instance.database;
      await db.transaction((txn) async {
        await txn.delete('cart_items');
        for (final it in items) {
          final pid = it['product_id'] ?? 0;
          final qty = it['qty'] ?? 0;
          if (pid > 0 && qty > 0) {
            await txn.insert('cart_items', {'product_id': pid, 'qty': qty});
          }
        }
      });
    }
  }

  Future<int> saveCard({required String holder, required String brand, required String last4, required int expMonth, required int expYear}) async {
    if (kIsWeb) {
      _ensureWebInit();
      final id = (_webCards.isNotEmpty ? (_webCards.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b)) : 0) + 1;
      _webCards.add({
        'id': id,
        'holder': holder,
        'brand': brand,
        'last4': last4,
        'exp_month': expMonth,
        'exp_year': expYear,
      });
      return id;
    } else {
      final db = await instance.database;
      return await db.insert('cards', {
        'holder': holder,
        'brand': brand,
        'last4': last4,
        'exp_month': expMonth,
        'exp_year': expYear,
      });
    }
  }

  Future<Map<String, Object?>?> getLastCard() async {
    if (kIsWeb) {
      _ensureWebInit();
      if (_webCards.isEmpty) return null;
      _webCards.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
      return _webCards.first;
    } else {
      final db = await instance.database;
      final res = await db.query('cards', orderBy: 'id DESC', limit: 1);
      return res.isEmpty ? null : res.first;
    }
  }

  Future<int> createOrderWithPayment({required double amount, required String method, int? cardId, String? promoCode}) async {
    if (kIsWeb) {
      _ensureWebInit();
      final orderId = (_webOrders.isNotEmpty ? (_webOrders.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b)) : 0) + 1;
      final now = DateTime.now().toIso8601String();
      _webOrders.add({'id': orderId, 'total': amount, 'created_at': now});
      final paymentId = (_webPayments.isNotEmpty ? (_webPayments.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b)) : 0) + 1;
      _webPayments.add({'id': paymentId, 'order_id': orderId, 'method': method, 'card_id': cardId, 'promo_code': promoCode, 'amount': amount});
      return orderId;
    } else {
      final db = await instance.database;
      final now = DateTime.now().toIso8601String();
      final orderId = await db.insert('orders', {'total': amount, 'created_at': now});
      await db.insert('payments', {
        'order_id': orderId,
        'method': method,
        'card_id': cardId,
        'promo_code': promoCode,
        'amount': amount,
      });
      return orderId;
    }
  }

  void _ensureWebInit() {
    if (_webInitialized) return;
    _webProducts.addAll([
      {'id': 1, 'name': 'Sneakers', 'price': 1140.0},
      {'id': 2, 'name': 'Jacket', 'price': 350.0},
      {'id': 3, 'name': 'T-Shirt', 'price': 90.0},
    ]);
    _webCartItems.add({'id': 1, 'product_id': 1, 'qty': 2});
    _webInitialized = true;
  }
}
