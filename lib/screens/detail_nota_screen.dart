import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/nota.dart';
import '../providers/edit_nota_provider.dart';
import '../providers/history_provider.dart';
import '../providers/printer_provider.dart';
import '../providers/settings_provider.dart';
import '../services/receipt_image_share.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/toast.dart';
import 'edit_nota_screen.dart';

/// Halaman penuh "Detail Nota": isi nota + tombol Share / Simpan / Cetak.
class DetailNotaScreen extends ConsumerStatefulWidget {
  final Nota nota;
  const DetailNotaScreen({super.key, required this.nota});

  @override
  ConsumerState<DetailNotaScreen> createState() => _DetailNotaScreenState();
}

class _DetailNotaScreenState extends ConsumerState<DetailNotaScreen> {
  late Nota _nota;
  String? _busy; // 'share' | 'save' | 'print'

  @override
  void initState() {
    super.initState();
    _nota = widget.nota;
  }

  Future<void> _edit() async {
    ref.read(editNotaProvider.notifier).load(_nota, force: true);
    final updated = await Navigator.of(context).push<Nota>(
      MaterialPageRoute(builder: (_) => const EditNotaScreen()),
    );
    if (updated != null && mounted) setState(() => _nota = updated);
  }

  Future<void> _delete() async {
    final id = _nota.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus nota ini?'),
        content: Text('Nota ${_nota.number} akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await deleteNotaAndRefresh(ref, id);
    if (!mounted) return;
    Navigator.of(context).pop();
    showToast('Nota dihapus', ToastType.info);
  }

  Future<void> _run(String key, Future<void> Function() body) async {
    if (_busy != null) return;
    setState(() => _busy = key);
    try {
      await body();
    } catch (err) {
      showToast(err.toString().replaceFirst('Exception: ', ''), ToastType.error);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _share() => _run('share', () async {
        final settings = ref.read(settingsProvider).value;
        if (settings == null) return;
        await shareNotaAsImage(context, _nota, settings);
      });

  Future<void> _saveImage() => _run('save', () async {
        final settings = ref.read(settingsProvider).value;
        if (settings == null) return;
        final ok = await saveNotaImage(context, _nota, settings);
        if (ok) showToast('Nota disimpan sebagai gambar', ToastType.success);
      });

  Future<void> _print() => _run('print', () async {
        final settings = ref.read(settingsProvider).value;
        if (settings == null) return;
        final ok = await ref.read(printerProvider.notifier).print(_nota, settings);
        showToast(ok ? 'Nota berhasil dicetak' : 'Gagal mencetak. Cek koneksi printer.',
            ok ? ToastType.success : ToastType.error);
      });

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final name = (_nota.customerName ?? '').trim();
    final isQris = _nota.paymentMethod == 'qris';
    final showTunai = !isQris && _nota.bayarTunai != null && _nota.bayarTunai! > 0;

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
        title: Text('Detail Nota',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, color: AppColors.brand600)),
        actions: [
          IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit nota', onPressed: _edit),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'delete') _delete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Hapus nota')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (settings != null) ...[
                        Center(
                          child: Text(settings.storeName,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.brand600)),
                        ),
                        if (settings.address.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Center(
                              child: Text(settings.address,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: AppColors.slate500)),
                            ),
                          ),
                        const SizedBox(height: 14),
                        Divider(height: 1, color: AppColors.slate100),
                        const SizedBox(height: 12),
                      ],
                      _kv('No. Nota', _nota.number),
                      _kv('Tanggal', formatDateTime(_nota.date)),
                      _kv('Pembeli', name.isEmpty ? '-' : name),
                      _kv('Pembayaran', isQris ? 'QRIS' : 'Tunai'),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          SizedBox(width: 30, child: Text('No', style: _head())),
                          Expanded(child: Text('Item', style: _head())),
                          SizedBox(width: 74, child: Text('Qty', textAlign: TextAlign.center, style: _head())),
                          SizedBox(width: 98, child: Text('Subtotal', textAlign: TextAlign.right, style: _head())),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (int i = 0; i < _nota.items.length; i++) ...[
                        Divider(height: 1, color: AppColors.slate100),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                  width: 30,
                                  child: Text('${i + 1}',
                                      style: TextStyle(fontSize: 16, color: AppColors.slate600))),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_nota.items[i].name,
                                        style: TextStyle(
                                            fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.slate800)),
                                    Text('@ ${formatRupiah(_nota.items[i].price)}',
                                        style: TextStyle(fontSize: 14, color: AppColors.slate400)),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 74,
                                child: Text(
                                  '${formatQty(_nota.items[i].qty)} ${_nota.items[i].unit}'.trim(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16, color: AppColors.slate700),
                                ),
                              ),
                              SizedBox(
                                width: 98,
                                child: Text(formatRupiah(_nota.items[i].effectiveTotal),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.slate800)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Divider(height: 1, color: AppColors.slate100),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(18)),
                        child: Row(
                          children: [
                            Text('TOTAL',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.brand600)),
                            const Spacer(),
                            Text(formatRupiah(_nota.total),
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.brand600)),
                          ],
                        ),
                      ),
                      if (showTunai) ...[
                        const SizedBox(height: 12),
                        _kv('Bayar Tunai', formatRupiah(_nota.bayarTunai!)),
                        _kv(_nota.bayarTunai! - _nota.total < 0 ? 'Kurang' : 'Kembali',
                            formatRupiah((_nota.bayarTunai! - _nota.total).abs())),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              border: Border(top: BorderSide(color: AppColors.slate100)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _actionButton(
                      icon: Icons.share_outlined, label: 'Share', loading: _busy == 'share', onTap: _share),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(
                      icon: Icons.download_outlined, label: 'Simpan', loading: _busy == 'save', onTap: _saveImage),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(
                      icon: Icons.print_outlined,
                      label: 'Cetak',
                      loading: _busy == 'print',
                      onTap: _print,
                      primary: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _head() => TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.brand600);

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(k, style: TextStyle(fontSize: 15, color: AppColors.slate500))),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.slate800)),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required bool loading,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final fg = primary ? Colors.white : AppColors.brand600;
    return SizedBox(
      height: 60,
      child: ElevatedButton.icon(
        onPressed: _busy == null ? onTap : null,
        icon: loading
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
            : Icon(icon, size: 22),
        label: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: primary ? AppColors.brand600 : AppColors.slate50,
          foregroundColor: fg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: primary ? BorderSide.none : BorderSide(color: AppColors.slate300),
          ),
        ),
      ),
    );
  }
}
