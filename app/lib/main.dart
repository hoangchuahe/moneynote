import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/home/home_shell.dart';
import 'package:moneynote/state/providers.dart';

final _seedProvider = FutureProvider<void>((ref) async {
  await seedIfEmpty(ref.watch(databaseProvider));
});

void main() {
  runApp(const ProviderScope(child: MoneyNoteApp()));
}

class MoneyNoteApp extends StatelessWidget {
  const MoneyNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoneyNote',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const _Root(),
    );
  }
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = ref.watch(_seedProvider);
    return seed.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Lỗi khởi tạo: $e'))),
      data: (_) => const HomeShell(),
    );
  }
}
