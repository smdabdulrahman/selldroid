import 'dart:async';
import 'package:path/path.dart';
import 'package:selldroid/models/general_models.dart';
import 'package:selldroid/models/preference_model.dart';
import 'package:selldroid/models/sale.dart';
import 'package:selldroid/models/shop.dart';
import 'package:selldroid/models/sold_item.dart';
import 'package:selldroid/models/stock_item.dart';
// Note: Ensure PurchaseItem is in general_models.dart or imported separately
// import 'package:selldroid/models/purchase_item.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const _databaseName = "SellDroid.db";
  static const _databaseVersion = 5;

  // --- Table Names ---
  static const tableShopDetails = 'shop_details';
  static const tablePreferences = 'preferences';
  static const tableStockItems = 'stock_items';
  static const tableSales = 'sales';
  static const tableStockSalesItems = 'stock_sales_items';
  static const tableCashMode = 'cash_mode';
  static const tableExpensesList = 'expenses_list';
  static const tableCustomer = 'customer';
  static const tablePrinter = 'printer';
  static const tableCurrency = 'currency';

  // UPDATED: Changed from purchaser_info to supplier_info
  static const tableSupplierInfo = 'supplier_info';
  static const tablePurchases = 'purchases';
  static const tablePurchaseItems = 'purchase_items'; // New Table
  static const tableExpenses = 'expenses';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    // 1. Shop Details
    await db.execute('''
      CREATE TABLE $tableShopDetails (
        id INTEGER PRIMARY KEY,
        name TEXT,
        address TEXT,
        city TEXT,
        state TEXT,
        logo TEXT,
        phone_number TEXT,
        upi_id TEXT
      )
    ''');

    // 2. Preferences
    await db.execute('''
      CREATE TABLE $tablePreferences (
        id INTEGER PRIMARY KEY,
        include_gst INTEGER,
        is_gst_inclusive INTEGER,
        manage_stock INTEGER
      )
    ''');

    // 3. Stock Items
    await db.execute('''
      CREATE TABLE $tableStockItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        item_name TEXT, 
        selling_price INTEGER, 
        cost_price INTEGER, 
        stock_qty INTEGER,
        igst REAL,
        sgst REAL,
        cgst REAL
      )
    ''');

    // 4. Sales Header
    await db.execute('''
      CREATE TABLE $tableSales (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        customer_id INTEGER, 
        total_amount INTEGER, 
        gst_amount INTEGER, 
        discount_amount INTEGER, 
        final_amount INTEGER, 
        paid INTEGER, 
        is_stock_sales INTEGER, 
        payment_mode TEXT,
        billed_date TEXT,
        last_payment_date TEXT
      )
    ''');

    // 5. Sold Items
    await db.execute('''
      CREATE TABLE $tableStockSalesItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        sales_id INTEGER, 
        item_name TEXT, 
        qty INTEGER, 
        amount REAL,
        igst REAL,
        sgst REAL,
        cgst REAL
      )
    ''');

    // 6. Purchases (Updated with full bill details & supplier_info_id)
    await db.execute('''
      CREATE TABLE $tablePurchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        supplier_info_id INTEGER, 
        tot_amount INTEGER, 
        gst_amount INTEGER, 
        discount INTEGER, 
        final_amount INTEGER, 
        paid INTEGER, 
        payment_mode TEXT, 
        purchased_date TEXT, 
        last_payment_date TEXT
      )
    ''');

    // 7. Purchase Items (New Table)
    await db.execute('''
      CREATE TABLE $tablePurchaseItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        purchase_id INTEGER, 
        item_name TEXT, 
        qty INTEGER, 
        amount REAL,
        gst_rate REAL,
        gst_amount REAL
      )
    ''');

    // 8. Supplier Info (Updated table name & added state)
    await db.execute('''
      CREATE TABLE $tableSupplierInfo (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT, 
        balance INTEGER, 
        state TEXT
      )
    ''');

    // 9. Customer (Added state)
    await db.execute('''
      CREATE TABLE $tableCustomer (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT, 
        phone_number TEXT, 
        state TEXT
      )
    ''');

    // 10. Simple Tables
    await db.execute(
      'CREATE TABLE $tableExpenses (id INTEGER PRIMARY KEY AUTOINCREMENT, category TEXT, date TEXT, description TEXT, amount INTEGER)',
    );
    await db.execute(
      'CREATE TABLE $tableCashMode (id INTEGER PRIMARY KEY AUTOINCREMENT, cash_modes TEXT)',
    );
    await db.execute(
      'CREATE TABLE $tableExpensesList (id INTEGER PRIMARY KEY AUTOINCREMENT, expense_type TEXT)',
    );
    await db.execute(
      'CREATE TABLE $tablePrinter (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, width INTEGER)',
    );
    await db.execute(
      'CREATE TABLE $tableCurrency (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)',
    );

    await _insertDefaults(db);
  }

  // Handle upgrades for existing users
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      // Add state column to customer if missing
      try {
        await db.execute('ALTER TABLE $tableCustomer ADD COLUMN state TEXT');
      } catch (_) {}

      // Note: Rename/Migration logic for purchases/suppliers is complex.
      // For this update, we rely on fresh creation or manual data migration scripts if needed.
    }
  }

  Future _insertDefaults(Database db) async {
    // 1. Shop Defaults
    await db.insert(tableShopDetails, {
      'id': 1,
      'name': 'My Shop',
      'address': '',
      'city': '',
      'state': 'Tamil Nadu',
      'logo': '',
      'phone_number': '',
    });

    // 2. Preferences Defaults
    await db.insert(tablePreferences, {
      'id': 1,
      'include_gst': 1,
      'is_gst_inclusive': 1,
      'manage_stock': 0,
    });
    await db.insert(tableExpensesList, {'expense_type': 'Other'});
    // 3. Payment Modes
    await db.insert(tableCashMode, {'cash_modes': 'Cash'});
    await db.insert(tableCashMode, {'cash_modes': 'UPI'});

    // 4. INSERT WALK-IN CUSTOMER (ID 0)
    // We use rawInsert to force ID 0, as simple insert might auto-increment to 1
    await db.rawInsert(
      'INSERT OR IGNORE INTO $tableCustomer (id, name, phone_number, state) VALUES (0, ?, ?, ?)',
      ['Walk-in Customer', '', 'Tamil Nadu'],
    );
  }

  // ====================================================================
  // CRUD: SHOP & PREFERENCES
  // ====================================================================

  Future<ShopDetails> getShopDetails() async {
    Database db = await instance.database;
    final maps = await db.query(tableShopDetails, where: 'id = 1');
    if (maps.isEmpty)
      return ShopDetails(
        id: 1,
        name: '',
        address: '',
        city: '',
        state: '',
        logo: '',
        phoneNumber: '',
        upiId: '',
      );

    return ShopDetails.fromMap(maps.first);
  }

  Future<int> updateShopDetails(ShopDetails shop) async {
    Database db = await instance.database;
    shop.id = 1;
    return await db.update(tableShopDetails, shop.toMap(), where: 'id = 1');
  }

  Future<PreferenceModel> getPreferences() async {
    Database db = await instance.database;
    final maps = await db.query(tablePreferences, where: 'id = 1');
    if (maps.isNotEmpty) return PreferenceModel.fromMap(maps.first);
    return PreferenceModel(
      includeGst: true,
      isGstInclusive: true,
      manageStock: false,
    );
  }

  Future<int> updatePreferences(PreferenceModel pref) async {
    Database db = await instance.database;
    pref.id = 1;
    return await db.update(tablePreferences, pref.toMap(), where: 'id = 1');
  }

  // ====================================================================
  // CRUD: CUSTOMER
  // ====================================================================
  // inside database_helper.dart

  Future<void> resetBillNumber() async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. Delete all records from the table (e.g., 'sales')
      await txn.delete('sales');

      // 2. Reset the Auto-Increment counter in sqlite_sequence
      await txn.rawDelete("DELETE FROM sqlite_sequence WHERE name = 'sales'");
    });
  }

  Future<int> addCustomer(Customer customer) async {
    Database db = await instance.database;
    return await db.insert(tableCustomer, customer.toMap());
  }

  Future<List<Customer>> getCustomers() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableCustomer,
      where: "id != 0",
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<int> deleteCustomer(int id) async {
    Database db = await instance.database;
    return await db.delete(tableCustomer, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateCustomer(Customer customer) async {
    Database db = await instance.database;
    return await db.update(
      tableCustomer,
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  // ====================================================================
  // CRUD: SALES & STOCK
  // ====================================================================

  Future<int> createSale(Sale sale, List<SoldItem> items) async {
    Database db = await instance.database;
    bool toMaintainStock = (await getPreferences()).manageStock;

    return await db.transaction((txn) async {
      int saleId = await txn.insert(tableSales, sale.toMap());
      for (var item in items) {
        item.salesId = saleId;
        await txn.insert(tableStockSalesItems, item.toMap());
        if (toMaintainStock) {
          await txn.rawUpdate(
            'UPDATE $tableStockItems SET stock_qty = stock_qty - ? WHERE item_name = ?',
            [item.qty, item.itemName],
          );
        }
      }
      return saleId;
    });
  }

  Future<Sale> getSaleById(int id) async {
    Database db = await instance.database;
    return Sale.fromMap(
      (await db.query("sales", where: "id = ?", whereArgs: [id]))[0],
    );
  }

  Future<List<Map<String, dynamic>>> getAllSalesWithCustomer() async {
    Database db = await instance.database;
    return await db.rawQuery('''
      SELECT s.*, c.name as cust_name 
      FROM sales s
      LEFT JOIN customer c ON s.customer_id = c.id
      ORDER BY s.billed_date DESC
    ''');
  }

  Future<List<SoldItem>> getItemsForSale(int saleId) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableStockSalesItems,
      where: 'sales_id = ?',
      whereArgs: [saleId],
    );
    return List.generate(maps.length, (i) => SoldItem.fromMap(maps[i]));
  }

  Future<int> addStockItem(StockItem item) async =>
      await (await instance.database).insert(tableStockItems, item.toMap());

  Future<List<StockItem>> getAllStockItems() async {
    final maps = await (await instance.database).query(tableStockItems);
    return List.generate(maps.length, (i) => StockItem.fromMap(maps[i]));
  }

  // ====================================================================
  // CRUD: PURCHASES (Updated Logic)
  // ====================================================================

  Future<int> createPurchase(
    Purchase purchase,
    List<PurchaseItem> items,
  ) async {
    Database db = await instance.database;

    return await db.transaction((txn) async {
      // 1. Insert Header
      int purchaseId = await txn.insert(tablePurchases, purchase.toMap());

      // 2. Insert Items & Update Stock
      for (var item in items) {
        item.purchaseId = purchaseId;
        await txn.insert(tablePurchaseItems, item.toMap());

        // Update Stock Logic: Add Qty (Purchasing increases stock)
        await txn.rawUpdate(
          'UPDATE $tableStockItems SET stock_qty = stock_qty + ? WHERE item_name = ?',
          [item.qty, item.itemName],
        );
      }
      return purchaseId;
    });
  }

  // Fetch All Purchases with Supplier Name (Using supplier_info_id)
  Future<List<Map<String, dynamic>>> getAllPurchasesWithSupplier() async {
    Database db = await instance.database;
    return await db.rawQuery('''
      SELECT p.*, s.name as vendor_name 
      FROM $tablePurchases p
      LEFT JOIN $tableSupplierInfo s ON p.supplier_info_id = s.id
      ORDER BY p.purchased_date DESC
    ''');
  }

  // Get Recent Purchases with Vendor Name (For Dashboard)
  Future<List<Map<String, dynamic>>> getRecentPurchasesWithVendor() async {
    Database db = await instance.database;
    return await db.rawQuery('''
      SELECT p.*, s.name as vendor_name 
      FROM $tablePurchases p
      LEFT JOIN $tableSupplierInfo s ON p.supplier_info_id = s.id
      ORDER BY p.id DESC
      LIMIT 20
    ''');
  }

  Future<List<PurchaseItem>> getItemsForPurchase(int purchaseId) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tablePurchaseItems,
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );
    return List.generate(maps.length, (i) => PurchaseItem.fromMap(maps[i]));
  }

  Future<int> updatePurchasePayment(int id, int newPaidTotal) async {
    Database db = await instance.database;
    return await db.rawUpdate(
      'UPDATE $tablePurchases SET paid = ? WHERE id = ?',
      [newPaidTotal, id],
    );
  }

  // ====================================================================
  // CRUD: SUPPLIER INFO (Replaces Purchaser Info)
  // ====================================================================

  Future<int> addSupplier(SupplierInfo supplier) async {
    Database db = await instance.database;
    return await db.insert(tableSupplierInfo, supplier.toMap());
  }

  Future<List<SupplierInfo>> getAllSuppliers() async {
    Database db = await instance.database;
    final maps = await db.query(tableSupplierInfo, orderBy: 'name ASC');
    return List.generate(maps.length, (i) => SupplierInfo.fromMap(maps[i]));
  }

  Future<int> updateSupplierBalance(int id, int newBalance) async {
    Database db = await instance.database;
    return await db.rawUpdate(
      'UPDATE $tableSupplierInfo SET balance = ? WHERE id = ?',
      [newBalance, id],
    );
  }

  // ====================================================================
  // CRUD: EXPENSE TYPES, MODES & CONFIG
  // ====================================================================

  Future<int> addExpenseType(ExpenseType expense) async =>
      await (await instance.database).insert(
        tableExpensesList,
        expense.toMap(),
      );

  Future<List<ExpenseType>> getAllExpenseTypes() async {
    Database db = await instance.database;
    final maps = await db.query(tableExpensesList, orderBy: 'expense_type ASC');
    return List.generate(maps.length, (i) => ExpenseType.fromMap(maps[i]));
  }

  Future<int> deleteExpenseType(int id) async => await (await instance.database)
      .delete(tableExpensesList, where: 'id = ?', whereArgs: [id]);

  Future<int> addCashMode(CashMode mode) async =>
      await (await instance.database).insert(tableCashMode, mode.toMap());

  Future<List<CashMode>> getAllCashModes() async {
    Database db = await instance.database;
    final maps = await db.query(tableCashMode, orderBy: 'cash_modes ASC');
    return List.generate(maps.length, (i) => CashMode.fromMap(maps[i]));
  }

  Future<int> deleteCashMode(int id) async => await (await instance.database)
      .delete(tableCashMode, where: 'id = ?', whereArgs: [id]);

  Future<Printer?> getPrinter() async {
    Database db = await instance.database;
    final maps = await db.query(tablePrinter, where: 'id = 1');
    return maps.isNotEmpty ? Printer.fromMap(maps.first) : null;
  }

  Future<void> setPrinter(String name, int width) async {
    Database db = await instance.database;
    Printer newPrinter = Printer(id: 1, name: name, width: width);
    int count = await db.update(
      tablePrinter,
      newPrinter.toMap(),
      where: 'id = 1',
    );
    if (count == 0) await db.insert(tablePrinter, newPrinter.toMap());
  }

  Future<Currency?> getCurrency() async {
    Database db = await instance.database;
    final maps = await db.query(tableCurrency, where: 'id = 1');
    return maps.isNotEmpty ? Currency.fromMap(maps.first) : null;
  }

  Future<void> setCurrency(String symbol) async {
    Database db = await instance.database;
    Currency newCurrency = Currency(id: 1, name: symbol);
    int count = await db.update(
      tableCurrency,
      newCurrency.toMap(),
      where: 'id = 1',
    );
    if (count == 0) await db.insert(tableCurrency, newCurrency.toMap());
  }
}
