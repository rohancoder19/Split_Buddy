import 'dart:convert';

class E2eeHelper {
  /// Encrypts plaintext using a simple symmetric XOR cipher with the given key,
  /// and returns a Base64-encoded ciphertext string.
  static String encrypt(String plaintext, String key) {
    if (key.isEmpty) return plaintext;
    final textBytes = utf8.encode(plaintext);
    final keyBytes = utf8.encode(key);
    final encryptedBytes = List<int>.generate(textBytes.length, (i) {
      return textBytes[i] ^ keyBytes[i % keyBytes.length];
    });
    return base64.encode(encryptedBytes);
  }

  /// Decrypts a Base64-encoded ciphertext string using a simple symmetric XOR cipher
  /// with the given key, returning the original plaintext.
  static String decrypt(String ciphertext, String key) {
    if (key.isEmpty) return ciphertext;
    try {
      final encryptedBytes = base64.decode(ciphertext);
      final keyBytes = utf8.encode(key);
      final decryptedBytes = List<int>.generate(encryptedBytes.length, (i) {
        return encryptedBytes[i] ^ keyBytes[i % keyBytes.length];
      });
      return utf8.decode(decryptedBytes);
    } catch (e) {
      return "[Decryption Error: $e]";
    }
  }

  /// Generates a mock E2EE security session fingerprint hash for the group channel.
  static String getSessionFingerprint(String inviteCode) {
    final bytes = utf8.encode("${inviteCode}_e2ee_salt_2026");
    int hash = 0;
    for (var byte in bytes) {
      hash = (hash * 31 + byte) & 0xFFFFFFFF;
    }
    final hex = hash.toRadixString(16).padLeft(8, '0').toUpperCase();
    return "E2EE-FP-${hex.substring(0, 4)}-${hex.substring(4, 8)}";
  }

  /// Generates a mock user-device public fingerprint hash to display in the verification panel.
  static String getUserFingerprint(String userId, String userName) {
    final bytes = utf8.encode("$userId:$userName");
    int hash = 0;
    for (var byte in bytes) {
      hash = (hash * 17 + byte) & 0xFFFFFFFF;
    }
    final hex = hash.toRadixString(16).padLeft(8, '0').toUpperCase();
    return "DEV-FP-${hex.substring(0, 4)}-${hex.substring(4, 8)}";
  }
}
