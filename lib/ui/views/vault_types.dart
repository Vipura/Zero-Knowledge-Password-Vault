import '../../models/password_entry.dart';

/// Shared decrypted entry data model used across all home sub-views.
class DecryptedEntryData {
  final PasswordEntry entry;
  final String plaintext;
  final bool isWeak;
  const DecryptedEntryData(this.entry, this.plaintext, this.isWeak);
}
