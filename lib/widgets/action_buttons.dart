import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onPrint;
  final VoidCallback onNewNota;
  final bool saving;
  final bool printing;

  const ActionButtons({
    super.key,
    required this.onSave,
    required this.onPrint,
    required this.onNewNota,
    this.saving = false,
    this.printing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _btn(
            label: 'Simpan',
            icon: Icons.save_outlined,
            onTap: saving ? null : onSave,
            bg: AppColors.slate100,
            fg: AppColors.slate700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _btn(
            label: 'Cetak',
            icon: Icons.print_outlined,
            onTap: printing ? null : onPrint,
            bg: AppColors.brand600,
            fg: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _btn(
            label: 'Nota Baru',
            icon: Icons.note_add_outlined,
            onTap: onNewNota,
            bg: Colors.white,
            fg: AppColors.slate700,
            border: AppColors.slate200,
          ),
        ),
      ],
    );
  }

  Widget _btn({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required Color bg,
    required Color fg,
    Color? border,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: border != null ? BorderSide(color: border) : BorderSide.none,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
