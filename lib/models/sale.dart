class Sale {
  int? id;
  int customerId;
  int totalAmount;
  int gstAmount;
  int discountAmount;
  int finalAmount;
  int paid;
  bool isStockSales;
  String paymentMode; // <--- NEW
  String billedDate; // <--- NEW
  String lastPaymentDate; // <--- NEW

  Sale({
    this.id,
    required this.customerId,
    required this.totalAmount,
    required this.gstAmount,
    required this.discountAmount,
    required this.finalAmount,
    required this.paid,
    required this.isStockSales,
    required this.paymentMode, // <--- Add
    required this.billedDate, // <--- Add
    required this.lastPaymentDate, // <--- Add
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'total_amount': totalAmount,
      'gst_amount': gstAmount,
      'discount_amount': discountAmount,
      'final_amount': finalAmount,
      'paid': paid,
      'is_stock_sales': isStockSales ? 1 : 0,
      'payment_mode': paymentMode, // <--- Map
      'billed_date': billedDate, // <--- Map
      'last_payment_date': lastPaymentDate, // <--- Map
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      customerId: map['customer_id'],
      totalAmount: map['total_amount'],
      gstAmount: map['gst_amount'],
      discountAmount: map['discount_amount'],
      finalAmount: map['final_amount'],
      paid: map['paid'],
      isStockSales: map['is_stock_sales'] == 1,
      paymentMode: map['payment_mode'] ?? 'Cash', // <--- Default
      billedDate: map['billed_date'] ?? '',
      lastPaymentDate: map['last_payment_date'] ?? '',
    );
  }
}
