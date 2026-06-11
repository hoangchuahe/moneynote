import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/state/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(prefsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (prefs) => ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Giọng điệu AI'),
            ),
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
          ],
        ),
      ),
    );
  }

  String _toneLabel(Tone t) => switch (t) {
        Tone.serious => 'Nghiêm túc',
        Tone.cheer => 'Khen 🎉',
        Tone.scold => 'Mắng yêu 😤',
      };
}
