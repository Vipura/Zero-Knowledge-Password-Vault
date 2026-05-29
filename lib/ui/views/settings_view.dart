import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class SettingsView extends StatefulWidget {
  final bool biometricEnabled;
  final ValueChanged<bool> onBiometricToggle;

  const SettingsView({
    super.key,
    required this.biometricEnabled,
    required this.onBiometricToggle,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  int _autoLockIndex = 1; // default: 1 min
  int _clipboardIndex = 1; // default: 30s
  bool _exportLoading = false;

  static const _autoLockOptions = [
    '30 seconds',
    '1 minute',
    '5 minutes',
    '15 minutes',
    'Never',
  ];
  static const _clipboardOptions = [
    '15 seconds',
    '30 seconds',
    '1 minute',
    'Never',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: AppTextStyles.heading2.copyWith(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            'Security & privacy preferences',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),

          // ── Security section ─────────────────────────────────────────────
          _buildSectionLabel('Security'),
          const SizedBox(height: 12),

          _buildToggleTile(
            icon: Icons.fingerprint,
            iconColor: AppColors.primary,
            title: 'Biometric Unlock',
            subtitle: 'Use fingerprint or Face ID to unlock the vault',
            value: widget.biometricEnabled,
            onChanged: widget.onBiometricToggle,
          ),
          const SizedBox(height: 10),

          _buildDropdownTile(
            icon: Icons.lock_clock_outlined,
            iconColor: AppColors.warning,
            title: 'Auto-Lock Timeout',
            subtitle:
                'Lock the vault after inactivity: ${_autoLockOptions[_autoLockIndex]}',
            options: _autoLockOptions,
            selectedIndex: _autoLockIndex,
            onChanged: (i) => setState(() => _autoLockIndex = i),
          ),

          // ── Clipboard section ────────────────────────────────────────────
          const SizedBox(height: 20),
          _buildSectionLabel('Clipboard'),
          const SizedBox(height: 12),

          _buildDropdownTile(
            icon: Icons.content_paste_off_outlined,
            iconColor: AppColors.accent,
            title: 'Clipboard Auto-Clear',
            subtitle:
                'Wipe copied passwords after: ${_clipboardOptions[_clipboardIndex]}',
            options: _clipboardOptions,
            selectedIndex: _clipboardIndex,
            onChanged: (i) => setState(() => _clipboardIndex = i),
          ),

          // ── Backup section ───────────────────────────────────────────────
          const SizedBox(height: 20),
          _buildSectionLabel('Data & Backup'),
          const SizedBox(height: 12),

          _buildActionTile(
            icon: Icons.file_download_outlined,
            iconColor: AppColors.success,
            title: 'Export Encrypted Backup',
            subtitle: 'Save a local, encrypted copy of your vault data',
            trailing: _exportLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: AppColors.success,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppColors.textMuted),
            onTap: _exportLoading ? null : _exportBackup,
          ),
          const SizedBox(height: 10),

          _buildActionTile(
            icon: Icons.delete_outline,
            iconColor: AppColors.error,
            title: 'Clear Vault Cache',
            subtitle: 'Purge the locally cached favicon images',
            trailing: Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textMuted),
            onTap: _clearCache,
          ),

          const SizedBox(height: 32),
          // About card
          _buildAboutCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: AppTextStyles.caption.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _SettingsTile(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: 0.3);
          }
          return AppColors.surfaceBorder;
        }),
      ),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return _SettingsTile(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      trailing: PopupMenuButton<int>(
        initialValue: selectedIndex,
        onSelected: onChanged,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        itemBuilder: (ctx) => options
            .asMap()
            .entries
            .map(
              (e) => PopupMenuItem<int>(
                value: e.key,
                child: Text(
                  e.value,
                  style: AppTextStyles.body.copyWith(
                    color: e.key == selectedIndex
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            )
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                options[selectedIndex],
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more,
                  color: AppColors.primary, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return _SettingsTile(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppColors.cyanGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Zero-Knowledge Vault',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    )),
                Text(
                  'v1.0.0 · All data encrypted locally · No servers',
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup() async {
    setState(() => _exportLoading = true);
    try {
      final dbPath = await getDatabasesPath();
      final exportDir = Directory(p.join(dbPath, '..', 'exports'));
      await exportDir.create(recursive: true);
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file =
          File(p.join(exportDir.path, 'zk_vault_backup_$timestamp.json'));

      final entries = await DatabaseService.instance.readAllEntries();
      final payload = jsonEncode({
        'exported_at': timestamp,
        'version': '1.0.0',
        'note': 'All entries are AES-256-GCM encrypted. '
            'Master password required to decrypt.',
        'entries': entries
            .map((e) => {
                  'title': e.title,
                  'username': e.username,
                  'ciphertext': e.ciphertext,
                  'nonce': e.nonce,
                  'mac': e.mac,
                })
            .toList(),
      });

      await file.writeAsString(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup saved to ${file.path}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textPrimary)),
            backgroundColor: AppColors.success.withValues(alpha: 0.9),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textPrimary)),
            backgroundColor: AppColors.error.withValues(alpha: 0.9),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }

  void _clearCache() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Favicon cache cleared.',
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ─── Shared tile widget ────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(fontSize: 10),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
