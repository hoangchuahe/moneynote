import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/home/home_shell.dart';
import 'package:moneynote/features/lock/lock_gate.dart';
import 'package:moneynote/features/onboarding/onboarding_gate.dart';
import 'package:moneynote/state/providers.dart';

final _seedProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(databaseProvider);
  await seedIfEmpty(db);
  // Best-effort: auto-create due recurring transactions. Never block launch.
  try {
    await AppRepository(db).materializeDueRecurrings(DateTime.now());
  } catch (_) {
    // Recurring is best-effort; a failure here must not stop the app starting.
  }
});

void main() {
  runApp(const ProviderScope(child: MoneyNoteApp()));
}

class MoneyNoteApp extends ConsumerWidget {
  const MoneyNoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider).valueOrNull;
    final themeMode = prefs?.themeMode ?? ThemeMode.system;
    final style = prefs?.themeStyle ?? AppThemeStyle.classic;
    return MaterialApp(
      title: 'MoneyNote',
      theme: buildTheme(style, Brightness.light),
      darkTheme: buildTheme(style, Brightness.dark),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      // App tiếng Việt: date picker, dialog, tooltips… đều theo locale vi.
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
      data: (_) => const OnboardingGate(child: LockGate(child: HomeShell())),
    );
  }
}
