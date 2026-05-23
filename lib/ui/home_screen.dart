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
    return ((strong / _decryptedEntries.length) * 100).round();
  }

  void _toggleReveal(int index) {
    setState(() {
      if (_revealedPasswords.contains(index)) {
        _revealedPasswords.remove(index);
      } else {
        _revealedPasswords.add(index);
      }
    });
  }

  void _copyPassword(String password) {
    Clipboard.setData(ClipboardData(text: password));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Password copied!',
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 1),
      ),
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
    if (result == true) _loadAndDecryptEntries();
  }

  void _deleteEntry(DecryptedEntry item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete ${item.entry.title}?',
            style: AppTextStyles.heading3),
        content: Text('This action cannot be undone.', style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: AppTextStyles.label.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _databaseService.delete(item.entry.id!);
      _loadAndDecryptEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar
            _buildSidebar(),
            // Main content
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary))
                        : FadeTransition(
                            opacity: _fadeIn,
                            child: Row(
                              children: [
                                // Main grid area
                                Expanded(
                                  flex: isWide ? 3 : 1,
                                  child: _buildMainContent(),
                                ),
                                // Right passwords panel (wide only)
                                if (isWide) ...[
                                  Container(
                                    width: 1,
                                    color: AppColors.surfaceBorder,
                                  ),
                                  SizedBox(
                                    width: 280,
                                    child: _buildRightPanel(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Left sidebar with icon navigation.
  Widget _buildSidebar() {
    final items = [
      _SidebarItem(Icons.lock_outline, 'Vaults'),
      _SidebarItem(Icons.folder_outlined, 'Categories'),
      _SidebarItem(Icons.shield_outlined, 'Security\nScore'),
      _SidebarItem(Icons.settings_outlined, 'Settings'),
    ];

    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Logo at top
          Container(
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.shield,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(items.length, (index) {
            final isSelected = _selectedSidebarIndex == index;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                onTap: () => setState(() => _selectedSidebarIndex = index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 56,
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            width: 1)
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Special badge for security score
                      if (index == 2) ...[
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                value: _securityScore / 100,
                                strokeWidth: 2.5,
                                backgroundColor:
                                    AppColors.surfaceBorder,
                                color: _securityScore >= 70
                                    ? AppColors.success
                                    : _securityScore >= 40
                                        ? AppColors.warning
                                        : AppColors.error,
                              ),
                            ),
                            Text(
                              '$_securityScore%',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 7,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ] else
                        Icon(
                          items[index].icon,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textMuted,
                          size: 22,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        items[index].label,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 9,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          // Lock button
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: IconButton(
              onPressed: () => widget.sessionManager.lock(),
              icon: const Icon(Icons.logout, color: AppColors.textMuted, size: 20),
              tooltip: 'Lock Vault',
            ),
          ),
        ],
      ),
    );
  }

  /// Top bar with search, avatar, and add button.
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: AppTextStyles.body
                      .copyWith(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.textMuted, size: 18),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // User avatar
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.cyanGradient,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          // Add new entry button
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AddPasswordScreen(sessionManager: widget.sessionManager),
          ),
        );
        if (result == true) _loadAndDecryptEntries();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              'Add New Entry',
              style: AppTextStyles.label
                  .copyWith(color: AppColors.textPrimary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// Main content area with password grid and ZK card.
  Widget _buildMainContent() {
    final entries = _filteredEntries;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Password cards grid
          if (entries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Column(
                  children: [
                    const Icon(Icons.lock_open,
                        size: 64, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    Text('No passwords stored yet.',
                        style: AppTextStyles.body),
                    const SizedBox(height: 8),
                    Text('Tap "Add New Entry" to get started.',
                        style: AppTextStyles.caption),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 800
                    ? 3
                    : constraints.maxWidth > 500
                        ? 2
                        : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.65,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) =>
                      _buildPasswordCard(entries[index], index),
                );
              },
            ),
          const SizedBox(height: 20),
          // Zero-Knowledge Architecture card
          _buildZeroKnowledgeCard(),
        ],
      ),
    );
  }

  /// Individual password card.
  Widget _buildPasswordCard(DecryptedEntry item, int index) {
    final isRevealed = _revealedPasswords.contains(index);
    final brandColor = AppIconMapper.getBrandColor(item.entry.title);

    return GestureDetector(
      onTap: () => _editEntry(item),
      onLongPress: () => _deleteEntry(item),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: Icon + title
            Row(
              children: [
                // Brand icon circle
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: brandColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: _buildBrandWidget(item.entry.title, brandColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.entry.title,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${item.entry.title.toLowerCase().replaceAll(' ', '')}.com',
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Username
            Text(
              'Username: ${item.entry.username}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            // Password
            Text(
              'Password: ${isRevealed ? item.plaintext : '••••••••'}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Action buttons
            Row(
              children: [
                _buildCardAction(
                  icon: Icons.copy,
                  label: 'Copy',
                  color: AppColors.primary,
                  onTap: () => _copyPassword(item.plaintext),
                ),
                const SizedBox(width: 12),
                _buildCardAction(
                  icon: isRevealed
                      ? Icons.visibility_off
                      : Icons.visibility,
                  label: isRevealed ? 'Hide' : 'Reveal',
                  color: AppColors.accent,
                  onTap: () => _toggleReveal(index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandWidget(String title, Color brandColor) {
    final icon = AppIconMapper.getIconFor(title);
    if (icon != Icons.vpn_key) {
      return Icon(icon, color: brandColor, size: 20);
    }
    // Fallback: show initial letter
    return Text(
      AppIconMapper.getInitial(title),
      style: AppTextStyles.heading3.copyWith(
        color: brandColor,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildCardAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Zero-Knowledge Architecture information card.
  Widget _buildZeroKnowledgeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Key icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.cyanGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.vpn_key, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 20),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zero-Knowledge Architecture',
                  style: AppTextStyles.heading3.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildZkChip('Your Local'),
                    const SizedBox(width: 8),
                    _buildZkChip('Local Key'),
                    const SizedBox(width: 8),
                    _buildZkChip('Encrypted\nData Flow'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZkChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Right panel showing password list (wide layout only).
  Widget _buildRightPanel() {
    return Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Passwords',
              style: AppTextStyles.heading3.copyWith(fontSize: 16),
            ),
          ),
          Expanded(
            child: _decryptedEntries.isEmpty
                ? Center(
                    child: Text('No entries',
                        style: AppTextStyles.caption),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _decryptedEntries.length,
                    itemBuilder: (context, index) {
                      final item = _decryptedEntries[index];
                      final brandColor =
                          AppIconMapper.getBrandColor(item.entry.title);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: brandColor.withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: _buildBrandWidget(
                                        item.entry.title, brandColor),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.entry.title,
                                        style: AppTextStyles.label
                                            .copyWith(
                                          color: AppColors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        item.entry.title,
                                        style: AppTextStyles.caption
                                            .copyWith(fontSize: 9),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Username: ${item.entry.username}',
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 10),
                            ),
                            Text(
                              'Password: ••••••••',
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 10),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildCardAction(
                                  icon: Icons.copy,
                                  label: 'Copy',
                                  color: AppColors.primary,
                                  onTap: () =>
                                      _copyPassword(item.plaintext),
                                ),
                                const SizedBox(width: 12),
                                _buildCardAction(
                                  icon: Icons.visibility,
                                  label: 'Reveal',
                                  color: AppColors.accent,
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
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
