import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encapsulates all biometric authentication logic using the local_auth package.
/// Also handles secure key storage so biometric unlock can re-derive the session key
/// without re-entering the master password.
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  // flutter_secure_storage: Android uses EncryptedSharedPreferences by default,
  // iOS uses the Keychain. Both are hardware-backed on supported devices.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyAlias = 'zk_vault_master_key_bytes';

  // ── Availability ──────────────────────────────────────────────────────────

  /// Returns true if the device has biometric hardware and enrolled credentials.
  Future<bool> isBiometricAvailable() async {
    try {
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!isDeviceSupported) return false;

      final canCheckBiometrics = await _auth.canCheckBiometrics;
      if (!canCheckBiometrics) return false;

      final availableBiometrics = await _auth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Returns the types of biometrics available on this device.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  // ── Authentication ─────────────────────────────────────────────────────────

  /// Triggers the OS-level biometric prompt.
  /// Returns true on successful authentication, false otherwise.
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to unlock your Zero-Knowledge Vault',
        options: const AuthenticationOptions(
          biometricOnly: false, // Allows device PIN as fallback
          stickyAuth: true, // Keeps prompt visible if app is briefly backgrounded
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  // ── Key Storage ───────────────────────────────────────────────────────────

  /// After a successful master-password unlock, call this to persist the derived
  /// key bytes in the secure store so a later biometric auth can restore the session.
  ///
  /// The key bytes are stored in the OS keychain / encrypted prefs — they are
  /// never written to plain storage. Biometric must succeed before the bytes can
  /// be read back via [loadKeyWithBiometric].
  Future<void> saveKeyForBiometric(List<int> keyBytes) async {
    final encoded = base64Encode(keyBytes);
    await _storage.write(key: _keyAlias, value: encoded);
  }

  /// Prompts biometric authentication and, on success, returns the previously
  /// saved key bytes. Returns null if auth fails or no key has been saved yet.
  Future<List<int>?> loadKeyWithBiometric() async {
    // Step 1 — Biometric gate
    final authenticated = await authenticateWithBiometrics();
    if (!authenticated) return null;

    // Step 2 — Retrieve from secure storage
    final encoded = await _storage.read(key: _keyAlias);
    if (encoded == null) return null;

    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  /// Returns true if a saved key exists (i.e. biometric unlock has been set up).
  Future<bool> hasSavedKey() async {
    final val = await _storage.read(key: _keyAlias);
    return val != null && val.isNotEmpty;
  }

  /// Removes the stored key bytes (e.g. when user disables biometric unlock).
  Future<void> clearSavedKey() async {
    await _storage.delete(key: _keyAlias);
  }
}
