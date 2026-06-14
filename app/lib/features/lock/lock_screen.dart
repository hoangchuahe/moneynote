import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/state/providers.dart';

/// Full-screen lock. Auto-prompts the OS auth on show; calls [onUnlocked] on
/// success. Stays put on failure/cancel with a retry button. Pure gate UI.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _auth());
  }

  Future<void> _auth() async {
    if (_busy) return;
    _busy = true;
    final ok = await ref.read(appLockServiceProvider).authenticate();
    _busy = false;
    if (ok && mounted) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: cs.primary),
            const SizedBox(height: 16),
            const Text('MoneyNote',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Đã khoá', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('unlockBtn'),
              onPressed: _auth,
              icon: const Icon(Icons.lock_open),
              label: const Text('Mở khoá'),
            ),
          ],
        ),
      ),
    );
  }
}
