import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    // Security Note: 100,000 iterations is the minimum recommended for PBKDF2
    // to slow down brute force and dictionary attacks against the Master Password.
    iterations: 100000,
    // Security Note: 256 bits (32 bytes) generates an AES-256 compatible key length.
    bits: 256,
  );

  final AesGcm _aesGcm = AesGcm.with256bits();

  /// Derives a 256-bit SecretKey from the given master password and salt.
  Future<SecretKey> deriveKey(String masterPassword, List<int> salt) async {
    final secretKey = SecretKey(utf8.encode(masterPassword));
    final derivedKey = await _pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: salt,
    );
    return derivedKey;
  }

  /// Encrypts plaintext string returning [SecretBox] containing ciphertext, mac, and nonce.
  Future<SecretBox> encryptPassword(String plaintext, SecretKey masterKey) async {
    // Security Note: AES-GCM requires a unique Nonce (IV) per encryption to ensure 
    // confidentiality. Using Random.secure() provides cryptographic randomness.
    final nonce = List<int>.generate(12, (_) => Random.secure().nextInt(256));
    
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: masterKey,
      nonce: nonce,
    );
    return secretBox;
  }

  /// Decrypts a [SecretBox] using the provided master key.
  Future<String> decryptPassword(SecretBox box, SecretKey masterKey) async {
    final cleartextBytes = await _aesGcm.decrypt(
      box,
      secretKey: masterKey,
    );
    return utf8.decode(cleartextBytes);
  }

  /// Generates a random cryptographic salt.
  List<int> generateSalt([int length = 16]) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
