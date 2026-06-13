import 'package:flutter/material.dart';

/// Static hero-title screen header (no collapse-on-scroll). Ports only the
/// large-title block of the design's IOSNavBar; the iOS compact sticky row is
/// intentionally omitted. Action buttons keep a >=48px hit target.
class LargeTitleHeader extends StatelessWidget {
  const LargeTitleHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
    this.belowTitle,
  });

  final String title;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? belowTitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasTopRow = leading != null || actions.isNotEmpty;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasTopRow)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  if (leading != null) leading!,
                  const Spacer(),
                  ...actions,
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.64,
                height: 1.12,
                color: cs.onSurface,
              ),
            ),
          ),
          if (belowTitle != null) belowTitle!,
        ],
      ),
    );
  }
}
