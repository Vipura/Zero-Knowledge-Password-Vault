import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_icons.dart';
import 'vault_types.dart';

/// Category definitions for grouping credential entries.
enum VaultCategory {
  websites('Websites', Icons.language_outlined),
  apps('Apps', Icons.apps_outlined),
  social('Social', Icons.people_outline),
  banking('Banking', Icons.account_balance_outlined),
  streaming('Streaming', Icons.play_circle_outline);

  final String label;
  final IconData icon;
  const VaultCategory(this.label, this.icon);
}

// Keyword maps for auto-categorisation
const _socialKeywords = [
  'instagram', 'facebook', 'twitter', 'x', 'linkedin', 'reddit',
  'discord', 'tiktok', 'snapchat', 'pinterest', 'tumblr', 'mastodon',
];
const _bankingKeywords = [
  'bank', 'paypal', 'stripe', 'visa', 'mastercard', 'credit', 'debit',
  'finance', 'wallet', 'crypto', 'coinbase', 'binance', 'revolut', 'wise',
];
const _streamingKeywords = [
  'netflix', 'youtube', 'spotify', 'hulu', 'disney', 'prime', 'apple tv',
  'twitch', 'crunchyroll', 'peacock', 'hbo', 'paramount', 'deezer',
];
const _appKeywords = [
  'gmail', 'google', 'microsoft', 'apple', 'amazon', 'slack', 'notion',
  'zoom', 'github', 'gitlab', 'dropbox', 'figma', '1password', 'lastpass',
];

VaultCategory _categorise(String title) {
  final lower = title.toLowerCase();
  for (final k in _socialKeywords) {
    if (lower.contains(k)) return VaultCategory.social;
  }
  for (final k in _bankingKeywords) {
    if (lower.contains(k)) return VaultCategory.banking;
  }
  for (final k in _streamingKeywords) {
    if (lower.contains(k)) return VaultCategory.streaming;
  }
  for (final k in _appKeywords) {
    if (lower.contains(k)) return VaultCategory.apps;
  }
  return VaultCategory.websites;
}

class CategoriesView extends StatefulWidget {
  final List<DecryptedEntryData> entries;
  final void Function(DecryptedEntryData) onCopyPassword;
  final void Function(DecryptedEntryData) onEdit;

  const CategoriesView({
    super.key,
    required this.entries,
    required this.onCopyPassword,
    required this.onEdit,
  });

  @override
  State<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<CategoriesView> {
  final Set<VaultCategory> _expanded = {VaultCategory.websites};

  Map<VaultCategory, List<DecryptedEntryData>> get _grouped {
    final map = <VaultCategory, List<DecryptedEntryData>>{};
    for (final cat in VaultCategory.values) {
      map[cat] = [];
    }
    for (final e in widget.entries) {
      final cat = _categorise(e.entry.title);
      map[cat]!.add(e);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          ...VaultCategory.values.map((cat) {
            final items = grouped[cat]!;
            return _buildCategorySection(cat, items);
          }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Categories', style: AppTextStyles.heading2.copyWith(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          'Browse your vault by category',
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildCategorySection(VaultCategory cat, List<DecryptedEntryData> items) {
    final isExpanded = _expanded.contains(cat);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.surfaceBorder,
          ),
          boxShadow: isExpanded
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 16,
                    spreadRadius: -4,
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            // Section header
            InkWell(
              onTap: () => setState(() {
                if (isExpanded) {
                  _expanded.remove(cat);
                } else {
                  _expanded.add(cat);
                }
              }),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(cat.icon, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.label,
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${items.length} ${items.length == 1 ? 'entry' : 'entries'}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: isExpanded
                            ? AppColors.primary
                            : AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Expanded items
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                      child: Text(
                        'No entries in this category yet.',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(
                          left: 12, right: 12, bottom: 12),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) =>
                          _buildEntryTile(items[idx]),
                    ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryTile(DecryptedEntryData item) {
    final brandColor = AppIconMapper.getBrandColor(item.entry.title);
    final domain =
        '${item.entry.title.toLowerCase().replaceAll(' ', '')}.com';

    return InkWell(
      onTap: () => widget.onEdit(item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            // Favicon / icon
            _buildFaviconWidget(item.entry.title, brandColor),
            const SizedBox(width: 12),
            // Title + username
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
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Weak badge
            if (item.isWeak)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Weak',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.error,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            // Copy button
            InkWell(
              onTap: () => widget.onCopyPassword(item),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.copy,
                    size: 15, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaviconWidget(String title, Color brandColor) {
    final domain = '${title.toLowerCase().replaceAll(' ', '')}.com';
    final faviconUrl =
        'https://icons.duckduckgo.com/ip3/$domain.ico';
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: faviconUrl,
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
