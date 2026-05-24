import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/crypto_service.dart';
import '../services/database_service.dart';
import '../services/password_generator.dart';
import '../services/password_analyzer.dart';
import '../models/password_entry.dart';
import '../utils/app_icons.dart';
import '../utils/app_theme.dart';
import '../main.dart';

class AddPasswordScreen extends StatefulWidget {
  final SessionManager sessionManager;
  final PasswordEntry? entryToEdit;
  final String? initialPlaintext;

  const AddPasswordScreen(
      {super.key,
      required this.sessionManager,
      this.entryToEdit,
      this.initialPlaintext});

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
    if (_titleController.text.isEmpty || _passwordController.text.isEmpty) {
      return;
    }

    if (PasswordAnalyzer.isWeak(_passwordController.text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Warning: This password is weak! Consider generating a stronger one.',
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.warning.withValues(alpha: 0.9),
            duration: const Duration(seconds: 3),
          ),
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
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brandColor = AppIconMapper.getBrandColor(_currentTitle);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          widget.entryToEdit == null ? 'Add Password' : 'Edit Vault Entry',
          style: AppTextStyles.heading3,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Icon preview
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: brandColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: brandColor.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Center(
                child: _currentTitle.isEmpty
                    ? const Icon(Icons.vpn_key,
                        color: AppColors.textMuted, size: 36)
                    : _buildIconPreview(brandColor),
              ),
            ),
            const SizedBox(height: 28),

            // Title field with autocomplete
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return AppIconMapper.popularApps.where((String option) {
                  return option
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                _titleController.text = selection;
                setState(() => _currentTitle = selection);
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 8,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            dense: true,
                            title: Text(option,
                                style: AppTextStyles.body.copyWith(
                                    color: AppColors.textPrimary)),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
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
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textPrimary),
                  decoration: AppDecorations.inputDecoration(
                    hintText: 'Title / Website App',
                    prefixIcon: Icons.web,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Username field
            TextField(
              controller: _usernameController,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textPrimary),
              decoration: AppDecorations.inputDecoration(
                hintText: 'Username',
                prefixIcon: Icons.person_outline,
              ),
            ),
            const SizedBox(height: 16),

            // Password field with generate button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _passwordController,
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
