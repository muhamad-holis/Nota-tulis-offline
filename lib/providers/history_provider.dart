import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../models/nota.dart';

class HistoryFilter {
  final String search;
  final int? dateFrom;
  final int? dateTo;

  const HistoryFilter({this.search = '', this.dateFrom, this.dateTo});

  HistoryFilter copyWith({String? search, int? dateFrom, int? dateTo, bool clearFrom = false, bool clearTo = false}) {
    return HistoryFilter(
      search: search ?? this.search,
      dateFrom: clearFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearTo ? null : (dateTo ?? this.dateTo),
    );
  }
}

class HistoryFilterNotifier extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() => const HistoryFilter();

  void setSearch(String value) => state = state.copyWith(search: value);
  void setDateFrom(int? value) => value == null
      ? state = state.copyWith(clearFrom: true)
      : state = state.copyWith(dateFrom: value);
  void setDateTo(int? value) => value == null
      ? state = state.copyWith(clearTo: true)
      : state = state.copyWith(dateTo: value);
}

final historyFilterProvider = NotifierProvider<HistoryFilterNotifier, HistoryFilter>(
  HistoryFilterNotifier.new,
);

/// Dinaikkan setiap kali ada mutasi (simpan/edit/hapus nota) supaya historyProvider
/// di-refetch — pengganti reactivity otomatis ala Dexie liveQuery.
final historyRefreshProvider = StateProvider<int>((ref) => 0);

final historyProvider = FutureProvider<List<Nota>>((ref) async {
  ref.watch(historyRefreshProvider);
  final filter = ref.watch(historyFilterProvider);
  return DatabaseHelper.instance.searchNotas(
    search: filter.search,
    dateFrom: filter.dateFrom,
    dateTo: filter.dateTo,
  );
});

Future<void> deleteNotaAndRefresh(WidgetRef ref, int id) async {
  await DatabaseHelper.instance.deleteNota(id);
  ref.read(historyRefreshProvider.notifier).state++;
}

Future<void> clearAllNotasAndRefresh(WidgetRef ref) async {
  await DatabaseHelper.instance.clearAllNotas();
  ref.read(historyRefreshProvider.notifier).state++;
}
