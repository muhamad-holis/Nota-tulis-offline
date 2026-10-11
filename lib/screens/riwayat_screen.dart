import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/nota.dart';
import '../providers/history_provider.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/history_item.dart';
import 'detail_nota_screen.dart';

/// Halaman utama: daftar nota + tombol "Buat Nota".
class RiwayatScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLaporan;
  final VoidCallback onCreateNota;
  const RiwayatScreen({
    super.key,
    required this.onOpenSettings,
    required this.onOpenLaporan,
    required this.onCreateNota,
  });

  @override
  ConsumerState<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends ConsumerState<RiwayatScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  DateTimeRange? _range;
  String _method = 'all'; // all | tunai | qris

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    final n = ref.read(historyFilterProvider.notifier);
    n.setDateFrom(DateTime(picked.start.year, picked.start.month, picked.start.day).millisecondsSinceEpoch);
    n.setDateTo(DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59).millisecondsSinceEpoch);
  }

  void _clearRange() {
    setState(() => _range = null);
    final n = ref.read(historyFilterProvider.notifier);
    n.setDateFrom(null);
    n.setDateTo(null);
  }

  void _openNota(Nota nota) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailNotaScreen(nota: nota)));
  }

  bool _isQris(Nota n) => n.paymentMethod == 'qris';

  @override
  Widget build(BuildContext context) {
    final notasAsync = ref.watch(historyProvider);
    final notas = notasAsync.valueOrNull;

    Widget content;
    if (notas == null) {
      content = notasAsync.hasError
          ? Center(child: Text('Gagal memuat nota: ${notasAsync.error}'))
          : const Center(child: CircularProgressIndicator());
    } else {
      final qrisCount = notas.where(_isQris).length;
      final tunaiCount = notas.length - qrisCount;
      final shown = _method == 'all'
          ? notas
          : notas.where((n) => _method == 'qris' ? _isQris(n) : !_isQris(n)).toList();

      content = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _tabs(notas.length, tunaiCount, qrisCount),
          ),
          Expanded(
            child: shown.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Belum ada nota',
                    description: 'Tekan "Buat Nota" untuk membuat nota pertama.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    children: [for (final n in shown) HistoryItem(nota: n, onTap: () => _openNota(n))],
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.header,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        title: Text('Nota Tulis',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: AppColors.brand600)),
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart_rounded, size: 28, color: AppColors.brand600),
            tooltip: 'Laporan',
            onPressed: widget.onOpenLaporan,
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, size: 26, color: AppColors.brand600),
            tooltip: 'Pengaturan',
            onPressed: widget.onOpenSettings,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(fontSize: 16, color: AppColors.slate800),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: AppColors.brand600),
                      hintText: 'Cari nama, nomor nota...',
                      hintStyle: TextStyle(color: AppColors.slate400),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: AppColors.slate200)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: AppColors.slate200)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: AppColors.brand600)),
                    ),
                    onChanged: (v) => ref.read(historyFilterProvider.notifier).setSearch(v),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: _range == null ? AppColors.slate100 : AppColors.brand600,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _pickRange,
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: Icon(Icons.calendar_today_outlined,
                          color: _range == null ? AppColors.brand600 : Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_range != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text(
                      '${formatDateShort(_range!.start.millisecondsSinceEpoch)} - ${formatDateShort(_range!.end.millisecondsSinceEpoch)}'),
                  onDeleted: _clearRange,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          Expanded(child: content),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onCreateNota,
        backgroundColor: AppColors.brand600,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.add_circle_outline, size: 28),
        label: const Text('Buat Nota', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _tabs(int all, int tunai, int qris) {
    final tabs = [
      ('all', 'Semua ($all)'),
      ('tunai', 'Tunai ($tunai)'),
      ('qris', 'QRIS ($qris)'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final t in tabs)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _method = t.$1),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  color: _method == t.$1 ? AppColors.accent : Colors.transparent,
                  child: Text(
                    t.$2,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _method == t.$1 ? Colors.white : AppColors.brand600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
