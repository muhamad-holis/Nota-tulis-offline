import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onPrint;
  final VoidCallback onNewNota;
  final VoidCallback onShareWhatsApp;
  final bool saving;
  final bool printing;
  final bool sharing;

  const ActionButtons({
    super.key,
    required this.onSave,
    required this.onPrint,
    required this.onNewNota,
    required this.onShareWhatsApp,
    this.saving = false,
    this.printing = false,
    this.sharing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
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
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _btn(
            label: 'Bagikan ke WhatsApp',
            icon: Icons.share_outlined,
            onTap: sharing ? null : onShareWhatsApp,
            bg: Colors.white,
            fg: const Color(0xFF128C4A),
            border: const Color(0xFF128C4A),
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
