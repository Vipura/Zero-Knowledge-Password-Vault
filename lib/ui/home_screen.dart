import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import '../services/crypto_service.dart';
import '../services/database_service.dart';
import '../models/password_entry.dart';
import '../main.dart';
import 'add_password_screen.dart';

class HomeScreen extends StatefulWidget {
  final SessionManager sessionManager;
  const HomeScreen({super.key, required this.sessionManager});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _databaseService = DatabaseService.instance;
  final _cryptoService = CryptoService();
  List<PasswordEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    _entries = await _databaseService.readAllEntries();
    setState(() => _isLoading = false);
  }

  Future<void> _showPassword(PasswordEntry entry) async {
    try {
      final box = SecretBox(
        base64Decode(entry.ciphertext),
        nonce: base64Decode(entry.nonce),
        mac: Mac(base64Decode(entry.mac)),
      );
      final plaintext = await _cryptoService.decryptPassword(box, widget.sessionManager.masterKey!);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(entry.title),
            content: SelectableText(plaintext),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to decrypt password.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock),
            tooltip: 'Lock Vault',
            onPressed: () => widget.sessionManager.lock(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('No passwords stored yet.'))
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.vpn_key)),
                      title: Text(entry.title),
                      subtitle: Text(entry.username),
                      trailing: IconButton(
                        icon: const Icon(Icons.visibility),
                        onPressed: () => _showPassword(entry),
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
          _loadEntries();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
