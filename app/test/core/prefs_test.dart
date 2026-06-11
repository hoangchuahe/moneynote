import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneynote/core/prefs.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('tone defaults to serious and persists', () async {
    final prefs = await AppPrefs.load();
    expect(prefs.tone, Tone.serious);
    await prefs.setTone(Tone.scold);
    final again = await AppPrefs.load();
    expect(again.tone, Tone.scold);
  });

  test('device token is generated once and stable', () async {
    final prefs = await AppPrefs.load();
    final t1 = prefs.deviceToken;
    expect(t1, isNotEmpty);
    final again = await AppPrefs.load();
    expect(again.deviceToken, t1);
  });

  test('base url defaults to emulator host', () async {
    final prefs = await AppPrefs.load();
    expect(prefs.baseUrl, 'http://10.0.2.2:8080');
  });
}
