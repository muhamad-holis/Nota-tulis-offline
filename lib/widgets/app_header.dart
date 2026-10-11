import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showSettings;
  final VoidCallback? onSettingsTap;

  const AppHeader({super.key, required this.title, this.showSettings = true, this.onSettingsTap});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.header,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 64,
      iconTheme: IconThemeData(color: AppColors.brand600),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, color: AppColors.brand600)),
      actions: [
        if (showSettings)
          IconButton(
            icon: Icon(Icons.settings_outlined, color: AppColors.brand600),
            onPressed: onSettingsTap,
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}
