import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/nota.dart';
import '../models/settings.dart';
import '../services/receipt_text.dart';

class ReceiptPreview extends StatelessWidget {
  final Nota nota;
  final Settings settings;

  const ReceiptPreview({super.key, required this.nota, required this.settings});

  @override
  Widget build(BuildContext context) {
    final lines = buildReceiptLines(nota, settings);
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          if (settings.logo != null && settings.showLogo)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Image.memory(base64Decode(settings.logo!), height: 48, width: 48, fit: BoxFit.contain),
            ),
          for (final l in lines)
            Align(
              alignment: l.align == 'center' ? Alignment.center : Alignment.centerLeft,
              child: Text(
                l.text.isEmpty ? '\u00A0' : l.text,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: l.bold ? FontWeight.bold : FontWeight.normal,
                  color: Colors.black87,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
