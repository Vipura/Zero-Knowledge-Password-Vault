import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/password_generator.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_icons.dart';
import 'vault_types.dart';

class SecurityView extends StatefulWidget {
  final List<DecryptedEntryData> entries;
  final void Function(DecryptedEntryData, String newPassword) onImprovePassword;

  const SecurityView({
    super.key,
    required this.entries,
    required this.onImprovePassword,
  });

  @override
  State<SecurityView> createState() => _SecurityViewState();
}

class _SecurityViewState extends State<SecurityView>
    with SingleTickerProviderStateMixin {
  late AnimationController _gaugeController;
  late Animation<double> _gaugeAnim;

  @override
  void initState() {
    super.initState();
    _gaugeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _gaugeAnim = CurvedAnimation(
        parent: _gaugeController, curve: Curves.easeOutCubic);
    _gaugeController.forward();
  }

  @override
  void dispose() {
    _gaugeController.dispose();
    super.dispose();
  }

  int get _securityScore {
    if (widget.entries.isEmpty) return 100;
    final strong = widget.entries.where((e) => !e.isWeak).length;
    return ((strong / widget.entries.length) * 100).round();
  }

  List<DecryptedEntryData> get _weakEntries =>
      widget.entries.where((e) => e.isWeak).toList();

  Color get _scoreColor {
    if (_securityScore >= 80) return AppColors.success;
    if (_securityScore >= 50) return AppColors.warning;
    return AppColors.error;
  }

  String get _scoreLabel {
    if (_securityScore >= 80) return 'Strong';
    if (_securityScore >= 50) return 'Moderate';
    return 'At Risk';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Security Score',
              style: AppTextStyles.heading2.copyWith(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            'Monitor your vault\'s overall password health',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),

          // Score gauge card
          _buildScoreCard(),
          const SizedBox(height: 20),

          // Stats row
          _buildStatsRow(),
          const SizedBox(height: 24),

          // Weak passwords section
          if (_weakEntries.isNotEmpty) ...[
            Text(
              'Passwords That Need Attention',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            ..._weakEntries
                .map((e) => _buildWeakEntryCard(e))
                ,
          ] else ...[
            _buildAllStrongCard(),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _scoreColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _scoreColor.withValues(alpha: 0.1),
            blurRadius: 24,
            spreadRadius: -4,
          )
        ],
      ),
      child: Row(
        children: [
          // Animated radial gauge
          AnimatedBuilder(
            animation: _gaugeAnim,
            builder: (context, _) {
              return SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(
                  painter: _GaugePainter(
                    progress: (_securityScore / 100) * _gaugeAnim.value,
                    color: _scoreColor,
                    backgroundColor:
                        AppColors.surfaceBorder,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_securityScore',
                          style: AppTextStyles.heading2.copyWith(
                            fontSize: 22,
                            color: _scoreColor,
                          ),
                        ),
                        Text(
                          '%',
                          style: AppTextStyles.caption.copyWith(
                            color: _scoreColor,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _scoreColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _scoreLabel,
                      style: AppTextStyles.heading3.copyWith(
                        color: _scoreColor,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _securityScore >= 80
                      ? 'Your vault is well-protected. Keep it up!'
                      : _securityScore >= 50
                          ? 'Some passwords need improvement.'
                          : 'Critical: Multiple weak passwords detected!',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedBuilder(
                    animation: _gaugeAnim,
                    builder: (context, _) {
                      return LinearProgressIndicator(
                        value: (_securityScore / 100) * _gaugeAnim.value,
                        backgroundColor:
                            AppColors.surfaceBorder,
                        color: _scoreColor,
                        minHeight: 6,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final total = widget.entries.length;
    final weak = _weakEntries.length;
    final strong = total - weak;

    return Row(
      children: [
        _buildStatChip('Total', '$total', AppColors.primary),
        const SizedBox(width: 10),
        _buildStatChip('Strong', '$strong', AppColors.success),
        const SizedBox(width: 10),
        _buildStatChip('Weak', '$weak', AppColors.error),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.heading2.copyWith(
                color: color,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeakEntryCard(DecryptedEntryData item) {
    final brandColor = AppIconMapper.getBrandColor(item.entry.title);
    final domain =
        '${item.entry.title.toLowerCase().replaceAll(' ', '')}.com';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // Favicon
            _buildFaviconWidget(item.entry.title, brandColor),
            const SizedBox(width: 12),
            // Info
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
                    item.entry.username.isNotEmpty
                        ? item.entry.username
                        : domain,
                    style: AppTextStyles.caption.copyWith(fontSize: 10),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            // Improve button
            _buildImproveButton(item),
          ],
        ),
      ),
    );
  }

  Widget _buildImproveButton(DecryptedEntryData item) {
    return InkWell(
      onTap: () => _showPasswordGeneratorModal(item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppColors.cyanGradient,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_fix_high, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(
              'Improve',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllStrongCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_user_outlined,
              color: AppColors.success, size: 40),
          const SizedBox(height: 12),
          Text(
            'All Passwords Are Strong!',
            style: AppTextStyles.heading3.copyWith(
              color: AppColors.success,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your vault has zero weak passwords. Keep maintaining good security hygiene.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showPasswordGeneratorModal(DecryptedEntryData item) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Password Generator',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (ctx, anim, secondAnim, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          ),
        );
      },
      pageBuilder: (ctx, _, _) =>
          _PasswordGeneratorSheet(item: item, onAccept: (newPw) {
        Navigator.pop(ctx);
        widget.onImprovePassword(item, newPw);
      }),
    );
  }

  Widget _buildFaviconWidget(String title, Color brandColor) {
    final domain = '${title.toLowerCase().replaceAll(' ', '')}.com';
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: 'https://icons.duckduckgo.com/ip3/$domain.ico',
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: brandColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              title.isNotEmpty ? title[0].toUpperCase() : '?',
              style: AppTextStyles.label.copyWith(
                color: brandColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        placeholder: (_, _) => Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceBorder,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

// ─── Password Generator Bottom Sheet ──────────────────────────────────────────

class _PasswordGeneratorSheet extends StatefulWidget {
  final DecryptedEntryData item;
  final void Function(String) onAccept;

  const _PasswordGeneratorSheet(
      {required this.item, required this.onAccept});

  @override
  State<_PasswordGeneratorSheet> createState() =>
      _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<_PasswordGeneratorSheet> {
  int _length = 16;
  bool _uppercase = true;
  bool _lowercase = true;
  bool _numbers = true;
  bool _symbols = true;
  late String _generated;

  @override
  void initState() {
    super.initState();
    _generated = PasswordGenerator.generate(
      length: _length,
      uppercase: _uppercase,
      lowercase: _lowercase,
      numbers: _numbers,
      symbols: _symbols,
    );
  }

  void _regenerate() {
    setState(() {
      _generated = PasswordGenerator.generate(
        length: _length,
        uppercase: _uppercase,
        lowercase: _lowercase,
        numbers: _numbers,
        symbols: _symbols,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 40,
                  spreadRadius: -4,
                )
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_fix_high,
                            color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Improve Password',
                                style: AppTextStyles.heading3
                                    .copyWith(fontSize: 16)),
                            Text(
                              widget.item.entry.title,
                              style: AppTextStyles.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close,
                            color: AppColors.textMuted, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Generated password display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _generated,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.primary,
                              fontFamily: 'monospace',
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: _generated));
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.copy,
                                color: AppColors.primary, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Length slider
                  Row(
                    children: [
                      Text('Length: $_length',
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.textSecondary)),
                      Expanded(
                        child: Slider(
                          value: _length.toDouble(),
                          min: 8,
                          max: 32,
                          divisions: 24,
                          activeColor: AppColors.primary,
                          inactiveColor:
                              AppColors.surfaceBorder,
                          onChanged: (v) {
                            setState(() => _length = v.round());
                            _regenerate();
                          },
                        ),
                      ),
                    ],
                  ),

                  // Toggles
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildToggleChip(
                          'ABC', _uppercase, (v) {
                        setState(() => _uppercase = v);
                        _regenerate();
                      }),
                      _buildToggleChip(
                          'abc', _lowercase, (v) {
                        setState(() => _lowercase = v);
                        _regenerate();
                      }),
                      _buildToggleChip(
                          '123', _numbers, (v) {
                        setState(() => _numbers = v);
                        _regenerate();
                      }),
                      _buildToggleChip(
                          '!@#', _symbols, (v) {
                        setState(() => _symbols = v);
                        _regenerate();
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _regenerate,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Regenerate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(
                                color: AppColors.primary
                                    .withValues(alpha: 0.5)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.cyanGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ElevatedButton(
                            onPressed: () => widget.onAccept(_generated),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              'Use Password',
                              style: AppTextStyles.label.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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
  }

  Widget _buildToggleChip(
      String label, bool active, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!active),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: active ? AppColors.primary : AppColors.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─── Custom Gauge Painter ─────────────────────────────────────────────────────

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _GaugePainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const startAngle = -pi / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
