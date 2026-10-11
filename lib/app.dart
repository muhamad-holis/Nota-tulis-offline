import 'package:flutter/material.dart';
import 'screens/nota_screen.dart';
import 'screens/riwayat_screen.dart';
import 'screens/laporan_screen.dart';
import 'screens/pengaturan_screen.dart';
import 'utils/app_colors.dart';
import 'widgets/toast.dart';

class NotaTulisApp extends StatelessWidget {
  const NotaTulisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nota Tulis',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.brand600,
        scaffoldBackgroundColor: AppColors.slate50,
        fontFamily: 'Roboto',
      ),
      home: const _RootShell(),
    );
  }
}

/// Halaman utama = daftar nota. Laporan, Pengaturan, dan Buat Nota dibuka sebagai halaman penuh.
class _RootShell extends StatelessWidget {
  const _RootShell();

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PengaturanScreen()));
  }

  void _openLaporan(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LaporanScreen(onOpenSettings: () => _openSettings(context)),
    ));
  }

  void _createNota(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotaScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return RiwayatScreen(
      onOpenSettings: () => _openSettings(context),
      onOpenLaporan: () => _openLaporan(context),
      onCreateNota: () => _createNota(context),
    );
  }
}
