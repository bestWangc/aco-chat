part of 'aco_design_shell.dart';

const _socialMockMessages = [
  _SocialMockMessage('克里斯蒂亚诺', '你好，股票账户已就位'),
  _SocialMockMessage('Aco 社区', '你好，股票账户已就位'),
  _SocialMockMessage('Builder', '你好，股票账户已就位'),
  _SocialMockMessage('Satoshi', '你好，股票账户已就位'),
  _SocialMockMessage('链上观察者', '你好，股票账户已就位'),
  _SocialMockMessage('Nova', '你好，股票账户已就位'),
  _SocialMockMessage('产品讨论组', '你好，股票账户已就位'),
  _SocialMockMessage('Crypto Lab', '你好，股票账户已就位'),
  _SocialMockMessage(
    'Alice',
    '这是一条很长的消息内容，用来测试聊天列表在消息较长时是否能够正确省略并保持右侧未读数和日期布局稳定。',
  ),
  _SocialMockMessage('Web3 研究院', '你好，股票账户已就位'),
  _SocialMockMessage('Ming', '你好，股票账户已就位'),
  _SocialMockMessage('DAO 社区', '你好，股票账户已就位'),
  _SocialMockMessage('Block Runner', '你好，股票账户已就位'),
];

class _SocialMockMessage {
  const _SocialMockMessage(this.name, this.message);

  final String name;
  final String message;
}

class _ChatHistoryMessage {
  const _ChatHistoryMessage(this.text, {required this.mine})
    : imageBytes = null;

  const _ChatHistoryMessage.image(this.imageBytes, {required this.mine})
    : text = '';

  final String text;
  final bool mine;
  final Uint8List? imageBytes;
}

class _SocialMessageTile extends StatelessWidget {
  const _SocialMessageTile({
    required this.palette,
    required this.name,
    required this.onTap,
    required this.message,
    this.avatarUrl,
    this.unreadCount = 0,
    this.timestamp,
  });

  final AcoPalette palette;
  final String name;
  final VoidCallback onTap;
  final String message;
  final String? avatarUrl;
  final int unreadCount;
  final int? timestamp;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 0,
    minLeadingWidth: 34,
    horizontalTitleGap: 12,
    leading: AcoAvatar(size: 34, imageUrl: avatarUrl),
    title: Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: palette.primaryText,
        fontSize: AcoTypography.body - 1,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Text(
      message,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFFA2A4A8),
        fontSize: AcoTypography.caption,
      ),
    ),
    trailing: SizedBox(
      width: 82,
      height: 52,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (unreadCount > 0)
            _GreenBadge(
              label: unreadCount > 99 ? '99+' : '$unreadCount',
              color: palette.accent,
              fontSize: AcoTypography.caption - 1,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            ),
          const SizedBox(height: 5),
          Text(
            _formatConversationDate(timestamp),
            style: const TextStyle(
              color: Color(0xFF9D9EA0),
              fontSize: AcoTypography.caption - 2,
            ),
          ),
        ],
      ),
    ),
    onTap: onTap,
  );
}
