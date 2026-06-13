import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/input_formatters.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/widgets/inset_section.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/features/wallets/wallets_screen.dart';
import 'package:moneynote/state/providers.dart';

class WalletEditScreen extends ConsumerStatefulWidget {
  const WalletEditScreen({super.key, this.existing});

  final Wallet? existing;

  @override
  ConsumerState<WalletEditScreen> createState() => _WalletEditScreenState();
}

class _WalletEditScreenState extends ConsumerState<WalletEditScreen> {
  late final TextEditingController _nameCtrl;
  final _balCtrl = TextEditingController(text: '0');
  late WalletType _type;
  late int _color;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final w = widget.existing;
    _nameCtrl = TextEditingController(text: w?.name ?? '');
    _type = w?.type ?? WalletType.cash;
    _color = w?.color ?? kWalletColors.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Nhập tên ví')));
      return;
    }
    final navigator = Navigator.of(context);
    final repo = ref.read(repositoryProvider);
    if (_isEditing) {
      await repo.updateWallet(
          id: widget.existing!.id, name: name, type: _type, color: _color);
    } else {
      await repo.addWallet(
          name: name,
          type: _type,
          color: _color,
          initialBalance: parseVndInput(_balCtrl.text));
    }
    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onPreview =
        ThemeData.estimateBrightnessForColor(Color(_color)) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa ví' : 'Thêm ví'),
        actions: [
          TextButton(
            key: const Key('saveWallet'),
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
              child: Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color(_color),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Color(_color).withAlpha(64),
                        blurRadius: 16,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Icon(walletTypeIcon(_type), size: 36, color: onPreview),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              key: const Key('walletName'),
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Tên ví'),
            ),
          ),
          if (!_isEditing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                key: const Key('walletBalance'),
                controller: _balCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsInputFormatter()],
                decoration: const InputDecoration(labelText: 'Số dư ban đầu'),
              ),
            ),
          InsetSection(
            header: 'Loại ví',
            children: [
              for (final t in WalletType.values)
                InsetRow(
                  leading: WalletIconBox(color: _color, type: t, size: 24),
                  title: walletTypeLabel(t),
                  onTap: () => setState(() => _type = t),
                  trailing: _type == t
                      ? Icon(Icons.check, size: 22, color: cs.primary)
                      : null,
                ),
            ],
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
                for (final c in kWalletColors)
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
