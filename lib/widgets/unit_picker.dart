import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settings.dart';
import '../providers/settings_provider.dart';
import '../utils/app_colors.dart';

/// Bottom sheet pilihan satuan. Mengembalikan satuan yang dipilih (null kalau ditutup).
Future<String?> showUnitPicker(
  BuildContext context, {
  required List<String> units,
  String? current,
}) {
  final options = [...units];
  final cur = (current ?? '').trim();
  // Satuan lama yang sudah tidak ada di daftar tetap ditampilkan supaya tidak hilang.
  if (cur.isNotEmpty && !options.contains(cur)) options.insert(0, cur);

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Pilih Satuan',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.brand600)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Daftar satuan diatur di Pengaturan > Satuan Barang.',
                    style: TextStyle(fontSize: 12, color: AppColors.slate400)),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  for (final u in options)
                    ListTile(
                      onTap: () => Navigator.of(ctx).pop(u),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      title: Text(u,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: u == cur ? FontWeight.w800 : FontWeight.w500,
                              color: AppColors.slate800)),
                      trailing: u == cur ? Icon(Icons.check_circle, color: AppColors.brand600) : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Kotak pilihan satuan (dropdown). Dipakai di form nota, edit nota, dan produk.
class UnitSelectField extends ConsumerWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final double fontSize;

  const UnitSelectField({
    super.key,
    required this.value,
    required this.onChanged,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(settingsProvider).value?.units ?? kDefaultUnits;
    final text = value.trim();
    return InkWell(
      onTap: () async {
        final picked = await showUnitPicker(context, units: units, current: text);
        if (picked != null) onChanged(picked);
      },
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.isEmpty ? 'Satuan' : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: fontSize, color: text.isEmpty ? AppColors.slate300 : AppColors.slate800),
            ),
          ),
          Icon(Icons.arrow_drop_down, color: AppColors.brand600),
        ],
      ),
    );
  }
}
