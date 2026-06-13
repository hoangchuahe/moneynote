import 'dart:math' as math;

import 'package:flutter/material.dart';

const double kPillSlot = 50;
const double kPillPad = 7;
const double kPillGap = 4;
const double kPillRaise = 18;

/// Resting offset of the floating pill above the safe-area bottom.
/// Windows desktop (inset 0) → 16; Android uses the live gesture-nav inset.
double pillBottomOffset(BuildContext context) =>
    math.max(MediaQuery.of(context).viewPadding.bottom, 10) + 6;

/// Bottom space every shell screen's scroll content (and in-shell SnackBars)
/// must reserve so nothing hides behind the floating pill. Single source of
/// truth — used by each scrollable's padding and the Transactions undo toast.
double pillClearance(BuildContext context) =>
    MediaQuery.of(context).viewPadding.bottom + 96;

/// The floating pill bottom nav: 4 tabs + a raised center "+" action.
/// Visual order is [tab0, tab1, +, tab2, tab3]; the action is never "selected".
/// All colours come from [Theme], so all four theme variants work unchanged.
class FloatingPillNav extends StatelessWidget {
  const FloatingPillNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAdd,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(kPillPad),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: cs.onSurface.withValues(alpha: 0.06), width: 0.5),
        boxShadow: [
          BoxShadow(
              color: cs.onSurface.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 8)),
          BoxShadow(
              color: cs.onSurface.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab(context,
              page: 0,
              label: 'Tổng quan',
              filled: Icons.pie_chart,
              outlined: Icons.pie_chart_outline),
          const SizedBox(width: kPillGap),
          _tab(context,
              page: 1,
              label: 'Giao dịch',
              filled: Icons.receipt_long,
              outlined: Icons.receipt_long_outlined),
          const SizedBox(width: kPillGap),
          _addButton(context),
          const SizedBox(width: kPillGap),
          _tab(context,
              page: 2,
              label: 'Ví',
              filled: Icons.account_balance_wallet,
              outlined: Icons.account_balance_wallet_outlined),
          const SizedBox(width: kPillGap),
          _tab(context,
              page: 3,
              label: 'Danh mục',
              filled: Icons.grid_view,
              outlined: Icons.grid_view),
        ],
      ),
    );
  }

  Widget _tab(
    BuildContext context, {
    required int page,
    required String label,
    required IconData filled,
    required IconData outlined,
  }) {
    final cs = Theme.of(context).colorScheme;
    final selected = page == selectedIndex;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(page),
      child: Container(
        key: Key('navTab_$page'),
        width: kPillSlot,
        height: kPillSlot,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : null,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Tooltip(
          message: label,
          child: Icon(
            selected ? filled : outlined,
            size: 25,
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _addButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 64, // 60 circle + 2px breathing each side (design marginInline:2)
      height: kPillSlot,
      child: OverflowBox(
        maxHeight: double.infinity,
        child: Transform.translate(
          offset: const Offset(0, -kPillRaise),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAdd,
            child: Container(
              key: const Key('navAdd'),
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: cs.primary.withValues(alpha: 0.50),
                      blurRadius: 18,
                      offset: const Offset(0, 6)),
                  BoxShadow(
                      color: cs.onSurface.withValues(alpha: 0.16),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Icon(Icons.add, size: 30, color: cs.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
