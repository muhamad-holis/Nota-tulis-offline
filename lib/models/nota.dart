import 'dart:convert';
import 'nota_item.dart';

class Nota {
  final int? id;
  final String uuid;
  final String number;
  final String? customerName;
  final int date;
  final List<NotaItem> items;
  final double total;
  final double? bayarTunai;
  final int updatedAt;

  Nota({
    this.id,
    required this.uuid,
    required this.number,
    this.customerName,
    required this.date,
    required this.items,
    required this.total,
    this.bayarTunai,
    required this.updatedAt,
  });

  Nota copyWith({
    int? id,
    String? customerName,
    List<NotaItem>? items,
    double? total,
    double? bayarTunai,
    int? updatedAt,
  }) {
    return Nota(
      id: id ?? this.id,
      uuid: uuid,
      number: number,
      customerName: customerName ?? this.customerName,
      date: date,
      items: items ?? this.items,
      total: total ?? this.total,
      bayarTunai: bayarTunai ?? this.bayarTunai,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'number': number,
      'customerName': customerName,
      'date': date,
      'items': jsonEncode(items.map((e) => e.toMap()).toList()),
      'total': total,
      'bayarTunai': bayarTunai,
      'updatedAt': updatedAt,
    };
  }

  factory Nota.fromMap(Map<String, dynamic> map) {
    final rawItems = jsonDecode(map['items'] as String) as List<dynamic>;
    return Nota(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      number: map['number'] as String,
      customerName: map['customerName'] as String?,
      date: map['date'] as int,
      items: rawItems.map((e) => NotaItem.fromMap(e as Map<String, dynamic>)).toList(),
      total: (map['total'] as num).toDouble(),
      bayarTunai: map['bayarTunai'] == null ? null : (map['bayarTunai'] as num).toDouble(),
      updatedAt: map['updatedAt'] as int,
    );
  }

  Map<String, dynamic> toBackupJson() {
    return {
      'id': id,
      'uuid': uuid,
      'number': number,
      'customerName': customerName,
      'date': date,
      'items': items.map((e) => e.toMap()).toList(),
      'total': total,
      'bayarTunai': bayarTunai,
      'updatedAt': updatedAt,
    };
  }

  factory Nota.fromBackupJson(Map<String, dynamic> map) {
    final rawItems = (map['items'] as List<dynamic>? ?? []);
    return Nota(
      id: null,
      uuid: map['uuid'] as String? ?? '',
      number: map['number'] as String,
      customerName: map['customerName'] as String?,
      date: map['date'] as int,
      items: rawItems.map((e) => NotaItem.fromMap(e as Map<String, dynamic>)).toList(),
      total: (map['total'] as num).toDouble(),
      bayarTunai: map['bayarTunai'] == null ? null : (map['bayarTunai'] as num).toDouble(),
      updatedAt: map['updatedAt'] as int? ?? map['date'] as int,
    );
  }
}
