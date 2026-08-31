import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Stores app-lock credentials securely and delegates biometric checks to the
/// operating system. No PIN is persisted in plaintext.
class SecurityService {
  SecurityService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  static const _appLockKey = 'security.app_lock_enabled';
  static const _pinHashKey = 'security.pin_hash';
  static const _pinSaltKey = 'security.pin_salt';
  static const _pinLengthKey = 'security.pin_length';
  static const _configuredUserKey = 'security.configured_user';
  static const _biometricKey = 'security.biometric_enabled';
  static const _autoLockMinutesKey = 'security.auto_lock_minutes';

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  Future<bool> isAppLockEnabled() async =>
      (await _storage.read(key: _appLockKey)) == 'true';

  Future<void> setAppLockEnabled(bool enabled) async {
    await _storage.write(key: _appLockKey, value: enabled.toString());
  }

  Future<bool> hasPin() async =>
      (await _storage.read(key: _pinHashKey)) != null;

  Future<bool> hasPinForUser(String userId) async =>
      await hasPin() &&
      (await _storage.read(key: _configuredUserKey)) == userId;

  Future<void> setConfiguredUser(String userId) async =>
      _storage.write(key: _configuredUserKey, value: userId);

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('PIN must contain exactly 4 digits.');
    }

    final salt = _randomSalt();
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: _hashPin(pin, salt));
    await _storage.write(key: _pinLengthKey, value: pin.length.toString());
    await setAppLockEnabled(true);
  }

  Future<int> getPinLength() async =>
      int.tryParse(await _storage.read(key: _pinLengthKey) ?? '') ?? 4;

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _pinSaltKey);
    final expected = await _storage.read(key: _pinHashKey);
    if (salt == null || expected == null) return false;

    return _constantTimeEquals(expected, _hashPin(pin, salt));
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _pinLengthKey);
    await _storage.delete(key: _configuredUserKey);
    await setAppLockEnabled(false);
  }

  Future<void> clearSettings() async {
    await _storage.delete(key: _appLockKey);
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _pinLengthKey);
    await _storage.delete(key: _configuredUserKey);
    await _storage.delete(key: _biometricKey);
    await _storage.delete(key: _autoLockMinutesKey);
  }

  Future<int> getAutoLockMinutes() async =>
      int.tryParse(await _storage.read(key: _autoLockMinutesKey) ?? '') ?? 5;

  Future<void> setAutoLockMinutes(int minutes) async {
    if (![0, 1, 5, 15, -1].contains(minutes)) {
      throw ArgumentError('Unsupported auto-lock duration.');
    }
    await _storage.write(key: _autoLockMinutesKey, value: minutes.toString());
  }

  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.isDeviceSupported() &&
          (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } on LocalAuthException {
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async =>
      (await _storage.read(key: _biometricKey)) == 'true';

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricKey, value: enabled.toString());
  }

  Future<bool> authenticateBiometric() async {
    if (!await isBiometricAvailable()) return false;

    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock LifeTrack to view your private data.',
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    }
  }

  String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return difference == 0;
  }
}
