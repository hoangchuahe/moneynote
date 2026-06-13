import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/core/widgets/empty_state.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/recurring.dart';
import 'package:moneynote/features/recurring/recurring_edit_screen.dart';
import 'package:moneynote/state/providers.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(recurringsProvider).valueOrNull ?? [];
    final cats = {
      for (final c in ref.watch(categoriesProvider).valueOrNull ?? []) c.id: c.name
    };
    final mc = moneyColorsOf(context);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Giao dịch định kỳ')),
      floatingActionButton: FloatingActionButton(
        key: const Key('addRecurring'),
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RecurringEditScreen())),
        child: const Icon(Icons.add),
      ),
      body: rules.isEmpty
          ? const EmptyState(
              icon: Icons.repeat,
              title: 'Chưa có giao dịch định kỳ',
              hint: 'Bấm + để thêm quy tắc tự lặp')
          : ListView(
              children: [
                for (final r in rules)
                  Dismissible(
                    key: Key('dismiss_${r.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: mc.expense,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async =>
                        await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            content: const Text('Xoá định kỳ này?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Huỷ')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Xoá')),
                            ],
                          ),
                        ) ??
                        false,
                    onDismissed: (_) =>
                        ref.read(repositoryProvider).softDeleteRecurring(r.id),
                    child: ListTile(
                      leading: Icon(Icons.repeat,
                          color: r.type == TransactionType.income
                              ? mc.income
                              : mc.expense),
                      title: Text(formatVnd(r.amount)),
                      subtitle: Text(
                          '${cats[r.categoryId] ?? 'Chưa phân loại'} · '
                          '${cycleLabel(r.cycle)} · '
                          'Kỳ tới: ${formatDmy(nextOccurrenceAfter(r.startDate, r.cycle, now))}'),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => RecurringEditScreen(existing: r))),
                    ),
                  ),
              ],
            ),
    );
  }
}
