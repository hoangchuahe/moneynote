import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/category_visuals.dart';
import 'package:moneynote/core/widgets/inset_section.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/state/providers.dart';

/// Add/edit a category: name, type (Chi/Thu), an icon picker and a colour
/// picker, with a live preview. Replaces the old showAddCategoryDialog.
class CategoryEditScreen extends ConsumerStatefulWidget {
  const CategoryEditScreen({super.key, this.existing});

  final Category? existing;

  @override
  ConsumerState<CategoryEditScreen> createState() => _CategoryEditScreenState();
}

class _CategoryEditScreenState extends ConsumerState<CategoryEditScreen> {
  late final TextEditingController _nameCtrl;
  late CategoryType _type;
  late String _icon;
  late int _color;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _type = c?.type ?? CategoryType.expense;
    _icon = c?.icon ?? 'category';
    _color = c?.color ?? kCategoryColors.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Nhập tên danh mục')));
      return;
    }
    final navigator = Navigator.of(context);
    final repo = ref.read(repositoryProvider);
    if (_isEditing) {
      await repo.updateCategory(
          id: widget.existing!.id,
          name: name,
          type: _type,
          icon: _icon,
          color: _color);
    } else {
      await repo.addCategory(
          name: name, type: _type, icon: _icon, color: _color);
    }
    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa danh mục' : 'Thêm danh mục'),
        actions: [
          TextButton(
            key: const Key('saveCategory'),
            onPressed: _save,
            child: const Text('Lưu'),
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: CategoryIconBox(
                key: const Key('categoryPreview'),
                iconName: _icon,
                color: _color,
                size: 72,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              key: const Key('categoryName'),
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Tên danh mục'),
            ),
          ),
          InsetSection(
            header: 'Loại',
            children: [
              for (final t in const [CategoryType.expense, CategoryType.income])
                InsetRow(
                  title: t == CategoryType.expense ? 'Chi' : 'Thu',
                  onTap: () => setState(() => _type = t),
                  trailing: _type == t
                      ? Icon(Icons.check, size: 22, color: cs.primary)
                      : null,
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text('Biểu tượng',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final n in kCategoryIconNames)
                  GestureDetector(
                    key: Key('icon_$n'),
                    onTap: () => setState(() => _icon = n),
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: _icon == n
                            ? Border.all(color: cs.primary, width: 2)
                            : null,
                      ),
                      child:
                          CategoryIconBox(iconName: n, color: _color, size: 40),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text('Màu',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final c in kCategoryColors)
                  GestureDetector(
                    key: Key('swatch_$c'),
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        boxShadow: _color == c
                            ? [
                                BoxShadow(color: cs.surface, spreadRadius: 2),
                                BoxShadow(color: Color(c), spreadRadius: 4),
                              ]
                            : null,
                      ),
                      child: _color == c
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
