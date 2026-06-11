import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

enum Tone { serious, cheer, scold }

class AppPrefs {
  final SharedPreferences _p;
  AppPrefs._(this._p);

  static const _kTone = 'tone';
  static const _kToken = 'device_token';
  static const _kBaseUrl = 'ai_base_url';

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
  String get baseUrl => _p.getString(_kBaseUrl) ?? 'http://10.0.2.2:8080';
}
