import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/features/onboarding/onboarding_screen.dart';
import 'package:moneynote/state/providers.dart';

/// First-run gate: shows [OnboardingScreen] until `onboardingSeen` is set, then
/// the [child]. Wraps the lock gate in `_Root` — onboarding runs once ever,
/// while the lock runs every launch. Like `LockGate`, it withholds the child
/// until prefs resolve, so there is no wrong-screen flash.
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(prefsProvider);
    if (!prefsAsync.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (prefsAsync.requireValue.onboardingSeen) return child;
    return OnboardingScreen(onDone: () => _finishOnboarding(ref));
  }
}

Future<void> _finishOnboarding(WidgetRef ref) async {
  await ref.read(prefsProvider).requireValue.setOnboardingSeen(true);
  ref.invalidate(prefsProvider); // rebuild → falls through to `child`
}
