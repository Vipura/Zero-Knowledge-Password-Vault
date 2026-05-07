import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import '../services/crypto_service.dart';
import '../services/database_service.dart';
import '../services/password_analyzer.dart';
import '../services/password_generator.dart';
import '../models/password_entry.dart';
import '../main.dart';
import 'add_password_screen.dart';

class DecryptedEntry {
  final PasswordEntry entry;
  final String plaintext;
  final bool isWeak;
  DecryptedEntry(this.entry, this.plaintext, this.isWeak);
}

class HomeScreen extends StatefulWidget {
  final SessionManager sessionManager;
  const HomeScreen({super.key, required this.sessionManager});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _databaseService = DatabaseService.instance;
  final _cryptoService = CryptoService();
  List<DecryptedEntry> _decryptedEntries = [];
  bool _isLoading = true;
  bool _showWeakOnly = false;

  final TextEditingController _genLengthController = TextEditingController(text: "16");
  String _generatedPassword = "";

  @override
  void initState() {
    super.initState();
    _loadAndDecryptEntries();
  }

  Future<void> _loadAndDecryptEntries() async {
    setState(() => _isLoading = true);
    final rawEntries = await _databaseService.readAllEntries();
    List<DecryptedEntry> decoded = [];
    
    for (var entry in rawEntries) {
      try {
        final box = SecretBox(
          base64Decode(entry.ciphertext),
          nonce: base64Decode(entry.nonce),
          mac: Mac(base64Decode(entry.mac)),
        );
        final plaintext = await _cryptoService.decryptPassword(box, widget.sessionManager.masterKey!);
        final isWeak = PasswordAnalyzer.isWeak(plaintext);
        decoded.add(DecryptedEntry(entry, plaintext, isWeak));
      } catch (_) {
        // Skip decryption failures silently for UI rendering scope
      }
    }
    
    setState(() {
      _decryptedEntries = decoded;
      _isLoading = false;
    });
  }

  void _generateInfinitePassword() {
    int length = int.tryParse(_genLengthController.text) ?? 16;
    setState(() {
      _generatedPassword = PasswordGenerator.generate(length: length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final weakCount = _decryptedEntries.where((e) => e.isWeak).length;
    final displayList = _showWeakOnly 
      ? _decryptedEntries.where((e) => e.isWeak).toList() 
      : _decryptedEntries;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vault'),
            Text('Total Apps/Titles: ${_decryptedEntries.length}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              icon: const Icon(Icons.warning_amber, color: Colors.orange),
              label: Text('Weak: $weakCount', style: const TextStyle(color: Colors.orange)),
              onPressed: () {
                setState(() => _showWeakOnly = !_showWeakOnly);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.lock),
            tooltip: 'Lock Vault',
            onPressed: () => widget.sessionManager.lock(),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Password Generator', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: _genLengthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Character Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _generateInfinitePassword,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                  child: const Text('Generate Password'),
                ),
                const SizedBox(height: 30),
                if (_generatedPassword.isNotEmpty) ...[
                  const Text('Generated:', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  SelectableText(
                    _generatedPassword, 
                    style: const TextStyle(fontSize: 18, fontFamily: 'monospace', color: Colors.greenAccent)
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : displayList.isEmpty
              ? Center(child: Text(_showWeakOnly ? 'No weak passwords found!' : 'No passwords stored yet.'))
              : ListView.builder(
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final item = displayList[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: item.isWeak ? Colors.orange.withOpacity(0.3) : null,
                        child: Icon(Icons.vpn_key, color: item.isWeak ? Colors.orange : Colors.white),
                      ),
                      title: Text(item.entry.title),
                      subtitle: Text(item.entry.username),
                      trailing: IconButton(
                        icon: const Icon(Icons.visibility),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(item.entry.title),
                              content: SelectableText(item.plaintext),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddPasswordScreen(sessionManager: widget.sessionManager),
            ),
          );
          _loadAndDecryptEntries();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
