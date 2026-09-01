part of 'aco_design_shell.dart';

class _DiscoverShortcut extends StatelessWidget {
  const _DiscoverShortcut({
    required this.palette,
    required this.label,
    required this.onTap,
  });
  final AcoPalette palette;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final Color background;
    switch (label) {
      case '链上数据':
        background = const Color(0xFF3566D6);
        break;
      case 'NFT 市场':
        background = _black;
        break;
      case '交易工具':
        background = palette.surfaceRaised;
        break;
      default:
        background = const Color(0xFFEB2535);
    }

    return SizedBox(
      width: 108,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Column(
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(CupertinoIcons.app_badge, color: _white),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: AcoTypography.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketIcon extends StatelessWidget {
  const _MarketIcon({
    required this.palette,
    required this.icon,
    required this.label,
  });
  final AcoPalette palette;
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: palette.surfaceRaised,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: palette.primaryText),
      ),
    ],
  );
}

class _MarketTabs extends StatelessWidget {
  const _MarketTabs({required this.palette});
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: palette.dark
              ? const Color(0xFFF0F0F0)
              : const Color(0xFF202020),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          '自选 ▼',
          style: TextStyle(
            color: _lime,
            fontSize: AcoTypography.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(width: 30),
      for (final label in const ['现货', '合约', 'DEX'])
        Padding(
          padding: const EdgeInsets.only(right: 30),
          child: Text(
            label,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.body,
            ),
          ),
        ),
      const Spacer(),
      Icon(CupertinoIcons.chevron_right, color: palette.mutedText, size: 20),
    ],
  );
}

class _MarketRow extends StatelessWidget {
  const _MarketRow({
    required this.palette,
    required this.name,
    required this.tag,
    required this.price,
    required this.change,
  });
  final AcoPalette palette;
  final String name, tag, price, change;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: AcoTypography.body,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  color: _lime,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: _black,
                      fontSize: AcoTypography.caption,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '\$29.73万',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: AcoTypography.caption,
              ),
            ),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              price,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: AcoTypography.body,
              ),
            ),
            Text(
              change,
              style: TextStyle(
                color: change.startsWith('-') ? _danger : _lime,
                fontSize: AcoTypography.bodySmall,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _GreenBadge extends StatelessWidget {
  const _GreenBadge({
    required this.label,
    this.color = _lime,
    this.fontSize = AcoTypography.caption,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });
  final String label;
  final Color color;
  final double fontSize;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 4),
    padding: padding,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Text(
      label,
      style: TextStyle(
        color: _black,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.palette,
    required this.label,
    required this.width,
  });
  final AcoPalette palette;
  final String label;
  final double width;
  @override
  Widget build(BuildContext context) {
    final isAldTopic = label == 'ALD! V587!';
    return Container(
      width: width,
      height: 44,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(
          color: palette.dark ? const Color(0xFF4A4A4A) : palette.border,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          if (isAldTopic)
            ClipOval(
              child: Image.asset(
                'assets/design_svg/source/images/img5.jpg',
                width: 42,
                height: 42,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF4A4A4A)),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.play_rectangle,
                color: _lime,
                size: 22,
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _lime,
                fontSize: AcoTypography.body,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, right: 10),
            child: _SignalGlyph(),
          ),
        ],
      ),
    );
  }
}

class _SignalGlyph extends StatelessWidget {
  const _SignalGlyph();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (final height in [10.0, 16.0, 12.0])
        Container(
          width: 6,
          height: height,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: _lime,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
    ],
  );
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.palette});
  final AcoPalette palette;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/design_svg/source/images/img3.jpg',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '素素姐',
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: AcoTypography.bodyEmphasis,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    color: _lime,
                    size: 14,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '7小时前',
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: AcoTypography.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '365天盈利榜第1名',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PostOptionDot(color: palette.primaryText),
                const SizedBox(width: 6),
                _PostOptionDot(color: palette.primaryText),
                const SizedBox(width: 8),
                const _PostOptionStar(),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Text(
        '是非成败转头空，青山依旧在，惯看秋月春风。\n'
        '一壶浊酒喜相逢，古今多少事，滚滚长江东逝\n'
        '水，浪花淘尽英雄。几度夕阳红。白发渔樵江渚\n'
        '上，都付笑谈中。\n'
        '滚滚长江东逝水，浪花淘尽英雄。是非成败转头\n'
        '空，青山依旧在，几度夕阳红。白发渔樵江渚\n'
        '上，惯看秋月春风。一壶浊酒喜相逢，古今多少\n'
        '事，都付笑谈中。',
        style: TextStyle(
          color: palette.primaryText,
          height: 1.5,
          fontSize: AcoTypography.bodySmall,
        ),
      ),
      const SizedBox(height: 24),
      Container(
        height: 273,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(32),
        ),
      ),
      const SizedBox(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _PostAction(
            icon: CupertinoIcons.chat_bubble,
            label: '63',
            palette: palette,
          ),
          _PostAction(
            icon: CupertinoIcons.arrow_2_squarepath,
            label: '1',
            palette: palette,
          ),
          _PostAction(
            icon: CupertinoIcons.heart,
            label: '88',
            palette: palette,
          ),
          _PostAction(
            icon: CupertinoIcons.chart_bar,
            label: '12.64k',
            palette: palette,
          ),
          _PostAction(icon: CupertinoIcons.share, label: '', palette: palette),
        ],
      ),
    ],
  );
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.label,
    required this.palette,
  });
  final IconData icon;
  final String label;
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: palette.primaryText, size: 22),
      if (label.isNotEmpty) ...[
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodyEmphasis,
          ),
        ),
      ],
    ],
  );
}

