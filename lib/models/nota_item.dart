class NotaItem {
  final String id;
  final String name;
  final double price;
  final double qty;
  final double? totalOverride;

  NotaItem({
    required this.id,
    required this.name,
    required this.price,
    required this.qty,
    this.totalOverride,
  });

  double get computedTotal => price * qty;
  double get effectiveTotal => totalOverride ?? computedTotal;

  NotaItem copyWith({
    String? name,
    double? price,
    double? qty,
    double? totalOverride,
    bool clearOverride = false,
  }) {
    return NotaItem(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      totalOverride: clearOverride ? null : (totalOverride ?? this.totalOverride),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'qty': qty,
      'totalOverride': totalOverride,
    };
  }

  factory NotaItem.fromMap(Map<String, dynamic> map) {
    return NotaItem(
      id: map['id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      qty: (map['qty'] as num).toDouble(),
      totalOverride: map['totalOverride'] == null ? null : (map['totalOverride'] as num).toDouble(),
    );
  }
}
