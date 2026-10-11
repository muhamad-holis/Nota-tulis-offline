import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/nota_draft_provider.dart';
import '../providers/history_provider.dart';
import '../providers/printer_provider.dart';
import '../providers/settings_provider.dart';
import '../services/receipt_image_share.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/catalog_sheet.dart';
import '../widgets/kembalian_calculator.dart';
import '../widgets/nota_item_card.dart';
import '../widgets/qris_payment_sheet.dart';
import '../widgets/toast.dart';

/// Halaman "Buat Nota".
class NotaScreen extends ConsumerStatefulWidget {
  const NotaScreen({super.key});

  @override
  ConsumerState<NotaScreen> createState() => _NotaScreenState();
}

class _NotaScreenState extends ConsumerState<NotaScreen> {
  final TextEditingController _customerCtrl = TextEditingController();
  final Map<String, FocusNode> _nameFocusNodes = {};
  String _receivedText = '';
  String? _busy; // 'save' | 'print' | 'share'

  @override
  void initState() {
    super.initState();
    _customerCtrl.text = ref.read(notaDraftProvider).customerName;
  }

  FocusNode _nameFocusNodeFor(String id) => _nameFocusNodes.putIfAbsent(id, () => FocusNode());

  @override
  void dispose() {
    _customerCtrl.dispose();
    for (final node in _nameFocusNodes.values) {
      node.dispose();
    }
    _nameFocusNodes.clear();
    super.dispose();
  }

  void _finishAndClose() {
    ref.read(historyRefreshProvider.notifier).state++;
    ref.read(notaDraftProvider.notifier).reset();
    if (mounted) Navigator.of(context).pop();
  }

  bool _draftHasItems() {
    if (ref.read(notaDraftProvider).validItems.isEmpty) {
      showToast('Nota masih kosong.', ToastType.error);
      return false;
    }
    return true;
  }

