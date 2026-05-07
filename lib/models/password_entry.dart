class PasswordEntry {
  final int? id;
  final String title;
  final String username;
  final String ciphertext; // Base64 encoded
  final String nonce; // Base64 encoded IV
  final String mac; // Base64 encoded MAC
  
  PasswordEntry({
    this.id,
    required this.title,
    required this.username,
    required this.ciphertext,
    required this.nonce,
    required this.mac,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'username': username,
      'ciphertext': ciphertext,
      'nonce': nonce,
      'mac': mac,
    };
  }

  factory PasswordEntry.fromMap(Map<String, dynamic> map) {
    return PasswordEntry(
      id: map['id'] as int?,
      title: map['title'] as String,
      username: map['username'] as String,
      ciphertext: map['ciphertext'] as String,
      nonce: map['nonce'] as String,
      mac: map['mac'] as String,
    );
  }
}
