import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/crypto_service.dart';
import '../services/database_service.dart';
import '../services/password_analyzer.dart';
import '../services/biometric_service.dart';
import '../models/password_entry.dart';
import '../utils/app_icons.dart';
import '../utils/app_theme.dart';
import '../main.dart';
import 'add_password_screen.dart';
import 'views/vault_types.dart';
import 'views/categories_view.dart';
import 'views/security_view.dart';
import 'views/settings_view.dart';

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
  final _biometricService = BiometricService();

  List<DecryptedEntryData> _decryptedEntries = [];
  bool _isLoading = true;
  int _selectedSidebarIndex = 0;
  String _searchQuery = '';
  final Set<int> _revealedPasswords = {};
  bool _biometricEnabled = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  // Sidebar items definition
  static const _sidebarItems = [
    _SidebarItem(Icons.lock_outline, 'Vaults'),
    _SidebarItem(Icons.folder_outlined, 'Categories'),
    _SidebarItem(Icons.shield_outlined, 'Security\nScore'),
    _SidebarItem(Icons.settings_outlined, 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadAndDecryptEntries();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final available = await _biometricService.isBiometricAvailable();
    if (mounted) setState(() => _biometricEnabled = available);
  }

  Future<void> _loadAndDecryptEntries() async {
    setState(() => _isLoading = true);
    final rawEntries = await _databaseService.readAllEntries();
    final decoded = <DecryptedEntryData>[];

    for (final entry in rawEntries) {
      try {
        final box = SecretBox(
          base64Decode(entry.ciphertext),
          nonce: base64Decode(entry.nonce),
          mac: Mac(base64Decode(entry.mac)),
        );
        final plaintext = await _cryptoService.decryptPassword(
            box, widget.sessionManager.masterKey!);
        final isWeak = PasswordAnalyzer.isWeak(plaintext);
        decoded.add(DecryptedEntryData(entry, plaintext, isWeak));
      } catch (_) {
        // Skip silently on decryption failure
      }
    }

    setState(() {
      _decryptedEntries = decoded;
      _isLoading = false;
    });
    _fadeController.forward(from: 0);
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  List<DecryptedEntryData> get _filteredEntries {
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

  // ── Actions ────────────────────────────────────────────────────────────────

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
        content: Text('Password copied to clipboard',
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _editEntry(DecryptedEntryData item) async {
    final result = await Navigator.push(
      context,
      _slidePageRoute(AddPasswordScreen(
        sessionManager: widget.sessionManager,
        entryToEdit: item.entry,
        initialPlaintext: item.plaintext,
      )),
    );
    if (result == true) _loadAndDecryptEntries();
  }

  void _deleteEntry(DecryptedEntryData item) async {
    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Delete',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, _, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
      pageBuilder: (ctx, _, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delete Entry?', style: AppTextStyles.heading3),
                  const SizedBox(height: 8),
                  Text(
                    'This will permanently remove "${item.entry.title}" from your vault. This action cannot be undone.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: AppColors.surfaceBorder),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Cancel',
                              style: AppTextStyles.label
                                  .copyWith(color: AppColors.textSecondary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Delete',
                              style: AppTextStyles.label
                                  .copyWith(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (confirm == true) {
      await _databaseService.delete(item.entry.id!);
      _loadAndDecryptEntries();
    }
  }

  Future<void> _improvePassword(
      DecryptedEntryData item, String newPassword) async {
    try {
      final secretBox = await _cryptoService.encryptPassword(
        newPassword,
        widget.sessionManager.masterKey!,
      );
      final updated = PasswordEntry(
        id: item.entry.id,
        title: item.entry.title,
        username: item.entry.username,
        ciphertext: base64Encode(secretBox.cipherText),
        nonce: base64Encode(secretBox.nonce),
        mac: base64Encode(secretBox.mac.bytes),
      );
      await _databaseService.update(updated);
      _loadAndDecryptEntries();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password updated for ${item.entry.title}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textPrimary)),
            backgroundColor: AppColors.success.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      // Silently fail — user retains old password
    }
  }

  // ── Routing helper ─────────────────────────────────────────────────────────

  PageRoute _slidePageRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, animation, _) => page,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, anim, _, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            _buildSidebar(),
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
                                Expanded(
                                  flex: isWide ? 3 : 1,
                                  child: _buildCurrentView(),
                                ),
                                if (isWide) ...[
                                  Container(
                                      width: 1,
                                      color: AppColors.surfaceBorder),
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

  // ── Sidebar ────────────────────────────────────────────────────────────────

  Widget _buildSidebar() {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
            right: BorderSide(color: AppColors.surfaceBorder, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Logo
          Container(
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.shield,
                color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 20),
          ..._sidebarItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = _selectedSidebarIndex == index;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Tooltip(
                message: item.label.replaceAll('\n', ' '),
                preferBelow: false,
                child: InkWell(
                  onTap: () => setState(() => _selectedSidebarIndex = index),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: 56,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color:
                                  AppColors.primary.withValues(alpha: 0.4),
                              width: 1)
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (index == 2) ...[
                          // Security score badge
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  value: _securityScore / 100,
                                  strokeWidth: 2.5,
                                  backgroundColor: AppColors.surfaceBorder,
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
                            item.icon,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textMuted,
                            size: 22,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
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
              ),
            );
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: IconButton(
              onPressed: () => widget.sessionManager.lock(),
              icon: const Icon(Icons.logout,
                  color: AppColors.textMuted, size: 20),
              tooltip: 'Lock Vault',
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
            bottom: BorderSide(color: AppColors.surfaceBorder, width: 1)),
      ),
      child: Row(
        children: [
          // ── Search field — expands to fill available width ──────────────
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search vault…',
                hintStyle: AppTextStyles.body
                    .copyWith(color: AppColors.textMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.textMuted, size: 18),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.surfaceBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.surfaceBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.cyanGradient,
            ),
            child:
                const Icon(Icons.person, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
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
          _slidePageRoute(AddPasswordScreen(
              sessionManager: widget.sessionManager)),
        );
        if (result == true) _loadAndDecryptEntries();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: AppColors.primary, size: 16),
            if (MediaQuery.of(context).size.width > 500) ...[
              const SizedBox(width: 6),
              Text(
                'Add New Entry',
                style: AppTextStyles.label.copyWith(
                    color: AppColors.textPrimary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Indexed View Switcher ─────────────────────────────────────────────────

  Widget _buildCurrentView() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_selectedSidebarIndex),
        child: switch (_selectedSidebarIndex) {
          0 => _buildVaultView(),
          1 => CategoriesView(
              entries: _decryptedEntries,
              onCopyPassword: (e) => _copyPassword(e.plaintext),
              onEdit: _editEntry,
            ),
          2 => SecurityView(
              entries: _decryptedEntries,
              onImprovePassword: _improvePassword,
            ),
          3 => SettingsView(
              biometricEnabled: _biometricEnabled,
              onBiometricToggle: (v) => setState(() => _biometricEnabled = v),
            ),
          _ => _buildVaultView(),
        },
      ),
    );
  }

  // ── Vault View (index 0) ───────────────────────────────────────────────────

  Widget _buildVaultView() {
    final entries = _filteredEntries;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          _buildZeroKnowledgeCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Password Card ─────────────────────────────────────────────────────────

  Widget _buildPasswordCard(DecryptedEntryData item, int index) {
    final isRevealed = _revealedPasswords.contains(index);
    final brandColor = AppIconMapper.getBrandColor(item.entry.title);

    return GestureDetector(
      onTap: () => _editEntry(item),
      onLongPress: () => _deleteEntry(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isWeak
                ? AppColors.error.withValues(alpha: 0.4)
                : AppColors.surfaceBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: favicon + title
            Row(
              children: [
                _buildFaviconWidget(item.entry.title, brandColor, 36),
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (item.isWeak)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Weak',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.error,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            // Credentials
            Text(
              'Username: ${item.entry.username}',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              'Password: ${isRevealed ? item.plaintext : '••••••••'}',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Actions
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

  // ── Favicon widget (cached) ────────────────────────────────────────────────


  /// Normalises a service name to its most likely domain.
  static String _titleToDomain(String title) {
    final lower = title.toLowerCase().trim().replaceAll(' ', '');
    return '$lower.com';
  }

  Widget _buildFaviconWidget(String title, Color brandColor, double size) {
    final domain = _titleToDomain(title);
    // Clearbit returns high-res 128x128 PNG logos
    final clearbitUrl = 'https://logo.clearbit.com/$domain';
    // DuckDuckGo .ico is a reliable secondary fallback
    final ddgUrl = 'https://icons.duckduckgo.com/ip3/$domain.ico';

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: CachedNetworkImage(
        imageUrl: clearbitUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => _buildShimmerBox(size),
        // Clearbit failed -> try DuckDuckGo
        errorWidget: (_, _, _) => CachedNetworkImage(
          imageUrl: ddgUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) => _buildShimmerBox(size),
          // Both failed -> branded initial / icon
          errorWidget: (_, _, _) =>
              _buildInitialWidget(title, brandColor, size),
        ),
      ),
    );
  }

  Widget _buildShimmerBox(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceBorder,
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
      );
  Widget _buildInitialWidget(String title, Color brandColor, double size) {
    final icon = AppIconMapper.getIconFor(title);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: brandColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Center(
        child: icon != Icons.vpn_key
            ? Icon(icon, color: brandColor, size: size * 0.55)
            : Text(
                AppIconMapper.getInitial(title),
                style: AppTextStyles.heading3.copyWith(
                  color: brandColor,
                  fontSize: size * 0.45,
                  fontWeight: FontWeight.w800,
                ),
              ),
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

  // ── Zero-Knowledge Card (fixed overflow) ──────────────────────────────────

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
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.cyanGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.vpn_key,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          // Info — expanded to take remaining width, no overflow
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Zero-Knowledge Architecture',
                  style: AppTextStyles.heading3.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 10),
                // Wrap ensures chips reflow on narrow screens
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildZkChip('Your Local Device'),
                    _buildZkChip('Local Key Only'),
                    _buildZkChip('AES-256-GCM'),
                    _buildZkChip('Offline-First'),
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
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ── Right panel (wide layout) ─────────────────────────────────────────────

  Widget _buildRightPanel() {
    return Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'All Passwords',
                    style: AppTextStyles.heading3.copyWith(fontSize: 15),
                  ),
                ),
                Text(
                  '${_decryptedEntries.length} entries',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Expanded(
            child: _decryptedEntries.isEmpty
                ? Center(
                    child: Text('No entries',
                        style: AppTextStyles.caption))
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
                          border: Border.all(
                              color: AppColors.surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            _buildFaviconWidget(
                                item.entry.title, brandColor, 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.entry.title,
                                    style: AppTextStyles.label.copyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    item.entry.username,
                                    style: AppTextStyles.caption
                                        .copyWith(fontSize: 9),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () =>
                                  _copyPassword(item.plaintext),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.copy,
                                    size: 13,
                                    color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar Item ──────────────────────────────────────────────────────────────

class _SidebarItem {
  final IconData icon;
  final String label;
  const _SidebarItem(this.icon, this.label);
}
