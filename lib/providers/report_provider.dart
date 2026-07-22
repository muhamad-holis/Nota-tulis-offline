import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import 'history_provider.dart';

enum ReportPeriod { today, week, month }

class TopItem {
  final String name;
  final double qty;
  final double total;
  TopItem({required this.name, required this.qty, required this.total});
}

class ReportData {
  final double omzet;
  final int jumlahNota;
  final double rataRataPerNota;
  final List<TopItem> topItems;

  ReportData({
    required this.omzet,
    required this.jumlahNota,
    required this.rataRataPerNota,
    required this.topItems,
  });
}

int _startTimestamp(ReportPeriod period) {
  final now = DateTime.now();
  if (period == ReportPeriod.today) {
    return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  }
  if (period == ReportPeriod.week) {
    final weekday = now.weekday; // 1 = Senin ... 7 = Minggu
    final offsetToMonday = weekday - 1;
    return DateTime(now.year, now.month, now.day - offsetToMonday).millisecondsSinceEpoch;
  }
  return DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
}

final reportProvider = FutureProvider.family<ReportData, ReportPeriod>((ref, period) async {
  ref.watch(historyRefreshProvider);
  final start = _startTimestamp(period);
  final notas = await DatabaseHelper.instance.getNotasFrom(start);

  final omzet = notas.fold(0.0, (sum, n) => sum + n.total);
  final jumlahNota = notas.length;
  final rataRataPerNota = jumlahNota > 0 ? omzet / jumlahNota : 0.0;

  final itemMap = <String, TopItem>{};
  for (final nota in notas) {
    for (final item in nota.items) {
      final key = item.name.trim().toLowerCase();
      if (key.isEmpty) continue;
      final itemTotal = item.effectiveTotal;
      final existing = itemMap[key];
      if (existing != null) {
        itemMap[key] = TopItem(
          name: existing.name,
          qty: existing.qty + item.qty,
          total: existing.total + itemTotal,
        );
      } else {
        itemMap[key] = TopItem(name: item.name.trim(), qty: item.qty, total: itemTotal);
      }
    }
  }

  final topItems = itemMap.values.toList()..sort((a, b) => b.qty.compareTo(a.qty));

  return ReportData(
    omzet: omzet,
    jumlahNota: jumlahNota,
    rataRataPerNota: rataRataPerNota,
    topItems: topItems.take(5).toList(),
  );
});
