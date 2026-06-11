import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/prefs.dart';
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
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
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
