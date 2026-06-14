import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/features/lock/lock_screen.dart';
import 'package:moneynote/state/providers.dart';

/// Wraps [child] and shows a [LockScreen] while the session is locked, when
/// app lock is enabled. Owns the session-lock flag (distinct from the persisted
/// appLockEnabled): locks on cold launch and whenever the app is backgrounded.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final enabled =
        ref.read(prefsProvider).valueOrNull?.appLockEnabled ?? false;
    if (enabled && state == AppLifecycleState.paused) {
      setState(() => _locked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(prefsProvider);
    // Until prefs resolves, don't reveal the child (avoid a pre-lock flash).
    if (!prefsAsync.hasValue) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final enabled = prefsAsync.requireValue.appLockEnabled;
    if (!_initialized) {
      _initialized = true;
      _locked = enabled; // cold launch: locked iff enabled
    }
    if (enabled && _locked) {
      return LockScreen(onUnlocked: () => setState(() => _locked = false));
    }
    return widget.child;
  }
}
