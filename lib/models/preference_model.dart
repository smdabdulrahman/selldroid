class PreferenceModel {
  int? id;
  bool includeGst; // true = GST Mode, false = Non-GST Mode
  bool
  isGstInclusive; // true = Inclusive, false = Exclusive (only used if includeGst is true)
  bool manageStock; // true = Track Inventory

  PreferenceModel({
    this.id,
    required this.includeGst,
    required this.isGstInclusive,
    required this.manageStock,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'include_gst': includeGst ? 1 : 0,
      'is_gst_inclusive': isGstInclusive ? 1 : 0,
      'manage_stock': manageStock ? 1 : 0,
    };
  }

  factory PreferenceModel.fromMap(Map<String, dynamic> map) {
    return PreferenceModel(
      id: map['id'],
      includeGst: map['include_gst'] == 1,
      isGstInclusive: map['is_gst_inclusive'] == 1,
      manageStock: map['manage_stock'] == 1,
    );
  }
}
