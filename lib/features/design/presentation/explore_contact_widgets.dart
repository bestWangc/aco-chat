part of 'aco_design_shell.dart';

class _ContactDetailPage extends StatefulWidget {
  const _ContactDetailPage({
    required this.palette,
    required this.name,
    required this.accountID,
    required this.remark,
    required this.onMessagePressed,
    this.avatarUrl = '',
    this.isFriend = true,
  });

  final AcoPalette palette;
  final String name;
  final String accountID;
  final String remark;
  final ValueChanged<String> onMessagePressed;
  final String avatarUrl;
  final bool isFriend;

  @override
  State<_ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends State<_ContactDetailPage> {
  late String _remark;
  bool _savingRemark = false;

  @override
  void initState() {
    super.initState();
    _remark = widget.remark;
  }

  String get _handle => widget.isFriend
      ? '@${widget.name.toLowerCase().replaceAll(' ', '_')}'
      : '账号：${widget.accountID}';

  Future<void> _editRemark() async {
    if (_savingRemark) return;
    final controller = TextEditingController(text: _remark);
    final enteredRemark = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('设置备注'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            autofocus: true,
            controller: controller,
            maxLength: 64,
            placeholder: '输入备注',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (enteredRemark == null || enteredRemark.trim() == _remark) return;

    final remark = enteredRemark.trim();
    setState(() => _savingRemark = true);
    final client = AccountApiClient();
    try {
      await AccountSession(
        client,
      ).updateFriendRemark(accountID: widget.accountID, remark: remark);
      if (mounted) setState(() => _remark = remark);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '保存备注失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '保存备注失败', '请检查网络后重试。');
    } finally {
      client.close();
      if (mounted) setState(() => _savingRemark = false);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: widget.palette.background,
    child: AcoSafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          AcoPageHeader(
            palette: widget.palette,
            title: widget.isFriend ? '好友详情' : '个人资料',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              AcoAvatar(size: 70, imageUrl: widget.avatarUrl),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.palette.primaryText,
                        fontSize: AcoTypography.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _handle,
                      style: TextStyle(
                        color: widget.palette.mutedText,
                        fontSize: AcoTypography.body,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          if (widget.isFriend) ...[
            _ContactDetailActionRow(
              palette: widget.palette,
              icon: CupertinoIcons.pencil,
              label: _savingRemark
                  ? '保存中...'
                  : _remark.isEmpty
                  ? '设置备注'
                  : '备注：$_remark',
              onTap: () => unawaited(_editRemark()),
            ),
            const SizedBox(height: 8),
          ],
          _ContactDetailActionRow(
            palette: widget.palette,
            icon: CupertinoIcons.chat_bubble,
            label: '发消息',
            onTap: () => widget.onMessagePressed(
              _remark.isEmpty ? widget.name : _remark,
            ),
          ),
          const SizedBox(height: 8),
          _ContactDetailActionRow(
            palette: widget.palette,
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
    color: palette.dark ? const Color(0xFF191919) : palette.surfaceRaised,
    borderRadius: BorderRadius.circular(12),
    onPressed: onTap,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: palette.accentForeground, size: 19),
        const SizedBox(width: 8),
        Text(
          appText(context, label),
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
    this.nameFontWeight = FontWeight.w500,
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
  final FontWeight nameFontWeight;
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
                  fontWeight: nameFontWeight,
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
