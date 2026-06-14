import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/widgets/inset_section.dart';
import 'package:moneynote/core/widgets/large_title_header.dart';
import 'package:moneynote/domain/csv_export.dart';
import 'package:moneynote/features/recurring/recurring_screen.dart';
import 'package:moneynote/features/settings/widgets/setting_picker.dart';
import 'package:moneynote/state/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(prefsProvider);
    final cs = Theme.of(context).colorScheme;
    Widget chevron() =>
        Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant);
    Widget icon(IconData i) => Icon(i, size: 22, color: cs.onSurfaceVariant);

    return Scaffold(
      body: Column(
        children: [
          const LargeTitleHeader(title: 'Cài đặt', leading: BackButton()),
          Expanded(
            child: prefsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (prefs) => ListView(
                children: [
                  const SizedBox(height: 8),
                  InsetSection(
                    header: 'Giao diện',
                    children: [
                      InsetRow(
                        leading: icon(Icons.brightness_6),
                        title: 'Chế độ',
                        value: _themeLabel(prefs.themeMode),
                        trailing: chevron(),
                        onTap: () => _pickThemeMode(context, ref, prefs),
                      ),
                      InsetRow(
                        leading: icon(Icons.palette_outlined),
                        title: 'Phong cách',
                        value: _styleLabel(prefs.themeStyle),
                        trailing: chevron(),
                        onTap: () => _pickStyle(context, ref, prefs),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InsetSection(
                    header: 'AI',
                    children: [
                      InsetRow(
                        leading: icon(Icons.record_voice_over),
                        title: 'Giọng điệu',
                        value: _toneLabel(prefs.tone),
                        trailing: chevron(),
                        onTap: () => _pickTone(context, ref, prefs),
                      ),
                      InsetRow(
                        leading: icon(Icons.dns),
                        title: 'Máy chủ',
                        value: prefs.baseUrl,
                        trailing: chevron(),
                        onTap: () => _openServerUrlSheet(context, ref, prefs),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InsetSection(
                    header: 'Dữ liệu',
                    children: [
                      InsetRow(
                        key: const Key('exportCsv'),
                        leading: icon(Icons.file_download_outlined),
                        title: 'Xuất CSV',
                        value: 'Lưu ra .csv',
                        trailing: chevron(),
                        onTap: () => _openExportSheet(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InsetSection(
                    header: 'Tự động',
                    children: [
                      InsetRow(
                        key: const Key('recurringRules'),
                        leading: icon(Icons.repeat),
                        title: 'Giao dịch định kỳ',
                        value: 'Tự tạo khi tới hạn',
                        trailing: chevron(),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const RecurringScreen())),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const InsetSection(
                    header: 'Giới thiệu',
                    footer:
                        'Ghi chi tiêu trong 3 giây, bằng tiếng Việt, offline.',
                    children: [InsetRow(title: 'MoneyNote')],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _pickTone(
    BuildContext context, WidgetRef ref, AppPrefs prefs) async {
  final picked = await showSettingPicker<Tone>(
    context,
    title: 'Giọng điệu AI',
    options: [for (final t in Tone.values) (_toneLabel(t), t)],
    current: prefs.tone,
  );
  if (picked != null) {
    await prefs.setTone(picked);
    ref.invalidate(prefsProvider);
  }
}

Future<void> _pickThemeMode(
    BuildContext context, WidgetRef ref, AppPrefs prefs) async {
  final picked = await showSettingPicker<ThemeMode>(
    context,
    title: 'Giao diện',
    options: [for (final m in ThemeMode.values) (_themeLabel(m), m)],
    current: prefs.themeMode,
  );
  if (picked != null) {
    await prefs.setThemeMode(picked);
    ref.invalidate(prefsProvider);
  }
}

Future<void> _pickStyle(
    BuildContext context, WidgetRef ref, AppPrefs prefs) async {
  final picked = await showSettingPicker<AppThemeStyle>(
    context,
    title: 'Phong cách',
    options: [for (final s in AppThemeStyle.values) (_styleLabel(s), s)],
    current: prefs.themeStyle,
  );
  if (picked != null) {
    await prefs.setThemeStyle(picked);
    ref.invalidate(prefsProvider);
  }
}

void _openServerUrlSheet(BuildContext context, WidgetRef ref, AppPrefs prefs) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // keyboard inset padding
    builder: (sheetCtx) => _ServerUrlSheet(
      initialUrl: prefs.baseUrl,
      onSave: (url) async {
        await prefs.setBaseUrl(url);
        ref.invalidate(prefsProvider);
        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã lưu địa chỉ server')));
        }
      },
    ),
  );
}

void _openExportSheet(BuildContext context, WidgetRef ref) {
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
                _exportCsv(context, ref, scope);
              },
            ),
        ],
      ),
    ),
  );
}

Future<void> _exportCsv(
    BuildContext context, WidgetRef ref, ExportScope scope) async {
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
  if (!context.mounted) return;
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
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Đã lưu: $path'),
      action: SnackBarAction(
        label: 'Sao chép',
        onPressed: () => Clipboard.setData(ClipboardData(text: path)),
      ),
    ));
  } catch (e) {
    if (!context.mounted) return;
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

class _ServerUrlSheet extends StatefulWidget {
  const _ServerUrlSheet({required this.initialUrl, required this.onSave});
  final String initialUrl;
  final ValueChanged<String> onSave;

  @override
  State<_ServerUrlSheet> createState() => _ServerUrlSheetState();
}

class _ServerUrlSheetState extends State<_ServerUrlSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialUrl);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Máy chủ AI',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              key: const Key('baseUrlField'),
              controller: _ctrl,
              keyboardType: TextInputType.url,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ server',
                hintText: defaultBaseUrl,
                helperText: 'Mặc định dành cho emulator. Trên máy thật, '
                    'nhập địa chỉ server của bạn.',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('saveBaseUrl'),
              onPressed: () => widget.onSave(_ctrl.text),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
