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

class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  int _index = 0;

  void _goToSettings() => setState(() => _index = 3);

  @override
  Widget build(BuildContext context) {
    final screens = [
      NotaScreen(onOpenSettings: _goToSettings),
      RiwayatScreen(onOpenSettings: _goToSettings),
      LaporanScreen(onOpenSettings: _goToSettings),
      const PengaturanScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.brand50,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'Nota'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Laporan'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Pengaturan'),
        ],
      ),
    );
  }
}
