import 'dart:math';

class PasswordGenerator {
  /// Generates a highly secure password based on user constraints.
  /// 
  /// Security Note: dart:math's Random.secure() is used instead of standard Random()
  /// to ensure cryptographically secure pseudo-randomness, making password prediction impossible.
  static String generate({
    int length = 16,
    bool uppercase = true,
    bool lowercase = true,
    bool numbers = true,
    bool symbols = true,
  }) {
    const upperChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowerChars = 'abcdefghijklmnopqrstuvwxyz';
    const numberChars = '0123456789';
    const symbolChars = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

    String allowedChars = '';
    if (uppercase) allowedChars += upperChars;
    if (lowercase) allowedChars += lowerChars;
    if (numbers) allowedChars += numberChars;
    if (symbols) allowedChars += symbolChars;

    if (allowedChars.isEmpty) {
      allowedChars = lowerChars;
    }

    final random = Random.secure();
    final chars = List<String>.generate(length, (index) {
      return allowedChars[random.nextInt(allowedChars.length)];
    });

    return chars.join();
  }
}
