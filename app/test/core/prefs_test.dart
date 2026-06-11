import 'package:flutter/material.dart';
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

  test('base url can be changed and persists (real-device setup)', () async {
    final prefs = await AppPrefs.load();
    await prefs.setBaseUrl('https://moneynote.example.com');
    final again = await AppPrefs.load();
    expect(again.baseUrl, 'https://moneynote.example.com');
  });

  test('setBaseUrl trims and falls back to default when blank', () async {
    final prefs = await AppPrefs.load();
    await prefs.setBaseUrl('   ');
    expect((await AppPrefs.load()).baseUrl, 'http://10.0.2.2:8080');
  });

  test('theme mode defaults to system and persists', () async {
    final prefs = await AppPrefs.load();
    expect(prefs.themeMode, ThemeMode.system);
    await prefs.setThemeMode(ThemeMode.dark);
    final again = await AppPrefs.load();
    expect(again.themeMode, ThemeMode.dark);
  });

  test('theme style defaults to classic and persists', () async {
    final prefs = await AppPrefs.load();
    expect(prefs.themeStyle, AppThemeStyle.classic);
    await prefs.setThemeStyle(AppThemeStyle.warm);
    expect((await AppPrefs.load()).themeStyle, AppThemeStyle.warm);
  });
}
