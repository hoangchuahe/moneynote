import 'package:flutter/material.dart';
import 'package:moneynote/core/theme.dart';

/// Inset grouped-list section (the design's IOSListGroup): a rounded surface
/// card with optional header/footer caption, holding [children] rows separated
/// by inset hairlines. A single-child section draws no divider. Headers are
/// mixed-case — the brand forbids ALL-CAPS Vietnamese (diacritics).
class InsetSection extends StatelessWidget {
  const InsetSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
  });

  final String? header;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final caption = TextStyle(fontSize: 13, color: cs.onSurfaceVariant);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider(height: 0.5, thickness: 0.5, indent: 56));
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text(header!, style: caption),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          clipBehavior: Clip.antiAlias, // keep row InkWell ripples inside the radius
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant, width: 0.6),
          ),
          child: Column(children: rows),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Text(footer!, style: caption),
          ),
      ],
    );
  }
}

/// A single row inside an [InsetSection]: leading icon · title · trailing value.
/// The 24-wide leading slot is always reserved (even when null) so titles align
/// and the section's 56px divider indent matches the content start.
class InsetRow extends StatelessWidget {
  const InsetRow({
    super.key,
    this.leading,
    required this.title,
    this.value,
    this.onTap,
    this.destructive = false,
    this.wrap = false,
    this.trailing,
  });

  final Widget? leading;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;
  final bool wrap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleColor =
        destructive ? moneyColorsOf(context).expense : cs.onSurface;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: leading == null ? null : Center(child: leading),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                maxLines: wrap ? null : 1,
                overflow: wrap ? TextOverflow.clip : TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: titleColor),
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(value!,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant)),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}
