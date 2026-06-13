import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/domain/csv_export.dart';
import 'package:moneynote/state/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  bool _urlLoaded = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(prefsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (prefs) {
          if (!_urlLoaded) {
            _urlCtrl.text = prefs.baseUrl;
            _urlLoaded = true;
          }
          return ListView(
            children: [
              const _SectionHeader('Giọng điệu AI'),
              RadioGroup<Tone>(
                groupValue: prefs.tone,
                onChanged: (v) async {
                  if (v == null) return;
                  await prefs.setTone(v);
                  ref.invalidate(prefsProvider);
                },
                child: Column(
                  children: [
                    for (final t in Tone.values)
                      RadioListTile<Tone>(
                        title: Text(_toneLabel(t)),
                        value: t,
                      ),
                  ],
                ),
              ),
              const Divider(),
              const _SectionHeader('Giao diện'),
              RadioGroup<ThemeMode>(
                groupValue: prefs.themeMode,
                onChanged: (v) async {
                  if (v == null) return;
                  await prefs.setThemeMode(v);
                  ref.invalidate(prefsProvider);
                },
                child: Column(
                  children: [
                    for (final m in ThemeMode.values)
                      RadioListTile<ThemeMode>(
                        title: Text(_themeLabel(m)),
                        value: m,
                      ),
                  ],
                ),
              ),
              const Divider(),
              const _SectionHeader('Phong cách'),
              RadioGroup<AppThemeStyle>(
                groupValue: prefs.themeStyle,
                onChanged: (v) async {
                  if (v == null) return;
                  await prefs.setThemeStyle(v);
                  ref.invalidate(prefsProvider);
                },
                child: Column(
                  children: [
                    for (final s in AppThemeStyle.values)
                      RadioListTile<AppThemeStyle>(
                        title: Text(_styleLabel(s)),
                        secondary: _StylePreviewDot(style: s),
                        value: s,
                      ),
                  ],
                ),
              ),
              const Divider(),
              const _SectionHeader('Máy chủ AI'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('baseUrlField'),
                        controller: _urlCtrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Địa chỉ server',
                          hintText: defaultBaseUrl,
                          helperText:
                              'Mặc định dành cho emulator. Trên máy thật, '
                              'nhập địa chỉ server của bạn.',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const Key('saveBaseUrl'),
                      onPressed: () async {
                        await prefs.setBaseUrl(_urlCtrl.text);
                        ref.invalidate(prefsProvider);
                        _urlLoaded = false; // re-sync (e.g. blank -> default)
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã lưu địa chỉ server')));
                        }
                      },
                      child: const Text('Lưu'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              const _SectionHeader('Dữ liệu'),
              ListTile(
                key: const Key('exportCsv'),
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('Xuất CSV'),
                subtitle: const Text('Lưu giao dịch ra file .csv'),
                onTap: _openExportSheet,
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  void _openExportSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Xuất CSV',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Chọn khoảng thời gian'),
            ),
            for (final (scope, label) in const [
              (ExportScope.thisMonth, 'Tháng này'),
              (ExportScope.last3Months, '3 tháng gần đây'),
              (ExportScope.thisYear, 'Năm nay'),
              (ExportScope.all, 'Tất cả'),
            ])
              ListTile(
                title: Text(label),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _exportCsv(scope);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(ExportScope scope) async {
    final now = DateTime.now();
    final txns = await ref.read(transactionsProvider.future);
    final cats = await ref.read(categoriesProvider.future);
    final wallets = await ref.read(walletsProvider.future);
    final r = exportRange(scope, now);
    final rows = filterByRange(txns, r.start, r.end)
      ..sort((a, b) {
        final c = a.occurredAt.compareTo(b.occurredAt);
        return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
      });
    if (!mounted) return;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có giao dịch để xuất')));
      return;
    }
    final csv = buildTransactionsCsv(
      rows,
      categoryNames: {for (final c in cats) c.id: c.name},
      walletNames: {for (final w in wallets) w.id: w.name},
    );
    try {
      final path = await ref
          .read(csvExporterProvider)
          .save(exportFilename(scope, now), csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Đã lưu: $path'),
        action: SnackBarAction(
          label: 'Sao chép',
          onPressed: () => Clipboard.setData(ClipboardData(text: path)),
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi khi lưu file: $e')));
    }
  }

  String _toneLabel(Tone t) => switch (t) {
        Tone.serious => 'Nghiêm túc',
        Tone.cheer => 'Khen 🎉',
        Tone.scold => 'Mắng yêu 😤',
      };

  String _themeLabel(ThemeMode m) => switch (m) {
        ThemeMode.system => 'Theo hệ thống',
        ThemeMode.light => 'Sáng',
        ThemeMode.dark => 'Tối',
      };

  String _styleLabel(AppThemeStyle s) => switch (s) {
        AppThemeStyle.classic => 'Tinh gọn',
        AppThemeStyle.warm => 'Sổ tay ấm',
      };
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _StylePreviewDot extends StatelessWidget {
  final AppThemeStyle style;
  const _StylePreviewDot({required this.style});

  @override
  Widget build(BuildContext context) {
    final light = buildTheme(style, Brightness.light).colorScheme;
    return SizedBox(
      width: 36,
      height: 20,
      child: Stack(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration:
                BoxDecoration(color: light.primary, shape: BoxShape.circle),
          ),
          Positioned(
            left: 14,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: light.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Theme.of(context).colorScheme.outline, width: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
