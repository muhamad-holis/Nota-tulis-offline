import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/settings.dart';
import '../providers/settings_provider.dart';
import '../providers/printer_provider.dart';
import '../providers/history_provider.dart';
import '../services/backup_service.dart';
import '../services/csv_export_service.dart';
import '../services/image_service.dart';
import '../services/printer_service.dart';
import '../utils/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/settings_section.dart';
import '../widgets/live_field.dart';
import '../widgets/toast.dart';
import 'produk_screen.dart';

/// Halaman Pengaturan terdiri dari menu utama dan beberapa sub-halaman.
enum SettingsGroup { menu, profil, kustom, printer, backup, whatsNew }

class PengaturanScreen extends ConsumerStatefulWidget {
  final SettingsGroup group;
  const PengaturanScreen({super.key, this.group = SettingsGroup.menu});

  @override
  ConsumerState<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends ConsumerState<PengaturanScreen> {
  bool _busyBackup = false;

  Future<void> _requestBluetoothPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _pickAndSetLogo() async {
    final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
    if (result == null) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      showToast('Gagal membaca file gambar.', ToastType.error);
      return;
    }
    try {
      final base64Logo = cropImageToSquareBase64(bytes);
      await ref.read(settingsProvider.notifier).patchSettings({'logo': base64Logo});
    } catch (err) {
      showToast('Gagal mengupload logo: $err', ToastType.error);
    }
  }

