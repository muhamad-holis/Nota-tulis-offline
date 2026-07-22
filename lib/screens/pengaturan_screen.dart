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
import '../services/image_service.dart';
import '../services/printer_service.dart';
import '../utils/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/settings_section.dart';
import '../widgets/live_field.dart';
import '../widgets/toast.dart';

class PengaturanScreen extends ConsumerStatefulWidget {
  const PengaturanScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final printerUi = ref.watch(printerProvider);

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: const AppHeader(title: 'Pengaturan', showSettings: false),
      body: settingsAsync.when(
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- Informasi Toko ---
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

              // --- Tulisan Atas Nota ---
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
              SettingsSection(
                title: 'Ukuran Kertas',
                child: Row(
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
              ),

              // --- Printer Bluetooth ---
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

              // --- Tentang Aplikasi ---
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
                      'Aplikasi pencatatan nota toko retail yang ringkas, sederhana, mudah digunakan, cepat, dan efisien. Data nota tersimpan langsung di HP.',
                      style: TextStyle(fontSize: 11, color: AppColors.slate400),
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
