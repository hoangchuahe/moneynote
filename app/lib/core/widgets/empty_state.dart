import 'package:flutter/material.dart';

/// Trạng thái rỗng thân thiện: icon nhạt + tiêu đề + gợi ý hành động.
/// QUAN TRỌNG: title là Text riêng để các test find.text khớp chính xác.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;
  const EmptyState(
      {super.key, required this.icon, required this.title, this.hint});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint!,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
