import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/crypto_service.dart';
import '../services/database_service.dart';
import '../services/password_generator.dart';
import '../services/password_analyzer.dart';
import '../models/password_entry.dart';
import '../utils/app_icons.dart';
import '../main.dart';

class AddPasswordScreen extends StatefulWidget {
  final SessionManager sessionManager;
  final PasswordEntry? entryToEdit;
  final String? initialPlaintext;
  
  const AddPasswordScreen({super.key, required this.sessionManager, this.entryToEdit, this.initialPlaintext});

  @override
  State<AddPasswordScreen> createState() => _AddPasswordScreenState();
}

class _AddPasswordScreenState extends State<AddPasswordScreen> {
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cryptoService = CryptoService();
  final _databaseService = DatabaseService.instance;
  bool _isPasswordVisible = false;
  String _currentTitle = "";

  @override
  void initState() {
    super.initState();
    if (widget.entryToEdit != null) {
      _titleController.text = widget.entryToEdit!.title;
      _usernameController.text = widget.entryToEdit!.username;
      _currentTitle = widget.entryToEdit!.title;
    }
    if (widget.initialPlaintext != null) {
      _passwordController.text = widget.initialPlaintext!;
    }
  }

  void _generatePassword() {
    final newPassword = PasswordGenerator.generate();
    setState(() {
      _passwordController.text = newPassword;
      _isPasswordVisible = true;
    });
  }

  void _save() async {
    if (_titleController.text.isEmpty || _passwordController.text.isEmpty) return;

    if (PasswordAnalyzer.isWeak(_passwordController.text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warning: This password is weak! Consider Generating a stronger one.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          )
        );
      }
    }

    final secretBox = await _cryptoService.encryptPassword(
      _passwordController.text,
      widget.sessionManager.masterKey!,
    );

    final entry = PasswordEntry(
      id: widget.entryToEdit?.id,
      title: _titleController.text,
      username: _usernameController.text,
      ciphertext: base64Encode(secretBox.cipherText),
      nonce: base64Encode(secretBox.nonce),
      mac: base64Encode(secretBox.mac.bytes),
    );

    if (widget.entryToEdit == null) {
      await _databaseService.create(entry);
    } else {
      await _databaseService.update(entry);
    }
    
    if (mounted) {
      Navigator.pop(context, true); // True implies successful save/edit
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.entryToEdit == null ? 'Add Password' : 'Edit Vault Entry')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(AppIconMapper.getIconFor(_currentTitle), size: 40),
            ),
            const SizedBox(height: 24),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                return AppIconMapper.popularApps.where((String option) {
                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                _titleController.text = selection;
                setState(() => _currentTitle = selection);
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                // Ensure manual typing updates icon
                if (controller.text != _titleController.text) {
                   controller.text = _titleController.text;
                }
                controller.addListener(() {
                  _titleController.text = controller.text;
                  setState(() => _currentTitle = controller.text);
                });
                
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: 'Title / Website App', border: OutlineInputBorder()),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.autorenew, size: 28),
                  onPressed: _generatePassword,
                  tooltip: 'Generate Secure Password',
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(widget.entryToEdit == null ? 'Save Encrypted Entry' : 'Update Encrypted Entry'),
            ),
          ],
        ),
      ),
    );
  }
}
