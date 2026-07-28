class NotaItem {
  final String id;
  final String name;
  final double price;
  final double qty;
  final String unit;
  final double? totalOverride;

  NotaItem({
    required this.id,
    required this.name,
    required this.price,
    required this.qty,
    this.unit = 'pcs',
    this.totalOverride,
  });

  double get computedTotal => price * qty;
  double get effectiveTotal => totalOverride ?? computedTotal;

  NotaItem copyWith({
    String? name,
    double? price,
    double? qty,
    String? unit,
    double? totalOverride,
    bool clearOverride = false,
  }) {
    return NotaItem(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      totalOverride: clearOverride ? null : (totalOverride ?? this.totalOverride),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'qty': qty,
      'unit': unit,
      'totalOverride': totalOverride,
    };
  }

  factory NotaItem.fromMap(Map<String, dynamic> map) {
    return NotaItem(
      id: map['id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      qty: (map['qty'] as num).toDouble(),
      // Nota lama (sebelum fitur satuan) tidak punya field ini, default ke 'pcs'.
      unit: (map['unit'] as String?)?.trim().isNotEmpty == true ? map['unit'] as String : 'pcs',
      totalOverride: map['totalOverride'] == null ? null : (map['totalOverride'] as num).toDouble(),
    );
  }
}