class _PostOptionDot extends StatelessWidget {
  const _PostOptionDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _PostOptionStar extends StatelessWidget {
  const _PostOptionStar();

  @override
  Widget build(BuildContext context) =>
      const Icon(CupertinoIcons.sparkles, color: _lime, size: 10);
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.palette,
    required this.text,
    required this.mine,
  });
  final AcoPalette palette;
  final String text;
  final bool mine;
  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      style: TextStyle(color: _black, height: 1.4, fontSize: 16),
    );
    if (!mine) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: CustomPaint(
          painter: const _OtherBubblePainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            child: textWidget,
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 390),
      child: CustomPaint(
        painter: const _MineBubblePainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
          child: textWidget,
        ),
      ),
    );
  }
}

class _OtherBubblePainter extends CustomPainter {
  const _OtherBubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const tailWidth = 6.0;
    final bubbleLeft = tailWidth;
    final paint = Paint()..color = const Color(0xFFDDDDDD);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bubbleLeft, 0, size.width - tailWidth, size.height),
        const Radius.circular(3),
      ),
      paint,
    );
    final tailCenter = size.height - 20;
    final tail = Path()
      ..moveTo(bubbleLeft + 1, tailCenter - 6)
      ..lineTo(0, tailCenter)
      ..lineTo(bubbleLeft + 1, tailCenter + 6)
      ..close();
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(covariant _OtherBubblePainter oldDelegate) => false;
}

class _MineBubblePainter extends CustomPainter {
  const _MineBubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const tailWidth = 6.0;
    final bubbleWidth = size.width - tailWidth;
    final paint = Paint()..color = _accentGreen;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, bubbleWidth, size.height),
        const Radius.circular(3),
      ),
      paint,
    );
    // The message row aligns the avatar to the bubble's bottom edge.
    final tailCenter = size.height - 20;
    final tail = Path()
      ..moveTo(bubbleWidth - 1, tailCenter - 6)
      ..lineTo(size.width, tailCenter)
      ..lineTo(bubbleWidth - 1, tailCenter + 6)
      ..close();
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(covariant _MineBubblePainter oldDelegate) => false;
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({
    required this.palette,
    required this.session,
    this.onTap,
    this.onEdit,
  });
  final AcoPalette palette;
  final LiveSession session;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  String? get _scheduledStartLabel {
    final scheduledAt = session.scheduledAt;
    if (session.status != 'scheduled' || scheduledAt == null) return null;
    final localTime = scheduledAt.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '开始时间 ${localTime.month}月${localTime.day}日 $hour:$minute';
  }

  bool get _isLive => session.status == 'live';

  String get _statusLabel {
    switch (session.status) {
      case 'live':
        return '直播中';
      case 'scheduled':
        return '预约中';
      case 'ended':
        return '已结束';
      default:
        return session.status;
    }
  }

  Color get _statusColor => _isLive || session.status == 'scheduled'
      ? palette.accent
      : palette.mutedText;

  Color get _statusBackground => _statusColor.withValues(alpha: 0.14);

  @override
  Widget build(BuildContext context) {
    final scheduledStartLabel = _scheduledStartLabel;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              palette.dark
                  ? 'assets/icons/live_brand_dark.png'
                  : 'assets/icons/live_brand_light.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: AcoTypography.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (session.status.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _statusBackground,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _statusLabel,
                              style: TextStyle(
                                color: _statusColor,
                                fontSize: AcoTypography.caption,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (session.canExportCheckIns) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: palette.accent.withValues(alpha: .16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '我的直播',
                                style: TextStyle(
                                  color: palette.accent,
                                  fontSize: AcoTypography.caption,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          if (scheduledStartLabel != null) ...[
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                scheduledStartLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.primaryText,
                                  fontSize: AcoTypography.caption,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (onEdit != null) ...[
              const SizedBox(width: 6),
              AcoIconButton(
                icon: CupertinoIcons.pencil,
                palette: palette,
                label: '修改直播',
                size: 20,
                onPressed: onEdit!,
              ),
            ],
          ],
        ),
        if (session.coverUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.network(
              _liveCoverUrl(session.coverUrl),
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _LiveCoverPlaceholder(palette: palette),
            ),
          ),
        ],
      ],
    );
    return onTap == null
        ? content
        : CupertinoButton(
            padding: EdgeInsets.zero,
            pressedOpacity: 0.72,
            onPressed: onTap,
            child: content,
          );
  }
}

String _liveCoverUrl(String coverUrl) {
  if (Uri.tryParse(coverUrl)?.hasScheme ?? false) return coverUrl;
  final apiUri = Uri.parse(const AppConfig().apiBaseUrl);
  return apiUri.replace(path: coverUrl).toString();
}

class _LiveCoverPlaceholder extends StatelessWidget {
  const _LiveCoverPlaceholder({required this.palette});

  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: 220,
    color: palette.surfaceRaised,
    alignment: Alignment.center,
    child: Icon(CupertinoIcons.photo, color: palette.mutedText, size: 30),
  );
}

class _LiveCoverThumbnailFallback extends StatelessWidget {
  const _LiveCoverThumbnailFallback({required this.palette});

  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    width: 54,
    height: 52,
    decoration: BoxDecoration(
      color: palette.surfaceRaised,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(CupertinoIcons.photo, color: palette.mutedText, size: 26),
  );
}

class _LiveListMessage extends StatelessWidget {
  const _LiveListMessage({
    required this.palette,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final AcoPalette palette;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 56),
    child: Column(
      children: [
        Icon(CupertinoIcons.video_camera, color: palette.mutedText, size: 32),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.body,
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 16),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            onPressed: onPressed,
            child: Text(actionLabel!),
          ),
        ],
      ],
    ),
  );
}
