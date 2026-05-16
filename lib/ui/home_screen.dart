import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cryptography/cryptography.dart';
import '../services/crypto_service.dart';
import '../services/database_service.dart';
import '../services/password_analyzer.dart';
import '../models/password_entry.dart';
import '../utils/app_icons.dart';
import '../utils/app_theme.dart';
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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _databaseService = DatabaseService.instance;
  final _cryptoService = CryptoService();
  List<DecryptedEntry> _decryptedEntries = [];
  bool _isLoading = true;
  int _selectedSidebarIndex = 0;
  String _searchQuery = '';
  final Set<int> _revealedPasswords = {};

  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadAndDecryptEntries();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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
        final plaintext = await _cryptoService.decryptPassword(
            box, widget.sessionManager.masterKey!);
        final isWeak = PasswordAnalyzer.isWeak(plaintext);
        decoded.add(DecryptedEntry(entry, plaintext, isWeak));
      } catch (_) {
        // Skip decryption failures silently
      }
    }

    setState(() {
      _decryptedEntries = decoded;
      _isLoading = false;
    });
    _fadeController.forward(from: 0);
  }

  List<DecryptedEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return _decryptedEntries;
    return _decryptedEntries.where((e) {
      final q = _searchQuery.toLowerCase();
      return e.entry.title.toLowerCase().contains(q) ||
          e.entry.username.toLowerCase().contains(q);
    }).toList();
  }

  int get _securityScore {
    if (_decryptedEntries.isEmpty) return 100;
    final strong = _decryptedEntries.where((e) => !e.isWeak).length;
    setState(() {
      _generatedPassword = PasswordGenerator.generate(length: length);
    });
  }

  void _showItemDetails(DecryptedEntry item) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(AppIconMapper.getIconFor(item.entry.title), size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(item.entry.title, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Username:', style: TextStyle(color: Colors.grey, fontSize: 12)),
              SelectableText(item.entry.username, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              const Text('Password:', style: TextStyle(color: Colors.grey, fontSize: 12)),
              SelectableText(item.plaintext, style: const TextStyle(fontSize: 16)),
              if (item.isWeak) ...[
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                    SizedBox(width: 6),
                    Text('Weak Password', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _editEntry(item);
              },
              child: const Text('Edit'),
            ),
            TextButton(
              onPressed: () async {
                await _databaseService.delete(item.entry.id!);
                if (mounted) Navigator.pop(context);
                _loadAndDecryptEntries();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack).value,
          child: child,
        );
      },
    );
  }

  void _editEntry(DecryptedEntry item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPasswordScreen(
          sessionManager: widget.sessionManager,
          entryToEdit: item.entry,
          initialPlaintext: item.plaintext,
        ),
      ),
    );
    if (result == true) {
      _loadAndDecryptEntries();
    }
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
            const Text('Password Vault'),
            Text('Total Apps: ${_decryptedEntries.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                    labelText: 'Length',
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
                        backgroundColor: item.isWeak ? Colors.orange.withOpacity(0.3) : Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(AppIconMapper.getIconFor(item.entry.title), color: item.isWeak ? Colors.orange : Colors.white),
                      ),
                      title: Text(item.entry.title),
                      subtitle: Text(item.entry.username),
                      onTap: () => _showItemDetails(item),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddPasswordScreen(sessionManager: widget.sessionManager),
            ),
          );
          if (result == true) {
            _loadAndDecryptEntries();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
