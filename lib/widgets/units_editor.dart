import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settings.dart';
import '../providers/settings_provider.dart';
import '../utils/app_colors.dart';
import 'toast.dart';

/// Editor daftar satuan barang (tambah / hapus / kembalikan default).
class UnitsEditor extends ConsumerStatefulWidget {
  const UnitsEditor({super.key});

  @override
  ConsumerState<UnitsEditor> createState() => _UnitsEditorState();
}

class _UnitsEditorState extends ConsumerState<UnitsEditor> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save(List<String> units) async {
    await ref.read(settingsProvider.notifier).patchSettings({'units': jsonEncode(units)});
  }

  Future<void> _add(List<String> units) async {
    final u = _ctrl.text.trim();
    if (u.isEmpty) return;
    if (units.any((e) => e.toLowerCase() == u.toLowerCase())) {
      showToast('Satuan "$u" sudah ada.', ToastType.error);
      return;
    }
    await _save([...units, u]);
    _ctrl.clear();
  }

  Future<void> _remove(List<String> units, String u) async {
    if (units.length <= 1) {
      showToast('Minimal harus ada satu satuan.', ToastType.error);
      return;
    }
    await _save(units.where((e) => e != u).toList());
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(settingsProvider).value?.units ?? kDefaultUnits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Satuan di sini akan jadi pilihan dropdown saat membuat nota, mengedit nota, dan menambah produk.',
          style: TextStyle(fontSize: 12, color: AppColors.slate500),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final u in units)
              InputChip(
                label: Text(u, style: TextStyle(fontSize: 15, color: AppColors.brand600)),
                backgroundColor: AppColors.brand50,
                side: BorderSide.none,
                deleteIconColor: AppColors.slate500,
                onDeleted: () => _remove(units, u),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLength: 12,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(units),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Satuan baru (mis. pak)',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.slate200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.slate200)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _add(units),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand600,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(80, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Tambah'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _save(kDefaultUnits),
          child: const Text('Kembalikan ke daftar bawaan'),
        ),
      ],
    );
  }
}
