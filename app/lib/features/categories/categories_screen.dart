import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/category_visuals.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/features/categories/category_detail_screen.dart';
import 'package:moneynote/features/home/widgets/floating_pill_nav.dart';
import 'package:moneynote/state/providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider).valueOrNull ?? [];
    final expense = cats.where((c) => c.type == CategoryType.expense).toList();
    final income = cats.where((c) => c.type == CategoryType.income).toList();
    return ListView(
      padding: EdgeInsets.only(bottom: pillClearance(context)),
      children: [
        _header(context, 'Chi'),
        for (final c in expense) _tile(context, ref, c),
        _header(context, 'Thu'),
        for (final c in income) _tile(context, ref, c),
      ],
    );
  }

  Widget _header(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(t, style: Theme.of(c).textTheme.titleSmall),
      );

  Widget _tile(BuildContext context, WidgetRef ref, Category c) => ListTile(
        leading: CategoryIconBox(iconName: c.icon, color: c.color),
        title: Text(c.name),
        onTap: () => openCategoryDetail(context, c.id),
        onLongPress: () => _confirmDelete(context, ref, c),
      );

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xoá danh mục "${c.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xoá')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(repositoryProvider).softDeleteCategory(c.id);
    }
  }
}
