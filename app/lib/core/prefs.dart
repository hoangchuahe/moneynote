import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

enum Tone { serious, cheer, scold }

const defaultBaseUrl = 'http://10.0.2.2:8080'; // Android emulator -> host

class AppPrefs {
  final SharedPreferences _p;
  AppPrefs._(this._p);

  static const _kTone = 'tone';
  static const _kToken = 'device_token';
  static const _kBaseUrl = 'ai_base_url';
  static const _kThemeMode = 'theme_mode';

  static Future<AppPrefs> load() async {
    final p = await SharedPreferences.getInstance();
    if (!p.containsKey(_kToken)) {
      await p.setString(_kToken, const Uuid().v4());
    }
    return AppPrefs._(p);
  }

  Tone get tone => Tone.values.firstWhere(
        (t) => t.name == _p.getString(_kTone),
        orElse: () => Tone.serious,
      );
  Future<void> setTone(Tone t) => _p.setString(_kTone, t.name);

  String get deviceToken => _p.getString(_kToken)!;

  String get baseUrl => _p.getString(_kBaseUrl) ?? defaultBaseUrl;

  /// Persists the AI server URL; blank input restores the default.
  Future<void> setBaseUrl(String url) {
    final v = url.trim();
    return v.isEmpty ? _p.remove(_kBaseUrl) : _p.setString(_kBaseUrl, v);
  }

  ThemeMode get themeMode => ThemeMode.values.firstWhere(
        (m) => m.name == _p.getString(_kThemeMode),
        orElse: () => ThemeMode.system,
      );
  Future<void> setThemeMode(ThemeMode m) => _p.setString(_kThemeMode, m.name);
}
