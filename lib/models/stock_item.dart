class StockItem {
  int? id;
  String itemName;
  int sellingPrice;
  int costPrice;
  int stockQty;
  double igst;
  double sgst;
  double cgst;

  StockItem({
    this.id,
    required this.itemName,
    required this.sellingPrice,
    required this.costPrice,
    required this.stockQty,
    required this.igst,
    required this.sgst,
    required this.cgst,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_name': itemName,
      'selling_price': sellingPrice,
      'cost_price': costPrice,
      'stock_qty': stockQty,
      'igst': igst,
      'sgst': sgst,
      'cgst': cgst,
    };
  }

  factory StockItem.fromMap(Map<String, dynamic> map) {
    return StockItem(
      id: map['id'],
      itemName: map['item_name'],
      sellingPrice: map['selling_price'],
      costPrice: map['cost_price'],
      stockQty: map['stock_qty'],
      // Handle nulls safely for existing data
      igst: (map['igst'] as num?)?.toDouble() ?? 0.0,
      sgst: (map['sgst'] as num?)?.toDouble() ?? 0.0,
      cgst: (map['cgst'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