  Future<void> _pickAndSetQris() async {
    final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
    if (result == null) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      showToast('Gagal membaca file gambar.', ToastType.error);
      return;
    }
    try {
      final b64 = resizeImageToBase64(bytes);
      await ref.read(settingsProvider.notifier).patchSettings({'qrisImage': b64});
      showToast('Gambar QRIS disimpan', ToastType.success);
    } catch (err) {
      showToast('Gagal mengupload gambar QRIS: $err', ToastType.error);
    }
  }

  Future<void> _openPrinterScanSheet() async {
    await _requestBluetoothPermissions();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PrinterScanSheet(),
    );
  }

  Future<void> _testPrint(Settings settings) async {
    final ok = await ref.read(printerProvider.notifier).testPrint(settings);
    showToast(ok ? 'Test print berhasil' : 'Test print gagal', ok ? ToastType.success : ToastType.error);
  }

  Future<void> _exportBackup() async {
    setState(() => _busyBackup = true);
    try {
      await BackupService.exportBackup();
      showToast('Backup berhasil dibuat', ToastType.success);
    } catch (err) {
      showToast('Gagal membuat backup', ToastType.error);
    } finally {
      if (mounted) setState(() => _busyBackup = false);
    }
  }

  Future<void> _importBackup() async {
    setState(() => _busyBackup = true);
    try {
      await BackupService.importBackupFromPicker();
      ref.invalidate(settingsProvider);
      ref.read(historyRefreshProvider.notifier).state++;
      showToast('Data berhasil dipulihkan', ToastType.success);
    } catch (err) {
      showToast(err.toString(), ToastType.error);
    } finally {
      if (mounted) setState(() => _busyBackup = false);
    }
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus semua riwayat nota?'),
        content: const Text(
          'Semua nota belanja yang tersimpan akan dihapus permanen dan tidak bisa dikembalikan. Produk dan pengaturan toko tidak akan terpengaruh.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Hapus Semua', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await clearAllNotasAndRefresh(ref);
      showToast('Semua riwayat nota berhasil dihapus', ToastType.success);
    }
  }

  bool _in(SettingsGroup g) => widget.group == g;

  String _titleFor(SettingsGroup g) {
    switch (g) {
      case SettingsGroup.menu:
        return 'Pengaturan';
      case SettingsGroup.profil:
        return 'Profil Bisnis';
      case SettingsGroup.kustom:
        return 'Kustomisasi Nota';
      case SettingsGroup.printer:
        return 'Printer Bluetooth';
      case SettingsGroup.backup:
        return 'Backup & Restore';
      case SettingsGroup.whatsNew:
        return 'Apa yang Baru';
    }
  }

  void _openGroup(SettingsGroup g) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PengaturanScreen(group: g)));
  }

  Future<void> _exportCsv() async {
    try {
      final count = await exportNotasCsv();
      showToast('$count nota diekspor ke CSV', ToastType.success);
    } catch (err) {
      showToast(err.toString().replaceFirst('Exception: ', ''), ToastType.error);
    }
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.slate100),
              ),
              child: Icon(icon, size: 28, color: AppColors.brand600),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.brand600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 15, color: AppColors.slate500, height: 1.3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu() {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: const AppHeader(title: 'Pengaturan', showSettings: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _menuTile(
            icon: Icons.storefront_outlined,
            title: 'Profil Bisnis',
            subtitle: 'Logo, Nama, Alamat, QRIS',
            onTap: () => _openGroup(SettingsGroup.profil),
          ),
          _menuTile(
            icon: Icons.style_outlined,
            title: 'Kustomisasi Nota',
            subtitle: 'Teks Atas & Bawah, Ukuran Kertas',
            onTap: () => _openGroup(SettingsGroup.kustom),
          ),
          _menuTile(
            icon: Icons.inventory_2_outlined,
            title: 'Produk Saya',
            subtitle: 'Kelola daftar produk, harga & satuan',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProdukScreen())),
          ),
          _menuTile(
            icon: Icons.bluetooth,
            title: 'Printer Bluetooth',
            subtitle: 'Pilih printer thermal & tes cetak',
            onTap: () => _openGroup(SettingsGroup.printer),
          ),
          Divider(color: AppColors.slate200, height: 24),
          _menuTile(
            icon: Icons.file_download_outlined,
            title: 'Export Data CSV',
            subtitle: 'Simpan data nota ke spreadsheet',
            onTap: _exportCsv,
          ),
          _menuTile(
            icon: Icons.cloud_upload_outlined,
            title: 'Backup & Restore',
            subtitle: 'Cadangkan dan pulihkan data',
            onTap: () => _openGroup(SettingsGroup.backup),
          ),
          Divider(color: AppColors.slate200, height: 24),
          _menuTile(
            icon: Icons.new_releases_outlined,
            title: 'Apa yang Baru',
            subtitle: 'Riwayat fitur & perbaikan tiap versi',
            onTap: () => _openGroup(SettingsGroup.whatsNew),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.group == SettingsGroup.menu) return _buildMenu();
    final settingsAsync = ref.watch(settingsProvider);
    final printerUi = ref.watch(printerProvider);

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppHeader(title: _titleFor(widget.group), showSettings: false),
      body: settingsAsync.when(
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- Informasi Toko ---
              if (_in(SettingsGroup.profil))
              SettingsSection(
                title: 'Informasi Toko',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _pickAndSetLogo,
                          child: Container(
                            width: 64,
                            height: 64,
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.slate300, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(16),
                              color: AppColors.slate50,
                            ),
                            child: settings.logo != null
                                ? Image.memory(base64Decode(settings.logo!), fit: BoxFit.cover)
                                : Icon(Icons.add_photo_alternate_outlined, color: AppColors.slate400),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextButton(
                              onPressed: _pickAndSetLogo,
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                              child: Text('Ubah Logo Toko', style: TextStyle(color: AppColors.brand600, fontSize: 13)),
                            ),
                            Text('Logo otomatis dipotong persegi', style: TextStyle(fontSize: 11, color: AppColors.slate400)),
                          ],
                        ),
                      ],
                    ),
                    if (settings.logo != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tampilkan Logo di Struk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate700)),
                                  Text('Matikan kalau printer tidak butuh logo', style: TextStyle(fontSize: 11, color: AppColors.slate400)),
                                ],
                              ),
                            ),
                            Switch(
                              value: settings.showLogo,
                              onChanged: (v) => ref.read(settingsProvider.notifier).patchSettings({'showLogo': v ? 1 : 0}),
                              activeColor: AppColors.brand600,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _labeledField('Nama Toko', settings.storeName, (v) => ref.read(settingsProvider.notifier).patchSettings({'storeName': v})),
                    const SizedBox(height: 10),
                    _labeledField('Alamat', settings.address, (v) => ref.read(settingsProvider.notifier).patchSettings({'address': v})),
                    const SizedBox(height: 10),
                    _labeledField('Nomor HP', settings.phone, (v) => ref.read(settingsProvider.notifier).patchSettings({'phone': v})),
                  ],
                ),
              ),

              // --- Pembayaran QRIS ---
              if (_in(SettingsGroup.profil))
              SettingsSection(
                title: 'Pembayaran QRIS',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gambar ini akan tampil saat metode pembayaran QRIS dipilih dan kamu menekan Simpan Nota.',
                      style: TextStyle(fontSize: 12, color: AppColors.slate500),
                    ),
                    const SizedBox(height: 12),
                    if (settings.qrisImage != null)
                      Center(
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.slate200),
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white,
                          ),
                          child: Image.memory(base64Decode(settings.qrisImage!), fit: BoxFit.contain),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickAndSetQris,
                            icon: Icon(Icons.qr_code_2, color: AppColors.brand600),
                            label: Text(settings.qrisImage == null ? 'Tambah Gambar QRIS' : 'Ganti Gambar QRIS',
                                style: TextStyle(color: AppColors.brand600)),
                          ),
                        ),
                        if (settings.qrisImage != null) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => ref.read(settingsProvider.notifier).patchSettings({'qrisImage': null}),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // --- Tulisan Atas Nota ---
              if (_in(SettingsGroup.kustom))
              SettingsSection(
                title: 'Tulisan Atas Nota',
                child: _labeledField(
                  null,
                  settings.headerText,
                  (v) => ref.read(settingsProvider.notifier).patchSettings({'headerText': v}),
                  multiline: true,
                  hint: 'TERIMA KASIH\nSELAMAT DATANG',
                ),
              ),

              // --- Tulisan Bawah Nota ---
              if (_in(SettingsGroup.kustom))
              SettingsSection(
                title: 'Tulisan Bawah Nota',
                child: _labeledField(
                  null,
                  settings.footerText,
                  (v) => ref.read(settingsProvider.notifier).patchSettings({'footerText': v}),
                  multiline: true,
                  hint: 'Terima kasih atas kepercayaan Anda.',
                ),
              ),

              // --- Ukuran Kertas ---
              if (_in(SettingsGroup.kustom))
              SettingsSection(
                title: 'Ukuran Kertas',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (final size in ['58', '80'])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: OutlinedButton(
                                onPressed: () => ref.read(settingsProvider.notifier).patchSettings({'paperSize': size}),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: settings.paperSize == size ? AppColors.brand50 : null,
                                  foregroundColor: settings.paperSize == size ? AppColors.brand700 : AppColors.slate600,
                                  side: BorderSide(color: settings.paperSize == size ? AppColors.brand500 : AppColors.slate200),
                                ),
                                child: Text('$size mm'),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Font Kecil (kondensasi)',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate700)),
                                const SizedBox(height: 2),
                                Text(
                                  settings.paperSize == '58'
                                      ? (settings.smallFont
                                          ? 'Aktif: nama barang dapat ruang lebih lega (setara tampilan 80mm), tapi tulisan jadi lebih kecil/rapat.'
                                          : 'Muat lebih banyak kolom (setara tampilan 80mm) di kertas 58mm, tulisannya jadi lebih kecil. Coba Test Print dulu sebelum dipakai.')
                                      : 'Cuma berpengaruh kalau Ukuran Kertas di atas dipilih 58mm.',
                                  style: TextStyle(fontSize: 11, color: AppColors.slate400),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: settings.smallFont,
                            onChanged: (v) => ref.read(settingsProvider.notifier).patchSettings({'smallFont': v ? 1 : 0}),
                            activeColor: AppColors.brand600,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- Printer Bluetooth ---
              if (_in(SettingsGroup.printer))
              SettingsSection(
                title: 'Printer Bluetooth',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Icon(Icons.bluetooth,
                              size: 18,
                              color: printerUi.status == PrinterStatus.connected ? AppColors.brand600 : AppColors.slate400),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(settings.printer?.name ?? 'Belum terhubung',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate700)),
                                Text(_statusLabel(printerUi.status, settings.printer != null),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: printerUi.status == PrinterStatus.connected ? AppColors.emerald600 : AppColors.slate400)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: printerUi.connecting ? null : _openPrinterScanSheet,
                            icon: const Icon(Icons.bluetooth_searching, size: 16),
                            label: Text(printerUi.connecting
                                ? 'Mencari...'
                                : (printerUi.status == PrinterStatus.connected ? 'Ganti Printer' : 'Cari Printer')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (printerUi.printing || settings.printer == null) ? null : () => _testPrint(settings),
                            icon: const Icon(Icons.print, size: 16),
                            label: const Text('Test Print'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate100, foregroundColor: AppColors.slate700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // --- Backup Database ---
              if (_in(SettingsGroup.backup))
              SettingsSection(
                title: 'Backup Database',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busyBackup ? null : _exportBackup,
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Export JSON'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _busyBackup ? null : _importBackup,
                            icon: const Icon(Icons.upload, size: 16),
                            label: const Text('Import JSON'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate100, foregroundColor: AppColors.slate700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Import JSON akan mengganti seluruh data produk, nota, dan pengaturan saat ini.',
                        style: TextStyle(fontSize: 11, color: AppColors.slate400)),
                  ],
                ),
              ),

              // --- Zona Berbahaya ---
              if (_in(SettingsGroup.backup))
              SettingsSection(
                title: 'Zona Berbahaya',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hapus semua riwayat transaksi nota agar database kembali kosong. Data produk dan pengaturan toko tidak ikut terhapus.',
                      style: TextStyle(fontSize: 11, color: AppColors.slate400),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _confirmClearHistory,
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Hapus Semua Riwayat Nota'),
                    ),
                  ],
                ),
              ),

              // --- Riwayat Versi ---
              if (_in(SettingsGroup.whatsNew))
                SettingsSection(
                  title: 'Tampilan Baru',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in const [
                        'Halaman utama berisi daftar nota dengan tab Semua / Tunai / QRIS.',
                        'Buat Nota dengan kartu item (Jumlah, Satuan, Harga Satuan) dan Katalog.',
                        'Metode pembayaran Tunai atau QRIS; QRIS menampilkan gambar QRIS dan jumlah yang harus dibayar.',
                        'Detail Nota halaman penuh: Share WhatsApp, Simpan sebagai gambar, dan Cetak.',
                        'Pengaturan baru berupa menu: Profil Bisnis, Kustomisasi Nota, Produk Saya, Printer, Export CSV, Backup.',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('\u2022 ', style: TextStyle(color: AppColors.slate500)),
                              Expanded(child: Text(line, style: TextStyle(fontSize: 13, color: AppColors.slate600))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

              // --- Tentang Aplikasi ---
              if (_in(SettingsGroup.whatsNew))
              SettingsSection(
                title: 'Tentang Aplikasi',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Nota Tulis', style: TextStyle(color: AppColors.slate500)),
                        Text('Versi 1.0.0', style: TextStyle(color: AppColors.slate400)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aplikasi pencatatan nota toko retail yang ringkas, sederhana, mudah digunakan, cepat, dan efisien. Data nota tersimpan langsung di HP masing-masing.',
                      style: TextStyle(fontSize: 11, color: AppColors.slate400),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: AppColors.slate200, height: 1),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        '© 2026 Dibuat oleh Muhamad Holis',
                        style: TextStyle(fontSize: 11, color: AppColors.slate400),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat pengaturan: $e')),
      ),
    );
  }

  String _statusLabel(PrinterStatus status, bool hasPrinterSaved) {
    switch (status) {
      case PrinterStatus.connected:
        return 'Terhubung';
      case PrinterStatus.reconnecting:
        return 'Menyambungkan ulang...';
      case PrinterStatus.connecting:
        return 'Mencari...';
      case PrinterStatus.disconnected:
        return hasPrinterSaved ? 'Terputus' : 'Belum terhubung';
    }
  }

  Widget _labeledField(String? label, String value, ValueChanged<String> onChanged,
      {bool multiline = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.slate500)),
          const SizedBox(height: 4),
        ],
        LiveField(
          value: value,
          onCommit: onChanged,
          multiline: multiline,
          rows: 3,
          placeholder: hint,
        ),
      ],
    );
  }
}

