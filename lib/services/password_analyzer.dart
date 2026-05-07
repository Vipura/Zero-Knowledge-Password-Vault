class PasswordAnalyzer {
  /// Evaluates password strength and returns true if the password is weak.
  /// A password is considered weak if it is shorter than 8 characters,
  /// or lacks a mix of uppercase, lowercase, numbers, and symbols.
  static bool isWeak(String password) {
    if (password.length < 8) return true;
    if (!password.contains(RegExp(r'[A-Z]'))) return true;
    if (!password.contains(RegExp(r'[a-z]'))) return true;
    if (!password.contains(RegExp(r'[0-9]'))) return true;
    if (!password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>\-_+=\[\]]'))) return true;
    return false;
  }
}
