class ShopDetails {
  int? id;
  String name;
  String address;
  String city;
  String state;
  String logo;
  String phoneNumber;
  String upiId; // <--- NEW

  ShopDetails({
    this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.logo,
    required this.phoneNumber,
    required this.upiId, // <--- Add to constructor
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'logo': logo,
      'phone_number': phoneNumber,
      'upi_id': upiId, // <--- Map
    };
  }

  factory ShopDetails.fromMap(Map<String, dynamic> map) {
    return ShopDetails(
      id: map['id'],
      name: map['name'],
      address: map['address'],
      city: map['city'],
      state: map['state'] ?? '',
      logo: map['logo'],
      phoneNumber: map['phone_number'],
      upiId: map['upi_id'] ?? '', // <--- From Map
    );
  }
}
