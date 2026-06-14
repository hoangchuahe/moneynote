import 'package:flutter/services.dart' show PlatformException;
import 'package:local_auth/local_auth.dart';

/// Thin, mockable wrapper over local_auth — the only seam touching the plugin.
class AppLockService {
  final LocalAuthentication _auth;
  AppLockService([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  /// True if the device has any usable credential (biometric OR device PIN/pattern).
  Future<bool> isSupported() => _auth.isDeviceSupported();

  /// Prompts the OS auth sheet; true on success. biometricOnly:false so a device
  /// PIN/pattern also satisfies it; stickyAuth survives the prompt's backgrounding.
  /// Any PlatformException (sensor error / no credential / cancel) → false (fail-closed).
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Mở khoá MoneyNote',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
