import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

enum ToastType { success, error, info }

void showToast(String text, [ToastType type = ToastType.info]) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;

  Color bg;
  switch (type) {
    case ToastType.success:
      bg = const Color(0xFF16A34A);
      break;
    case ToastType.error:
      bg = const Color(0xFFDC2626);
      break;
    case ToastType.info:
      bg = const Color(0xFF334155);
      break;
  }

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
