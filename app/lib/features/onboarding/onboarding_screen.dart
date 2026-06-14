import 'package:flutter/material.dart';

/// First-run intro: a 3-page swipeable walkthrough of the app's value props.
/// Presentational — calls [onDone] when the user finishes ("Bắt đầu") or skips
/// ("Bỏ qua"); the caller persists the seen flag. No Riverpod.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  // (icon, headline, body) — copy is intentionally tied to the README pitch.
  static const _pages = <(IconData, String, String)>[
    (
      Icons.bolt,
      'Ghi chi tiêu trong 3 giây',
      'Offline, tiếng Việt. Không cần internet, không link ngân hàng.',
    ),
    (
      Icons.auto_awesome,
      'Nhập bằng lời',
      'Gõ "trưa nay ăn phở 50k" — AI điền số tiền, danh mục, ngày. Bạn chỉ xác nhận.',
    ),
    (
      Icons.lock_outline,
      'Riêng tư tuyệt đối',
      'Dữ liệu nằm trên máy bạn. Không tài khoản, không quảng cáo, không theo dõi.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= _pages.length - 1) {
      widget.onDone();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('onboardSkip'),
                onPressed: widget.onDone,
                child: const Text('Bỏ qua'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) {
                  final (icon, title, body) = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 72, color: cs.primary),
                        const SizedBox(height: 24),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 15, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? cs.primary : cs.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('onboardNext'),
                  onPressed: _next,
                  child: Text(isLast ? 'Bắt đầu' : 'Tiếp'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