  Future<void> _handleSave() async {
    if (_busy != null || !_draftHasItems()) return;
    final draft = ref.read(notaDraftProvider);

    // Metode QRIS: tampilkan gambar QRIS + jumlah yang harus dibayar dulu.
    if (draft.paymentMethod == 'qris') {
      final qris = ref.read(settingsProvider).value?.qrisImage;
      final paid = await showQrisPaymentSheet(context, total: draft.total, qrisBase64: qris);
      if (!paid || !mounted) return;
    }

    setState(() => _busy = 'save');
    try {
      await ref.read(notaDraftProvider.notifier).saveNota(
            bayarTunai: parseRupiahInput(_receivedText).toDouble(),
          );
      showToast('Nota berhasil disimpan', ToastType.success);
      _finishAndClose();
    } catch (err) {
      showToast(err.toString().replaceFirst('Exception: ', ''), ToastType.error);
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _handlePrint() async {
    final settings = ref.read(settingsProvider).value;
    if (settings == null || _busy != null || !_draftHasItems()) return;
    setState(() => _busy = 'print');
    try {
      final saved = await ref.read(notaDraftProvider.notifier).saveNota(
            bayarTunai: parseRupiahInput(_receivedText).toDouble(),
          );
      final ok = await ref.read(printerProvider.notifier).print(saved, settings);
      showToast(
        ok ? 'Nota berhasil dicetak' : 'Nota tersimpan, tapi gagal mencetak. Cek printer lalu cetak ulang dari daftar nota.',
        ok ? ToastType.success : ToastType.error,
      );
      _finishAndClose();
    } catch (err) {
      showToast(err.toString().replaceFirst('Exception: ', ''), ToastType.error);
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _handleShareWhatsApp() async {
    final settings = ref.read(settingsProvider).value;
    if (settings == null || _busy != null || !_draftHasItems()) return;
    setState(() => _busy = 'share');
    try {
      final saved = await ref.read(notaDraftProvider.notifier).saveNota(
            bayarTunai: parseRupiahInput(_receivedText).toDouble(),
          );
      if (!mounted) return;
      await shareNotaAsImage(context, saved, settings);
      _finishAndClose();
    } catch (err) {
      showToast(err.toString().replaceFirst('Exception: ', ''), ToastType.error);
      if (mounted) setState(() => _busy = null);
    }
  }

  void _onEnterPrice(String id, bool isLast) {
    final notifier = ref.read(notaDraftProvider.notifier);
    if (isLast) notifier.ensureTrailingRow();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final items = ref.read(notaDraftProvider).items;
      final idx = items.indexWhere((it) => it.id == id);
      if (idx >= 0 && idx + 1 < items.length) {
        _nameFocusNodeFor(items[idx + 1].id).requestFocus();
      }
    });
  }

  Widget _sideButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool loading,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: SizedBox(
        height: 62,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            padding: EdgeInsets.zero,
            side: BorderSide(color: color.withOpacity(0.6), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              loading
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                  : Icon(icon, size: 22),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(notaDraftProvider);
    final notifier = ref.read(notaDraftProvider.notifier);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.header,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        iconTheme: IconThemeData(color: AppColors.brand600),
        title: Text('Buat Nota',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, color: AppColors.brand600)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('Nama Pembeli',
                      style: TextStyle(fontSize: 16, color: AppColors.slate600)),
                ),
                TextField(
                  controller: _customerCtrl,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(fontSize: 17, color: AppColors.slate800),
                  decoration: InputDecoration(
                    hintText: 'Bu Nita',
                    hintStyle: TextStyle(color: AppColors.slate300),
                    prefixIcon: Icon(Icons.person_outline, color: AppColors.brand600),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: AppColors.slate200)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: AppColors.slate200)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: AppColors.brand600)),
                  ),
                  onChanged: notifier.setCustomerName,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text('Daftar Item',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.brand600)),
                    ),
                    TextButton.icon(
                      onPressed: () => showCatalogSheet(context),
                      icon: Icon(Icons.apps_rounded, size: 22, color: AppColors.brand600),
                      label: Text('Katalog',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.brand600)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < draft.items.length; i++) ...[
                  NotaItemCard(
                    key: ValueKey(draft.items[i].id),
                    index: i,
                    item: draft.items[i],
                    nameFocusNode: _nameFocusNodeFor(draft.items[i].id),
                    onUpdate: ({name, price, qty, unit, totalOverride, clearOverride = false}) =>
                        notifier.updateItem(
                      draft.items[i].id,
                      name: name,
                      price: price,
                      qty: qty,
                      unit: unit,
                      totalOverride: totalOverride,
                      clearOverride: clearOverride,
                    ),
                    onRemove: () {
                      final id = draft.items[i].id;
                      notifier.removeItem(id);
                      _nameFocusNodes.remove(id)?.dispose();
                    },
                    onEnterPrice: () => _onEnterPrice(draft.items[i].id, i == draft.items.length - 1),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: notifier.addRow,
                  icon: const Icon(Icons.add, size: 24),
                  label: const Text('Tambah Baris Item',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brand600,
                    minimumSize: const Size.fromHeight(60),
                    side: BorderSide(color: AppColors.slate400, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
                const SizedBox(height: 20),
                _PaymentOptions(
                  method: draft.paymentMethod,
                  onMethodChanged: notifier.setPaymentMethod,
                  total: draft.total,
                  receivedText: _receivedText,
                  onReceivedChanged: (v) => setState(() => _receivedText = v),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottomInset),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('Total',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.brand600)),
                    const Spacer(),
                    Text(formatRupiah(draft.total),
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.brand600)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _sideButton(
                      icon: Icons.share_outlined,
                      label: 'Share WA',
                      color: const Color(0xFF128C4A),
                      loading: _busy == 'share',
                      onTap: _busy == null ? _handleShareWhatsApp : null,
                    ),
                    const SizedBox(width: 8),
                    _sideButton(
                      icon: Icons.print_outlined,
                      label: 'Cetak',
                      color: AppColors.brand600,
                      loading: _busy == 'print',
                      onTap: _busy == null ? _handlePrint : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 62,
                        child: ElevatedButton.icon(
                          onPressed: _busy == null ? _handleSave : null,
                          icon: _busy == 'save'
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save, size: 22),
                          label: const Text('Simpan Nota', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand600,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu "Opsi Tambahan": metode pembayaran (Tunai/QRIS) + kalkulator kembalian untuk tunai.
class _PaymentOptions extends StatelessWidget {
  final String method;
  final ValueChanged<String> onMethodChanged;
  final double total;
  final String receivedText;
  final ValueChanged<String> onReceivedChanged;

  const _PaymentOptions({
    required this.method,
    required this.onMethodChanged,
    required this.total,
    required this.receivedText,
    required this.onReceivedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text('Opsi Tambahan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.brand600)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Metode pembayaran: ${method == 'qris' ? 'QRIS' : 'Tunai'}',
                style: TextStyle(fontSize: 15, color: AppColors.slate500)),
          ),
          iconColor: AppColors.brand600,
          collapsedIconColor: AppColors.brand600,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('Metode Pembayaran', style: TextStyle(fontSize: 14, color: AppColors.slate500)),
              ),
            ),
            Row(
              children: [
                Expanded(child: _methodButton('tunai', 'Tunai', Icons.payments_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _methodButton('qris', 'QRIS', Icons.qr_code_2)),
              ],
            ),
            if (method == 'tunai') ...[
              const SizedBox(height: 12),
              KembalianCalculator(
                total: total,
                receivedText: receivedText,
                onReceivedTextChange: onReceivedChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _methodButton(String value, String label, IconData icon) {
    final selected = method == value;
    return InkWell(
      onTap: () => onMethodChanged(value),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: selected ? AppColors.brand600 : Colors.white,
          border: Border.all(color: selected ? AppColors.brand600 : AppColors.slate200),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: selected ? Colors.white : AppColors.brand600),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.brand600)),
          ],
        ),
      ),
    );
  }
}
