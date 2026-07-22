class Product {
  final int? id;
  final String uuid;
  final String name;
  final double price;
  final String? category;
  final int createdAt;
  final int updatedAt;

  Product({
    this.id,
    required this.uuid,
    required this.name,
    required this.price,
    this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  Product copyWith({
    int? id,
    String? uuid,
    String? name,
    double? price,
    String? category,
    int? createdAt,
    int? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'name': name,
      'price': price,
      'category': category,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      category: map['category'] as String?,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
    );
  }
}
