class SoldItem {
  int? id;
  int salesId;
  String itemName;
  int qty;
  double amount;
  double igst;
  double sgst;
  double cgst;

  SoldItem({
    this.id,
    required this.salesId,
    required this.itemName,
    required this.qty,
    required this.amount,
    required this.igst,
    required this.sgst,
    required this.cgst,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sales_id': salesId,
      'item_name': itemName,
      'qty': qty,
      'amount': amount,
      'igst': igst,
      "cgst": cgst,
      "sgst": sgst,
    };
  }

  factory SoldItem.fromMap(Map<String, dynamic> map) {
    return SoldItem(
      id: map['id'],
      salesId: map['sales_id'],
      itemName: map['item_name'],
      qty: map['qty'],
      amount: (map['amount'] as num).toDouble(),
      igst: (map['igst'] as num?)?.toDouble() ?? 0.0,
      sgst: (map['sgst'] as num?)?.toDouble() ?? 0.0,
      cgst: (map['cgst'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
