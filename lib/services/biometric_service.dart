import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Encapsulates all biometric authentication logic using the local_auth package.
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

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

  /// Triggers the OS-level biometric prompt.
  /// Returns true on successful authentication, false otherwise.
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to unlock your Zero-Knowledge Vault',
        options: const AuthenticationOptions(
          biometricOnly: false, // Also allows device PIN as fallback
          stickyAuth: true,     // Keeps the prompt visible if app is suspended briefly
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      // Silently fail — e.code may be: notAvailable, notEnrolled, lockedOut, permanentlyLockedOut
      // The user can still use their master password
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
}