class _PrinterScanSheet extends ConsumerStatefulWidget {
  const _PrinterScanSheet();

  @override
  ConsumerState<_PrinterScanSheet> createState() => _PrinterScanSheetState();
}

class _PrinterScanSheetState extends ConsumerState<_PrinterScanSheet> {
  @override
  void initState() {
    super.initState();
    PrinterService.instance.scanResults();
  }

  @override
  void dispose() {
    PrinterService.instance.stopScan();
    super.dispose();
  }

  Future<void> _connect(BluetoothDevice device) async {
    final info = await ref.read(printerProvider.notifier).connectTo(device);
    if (info != null) {
      await ref.read(settingsProvider.notifier).patchSettings({'printerId': info['id'], 'printerName': info['name']});
      showToast('Terhubung ke ${info['name']}', ToastType.success);
      if (mounted) Navigator.of(context).pop();
    } else {
      showToast('Gagal terhubung ke printer', ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Printer Bluetooth', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Pastikan printer sudah menyala dan dalam jangkauan.', style: TextStyle(fontSize: 12, color: AppColors.slate400)),
            const SizedBox(height: 12),
            Flexible(
              child: StreamBuilder<List<ScanResult>>(
                stream: FlutterBluePlus.scanResults,
                initialData: const [],
                builder: (context, snapshot) {
                  final results = snapshot.data ?? [];
                  if (results.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final r = results[index];
                      final name = r.device.platformName.isNotEmpty ? r.device.platformName : r.device.remoteId.str;
                      return ListTile(
                        leading: const Icon(Icons.print_outlined),
                        title: Text(name),
                        onTap: () => _connect(r.device),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
