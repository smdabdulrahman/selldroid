// file: lib/models/general_models.dart

class Customer {
  int? id;
  String name;
  String phoneNumber;
  String state;
  Customer({
    this.id,
    required this.name,
    required this.phoneNumber,
    required this.state,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone_number': phoneNumber,
    'state': state,
  };
  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
    id: map['id'],
    name: map['name'],
    phoneNumber: map['phone_number'],
    state: map['state'],
  );
}

class Expense {
  int? id;
  String category;
  String date;
  String description;
  int amount;

  Expense({
    this.id,
    required this.category,
    required this.date,
    required this.description,
    required this.amount,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'date': date,
    'description': description,
    'amount': amount,
  };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    id: map['id'],
    category: map['category'],
    date: map['date'],
    description: map['description'],
    amount: map['amount'],
  );
}

class PurchaseItem {
  int? id;
  int? purchaseId; // Foreign Key linking to Purchase table
  String itemName;
  int qty;
  double amount; // Cost Price per unit
  double gstRate;
  double gstAmount;

  PurchaseItem({
    this.id,
    this.purchaseId,
    required this.itemName,
    required this.qty,
    required this.amount,
    this.gstRate = 0.0,
    this.gstAmount = 0.0,
  });

  // Convert to Map for Database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'item_name': itemName,
      'qty': qty,
      'amount': amount,
      'gst_rate': gstRate,
      'gst_amount': gstAmount,
    };
  }

  // Extract from Map (Reading from Database)
  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'],
      purchaseId: map['purchase_id'],
      itemName: map['item_name'],
      qty: map['qty'] ?? 0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      gstRate: (map['gst_rate'] as num?)?.toDouble() ?? 0.0,
      gstAmount: (map['gst_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Purchase {
  int? id;
  int? supplierInfoId;
  int totalAmount;
  int gstAmount;
  int discount;
  int finalAmount;
  int paid;
  String paymentMode; // Changed to camelCase for Dart
  String purchasedDate; // Changed to camelCase for Dart
  String lastPaymentDate; // Changed to camelCase for Dart

  Purchase({
    this.id,
    this.supplierInfoId,
    required this.totalAmount,
    required this.gstAmount,
    required this.discount,
    required this.finalAmount,
    required this.paid,
    required this.paymentMode,
    required this.purchasedDate,
    required this.lastPaymentDate,
  });

  // Convert a Purchase into a Map. The keys must correspond to the names of the
  // columns in the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_info_id': supplierInfoId,
      'tot_amount': totalAmount, // DB column: tot_amount
      'gst_amount': gstAmount, // DB column: gst_amount
      'discount': discount, // DB column: discount
      'final_amount': finalAmount, // DB column: final_amount
      'paid': paid, // DB column: paid
      'payment_mode': paymentMode, // DB column: payment_mode
      'purchased_date':
          purchasedDate, // DB column: purchased_date (formerly created_at)
      'last_payment_date': lastPaymentDate, // DB column: last_payment_date
    };
  }

  // Extract a Purchase object from a Map object
  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: map['id'],
      supplierInfoId: map['supplier_info_id'],
      totalAmount: map['tot_amount'] ?? 0,
      gstAmount: map['gst_amount'] ?? 0,
      discount: map['discount'] ?? 0,
      finalAmount: map['final_amount'] ?? 0,
      paid: map['paid'] ?? 0,
      paymentMode: map['payment_mode'] ?? 'Cash',
      purchasedDate: map['purchased_date'] ?? '',
      lastPaymentDate: map['last_payment_date'] ?? '',
    );
  }
}

class SupplierInfo {
  int? id;
  String name;
  int balance;
  String state;
  SupplierInfo({
    this.id,
    required this.name,
    required this.balance,
    required this.state,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'balance': balance, 'state': state};
  }

  factory SupplierInfo.fromMap(Map<String, dynamic> map) {
    return SupplierInfo(
      id: map['id'],
      name: map['name'],
      balance: map['balance'],
      state: map['state'],
    );
  }
}

class Printer {
  int? id;
  String name;
  Printer({this.id, required this.name});
  Map<String, dynamic> toMap() => {'id': id, 'name': name};
  factory Printer.fromMap(Map<String, dynamic> map) =>
      Printer(id: map['id'], name: map['name']);
}

class Currency {
  int? id;
  String name;
  Currency({this.id, required this.name});
  Map<String, dynamic> toMap() => {'id': id, 'name': name};
  factory Currency.fromMap(Map<String, dynamic> map) =>
      Currency(id: map['id'], name: map['name']);
}

class ExpenseType {
  int? id;
  String type;
  ExpenseType({this.id, required this.type});
  Map<String, dynamic> toMap() => {'id': id, 'expense_type': type};
  factory ExpenseType.fromMap(Map<String, dynamic> map) =>
      ExpenseType(id: map['id'], type: map['expense_type']);
}

class CashMode {
  int? id;
  String modeName;

  CashMode({this.id, required this.modeName});

  // Maps to DB column 'cash_modes'
  Map<String, dynamic> toMap() {
    return {'id': id, 'cash_modes': modeName};
  }

  factory CashMode.fromMap(Map<String, dynamic> map) {
    return CashMode(id: map['id'], modeName: map['cash_modes']);
  }
}
