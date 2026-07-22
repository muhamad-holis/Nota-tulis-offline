import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showSettings;
  final VoidCallback? onSettingsTap;

  const AppHeader({super.key, required this.title, this.showSettings = true, this.onSettingsTap});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.slate800)),
      actions: [
        if (showSettings)
          IconButton(
            icon: Icon(Icons.settings_outlined, color: AppColors.slate500),
            onPressed: onSettingsTap,
          ),
        const SizedBox(width: 4),
      ],
      shape: Border(bottom: BorderSide(color: AppColors.slate100)),
    );
  }
}
