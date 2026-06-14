import 'package:flutter/material.dart';

/// Single-choice bottom sheet. Returns the chosen value, or null if dismissed.
/// Pure presentation — the caller persists (prefs setter + ref.invalidate).
Future<T?> showSettingPicker<T>(
  BuildContext context, {
  required String title,
  required List<(String, T)> options,
  required T current,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          for (final (label, value) in options)
            ListTile(
              title: Text(label),
              trailing: value == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(sheetCtx, value),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
