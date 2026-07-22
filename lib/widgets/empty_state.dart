import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const EmptyState({super.key, required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.slate300),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate600),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(description,
              style: TextStyle(fontSize: 13, color: AppColors.slate400), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
