import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/report_provider.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';

class LaporanScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenSettings;
  const LaporanScreen({super.key, required this.onOpenSettings});

  @override
  ConsumerState<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends ConsumerState<LaporanScreen> {
  ReportPeriod _period = ReportPeriod.today;

  static const _periods = [
    (ReportPeriod.today, 'Hari Ini'),
    (ReportPeriod.week, 'Minggu Ini'),
    (ReportPeriod.month, 'Bulan Ini'),
  ];

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportProvider(_period));

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppHeader(title: 'Laporan', onSettingsTap: widget.onOpenSettings),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                for (final p in _periods)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _period = p.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _period == p.$1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          p.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _period == p.$1 ? AppColors.brand600 : AppColors.slate500,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          reportAsync.when(
            data: (report) {
              if (report.jumlahNota == 0) {
                return const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Belum ada nota',
                  description: 'Laporan akan muncul otomatis setelah ada nota yang disimpan pada periode ini.',
                );
              }
              return Column(
                children: [
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.trending_up, size: 16, color: AppColors.brand600),
                          const SizedBox(width: 8),
                          Text('Omzet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate500)),
                        ]),
                        const SizedBox(height: 4),
                        Text(formatRupiah(report.omzet),
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.slate800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.receipt_outlined, size: 16, color: AppColors.brand600),
                                const SizedBox(width: 6),
                                Text('Jumlah Nota', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate500)),
                              ]),
                              const SizedBox(height: 4),
                              Text('${report.jumlahNota}',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.slate800)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.brand600),
                                const SizedBox(width: 6),
                                Text('Rata-rata/Nota', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate500)),
                              ]),
                              const SizedBox(height: 4),
                              Text(formatRupiah(report.rataRataPerNota),
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.slate800)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.brand600),
                          const SizedBox(width: 8),
                          Text('Barang Terlaris', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate500)),
                        ]),
                        const SizedBox(height: 12),
                        if (report.topItems.isEmpty)
                          Text('Belum ada barang tercatat.', style: TextStyle(fontSize: 12, color: AppColors.slate400))
                        else
                          for (int i = 0; i < report.topItems.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(color: AppColors.brand50, shape: BoxShape.circle),
                                    child: Text('${i + 1}',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.brand600)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(report.topItems[i].name,
                                            overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: AppColors.slate700)),
                                        Text('${formatQty(report.topItems[i].qty)} terjual',
                                            style: TextStyle(fontSize: 11, color: AppColors.slate400)),
                                      ],
                                    ),
                                  ),
                                  Text(formatRupiah(report.topItems[i].total),
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate600)),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(padding: const EdgeInsets.only(top: 48), child: Center(child: Text('Gagal memuat laporan: $e'))),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.slate100),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
