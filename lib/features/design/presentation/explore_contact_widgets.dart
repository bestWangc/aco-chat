part of 'aco_design_shell.dart';

class _ContactDetailPage extends StatelessWidget {
  const _ContactDetailPage({
    required this.palette,
    required this.name,
    required this.onMessagePressed,
  });

  final AcoPalette palette;
  final String name;
  final VoidCallback onMessagePressed;

  String get _handle => '@${name.toLowerCase().replaceAll(' ', '_')}';

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: palette.background,
    child: AcoSafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          AcoPageHeader(
            palette: palette,
            title: '好友详情',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const AcoAvatar(size: 70),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: AcoTypography.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _handle,
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: AcoTypography.body,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _ContactDetailActionRow(
            palette: palette,
            icon: CupertinoIcons.chat_bubble,
            label: '发消息',
            onTap: onMessagePressed,
          ),
          const SizedBox(height: 8),
          _ContactDetailActionRow(
            palette: palette,
            icon: CupertinoIcons.phone,
            label: '音频通话',
            onTap: () => _showNotice(context, '音频通话', '通话功能暂未开放。'),
          ),
        ],
      ),
    ),
  );
}

class _ContactDetailActionRow extends StatelessWidget {
  const _ContactDetailActionRow({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final AcoPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 13),
    color: const Color(0xFF191919),
    borderRadius: BorderRadius.circular(12),
    onPressed: onTap,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: palette.accent, size: 19),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _ContactListTile extends StatelessWidget {
  const _ContactListTile({
    required this.palette,
    required this.name,
    required this.onTap,
    this.avatarUrl,
    this.trailing,
    this.backgroundColor,
    this.borderRadius,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 10),
    this.nameMaxLines = 1,
    this.avatarSize = 42,
    this.nameFontSize,
    this.avatarGap = 20,
    this.identity = 0,
    this.staffIdentity = 0,
  });

  final AcoPalette palette;
  final String name;
  final VoidCallback onTap;
  final String? avatarUrl;
  final Widget? trailing;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final EdgeInsets contentPadding;
  final int nameMaxLines;
  final double avatarSize;
  final double? nameFontSize;
  final double avatarGap;
  final int identity;
  final int staffIdentity;

  @override
  Widget build(BuildContext context) {
    final identityAsset = _identityBadgeAsset(identity);
    final staffAsset = _staffLongBadgeAsset(staffIdentity);
    final identityBadgeWidth = _longBadgeWidth(identity) * 1.15;
    final staffBadgeWidth = _longBadgeWidth(staffIdentity) * 1.15;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: double.infinity,
        padding: contentPadding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
        ),
        child: Row(
          children: [
            AcoAvatar(
              size: avatarSize,
              imageUrl: avatarUrl,
              assetPath: _defaultAvatarAsset,
            ),
            SizedBox(width: avatarGap),
            Flexible(
              child: Text(
                name,
                maxLines: nameMaxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: nameFontSize ?? AcoTypography.body,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (identityAsset != null || staffAsset != null)
              const SizedBox(width: 10),
            if (identityAsset != null || staffAsset != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (identityAsset != null)
                    Image.asset(
                      identityAsset,
                      width: identityBadgeWidth,
                      fit: BoxFit.contain,
                    ),
                  if (identityAsset != null && staffAsset != null)
                    const SizedBox(width: 4),
                  if (staffAsset != null)
                    Image.asset(
                      staffAsset,
                      width: staffBadgeWidth,
                      fit: BoxFit.contain,
                    ),
                ],
              ),
            if (trailing != null) ...[const Spacer(), trailing!],
          ],
        ),
      ),
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedHeaderDelegate({
    required this.extent,
    required this.backgroundColor,
    required this.child,
  });

  final double extent;
  final Color backgroundColor;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(color: backgroundColor, child: child);

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) =>
      extent != oldDelegate.extent ||
      backgroundColor != oldDelegate.backgroundColor ||
      child != oldDelegate.child;
}
