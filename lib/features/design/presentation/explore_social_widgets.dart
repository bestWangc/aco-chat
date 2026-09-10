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
  const _ChatHistoryMessage(
    this.text, {
    required this.mine,
    this.clientMsgID,
    this.timestamp,
    this.isVoiceCallRecord = false,
    this.sendFailed = false,
  }) : imageBytes = null,
       imagePath = null,
       imageUrl = null,
       previewImageUrl = null,
       shouldCacheThumbnail = false,
       soundPath = null,
       soundUrl = null,
       soundDuration = null;

  const _ChatHistoryMessage.image({
    required this.mine,
    this.clientMsgID,
    this.timestamp,
    this.imageBytes,
    this.imagePath,
    this.imageUrl,
    this.previewImageUrl,
    this.shouldCacheThumbnail = false,
    this.sendFailed = false,
  }) : text = '',
       soundPath = null,
       soundUrl = null,
       soundDuration = null,
       isVoiceCallRecord = false;

  const _ChatHistoryMessage.sound({
    required this.mine,
    this.clientMsgID,
    this.timestamp,
    this.soundPath,
    this.soundUrl,
    this.soundDuration,
    this.sendFailed = false,
  }) : text = '',
       imageBytes = null,
       imagePath = null,
       imageUrl = null,
       previewImageUrl = null,
       shouldCacheThumbnail = false,
       isVoiceCallRecord = false;

  static bool isDisplayable(Message message) =>
      OpenIMChatRepository.messageText(message) != null ||
      message.pictureElem != null ||
      message.soundElem != null ||
      _voiceCallRecordTextFromMessage(message) != null;

  static String? imageUrlOf(PictureElem? picture) =>
      picture?.snapshotPicture?.url ??
      picture?.bigPicture?.url ??
      picture?.sourcePicture?.url;

  static String? previewImageUrlOf(PictureElem? picture) =>
      picture?.sourcePicture?.url ?? picture?.bigPicture?.url;

  factory _ChatHistoryMessage.fromOpenIM(
    Message message, {
    required bool mine,
  }) {
    final callRecord = _voiceCallRecordTextFromMessage(message);
    if (callRecord != null) {
      return _ChatHistoryMessage(
        callRecord,
        mine: mine,
        clientMsgID: message.clientMsgID,
        timestamp: message.sendTime ?? message.createTime,
        isVoiceCallRecord: true,
      );
    }
    final text = OpenIMChatRepository.messageText(message);
    if (text != null) {
      return _ChatHistoryMessage(
        text,
        mine: mine,
        clientMsgID: message.clientMsgID,
        timestamp: message.sendTime ?? message.createTime,
      );
    }
    final sound = message.soundElem;
    if (sound != null) {
      return _ChatHistoryMessage.sound(
        mine: mine,
        clientMsgID: message.clientMsgID,
        timestamp: message.sendTime ?? message.createTime,
        soundPath: sound.soundPath,
        soundUrl: sound.sourceUrl,
        soundDuration: sound.duration,
      );
    }
    final picture = message.pictureElem;
    final thumbnailUrl = picture?.snapshotPicture?.url;
    return _ChatHistoryMessage.image(
      mine: mine,
      clientMsgID: message.clientMsgID,
      timestamp: message.sendTime ?? message.createTime,
      imagePath: picture?.sourcePath,
      imageUrl: imageUrlOf(picture),
      previewImageUrl: previewImageUrlOf(picture),
      shouldCacheThumbnail: thumbnailUrl?.isNotEmpty == true,
    );
  }

  final String text;
  final String? clientMsgID;
  final int? timestamp;
  final bool mine;
  final Uint8List? imageBytes;
  final String? imagePath;
  final String? imageUrl;
  final String? previewImageUrl;
  final bool shouldCacheThumbnail;
  final String? soundPath;
  final String? soundUrl;
  final int? soundDuration;
  final bool isVoiceCallRecord;
  final bool sendFailed;
}

class _SocialMessageTile extends StatelessWidget {
  const _SocialMessageTile({
    required this.palette,
    required this.name,
    required this.onTap,
    required this.message,
    this.identity = 0,
    this.staffIdentity = 0,
    this.horizontalMargin = 0,
    this.avatarUrl,
    this.groupAvatarUrls,
    this.unreadCount = 0,
    this.timestamp,
  });

  final AcoPalette palette;
  final String name;
  final VoidCallback onTap;
  final String message;
  final int identity;
  final int staffIdentity;
  final double horizontalMargin;
  final String? avatarUrl;
  final List<String>? groupAvatarUrls;
  final int unreadCount;
  final int? timestamp;

  @override
  Widget build(BuildContext context) {
    final badgeAsset = _identityBadgeAsset(identity);
    final staffBadgeAsset = _staffLongBadgeAsset(staffIdentity);
    return Container(
      margin: EdgeInsets.only(left: horizontalMargin),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(right: horizontalMargin),
            child: Theme(
              data: Theme.of(context).copyWith(
                splashColor: const Color(0x00000000),
                highlightColor: const Color(0x00000000),
                hoverColor: const Color(0x00000000),
              ),
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                minVerticalPadding: 0,
                minLeadingWidth: 40,
                horizontalTitleGap: 12,
                leading: groupAvatarUrls == null
                    ? AcoAvatar(size: 40, imageUrl: avatarUrl)
                    : _GroupConversationAvatar(
                        imageUrls: groupAvatarUrls!,
                        fallbackAvatarUrl: avatarUrl,
                      ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: AcoTypography.body - 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (badgeAsset != null) ...[
                      const SizedBox(width: 5),
                      Image.asset(
                        badgeAsset,
                        width: _longBadgeWidth(identity),
                        fit: BoxFit.contain,
                      ),
                    ],
                    if (staffBadgeAsset != null) ...[
                      const SizedBox(width: 4),
                      Image.asset(
                        staffBadgeAsset,
                        width: _longBadgeWidth(staffIdentity),
                        fit: BoxFit.contain,
                      ),
                    ],
                  ],
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
                  height: 44,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatConversationDate(timestamp),
                        style: const TextStyle(
                          color: Color(0xFF9D9EA0),
                          fontSize: AcoTypography.caption - 2,
                        ),
                      ),
                      if (unreadCount > 0) const SizedBox(height: 4),
                      if (unreadCount > 0)
                        _GreenBadge(
                          label: unreadCount > 99 ? '99+' : '$unreadCount',
                          color: palette.accent,
                          fontSize: AcoTypography.caption - 1,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                        ),
                    ],
                  ),
                ),
                onTap: onTap,
              ),
            ),
          ),
          Positioned(
            left: 52,
            right: 0,
            bottom: 0,
            height: 1,
            child: ColoredBox(color: Color(0xFF323232)),
          ),
        ],
      ),
    );
  }
}

class _GroupConversationAvatar extends StatelessWidget {
  const _GroupConversationAvatar({
    required this.imageUrls,
    required this.fallbackAvatarUrl,
  });

  final List<String> imageUrls;
  final String? fallbackAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final avatars = imageUrls.isEmpty
        ? <String?>[fallbackAvatarUrl]
        : imageUrls.take(4).cast<String?>().toList(growable: false);
    return ClipOval(
      child: Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(color: Color(0xFF3A3A3A)),
        child: avatars.length == 1
            ? _GroupAvatarCell(imageUrl: avatars.single)
            : GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: avatars.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemBuilder: (_, index) =>
                    _GroupAvatarCell(imageUrl: avatars[index]),
              ),
      ),
    );
  }
}

class _GroupAvatarCell extends StatelessWidget {
  const _GroupAvatarCell({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final parsed = imageUrl == null || imageUrl!.isEmpty
        ? null
        : Uri.tryParse(imageUrl!);
    String? url;
    if (parsed?.hasScheme == true) {
      url = imageUrl;
    } else if (parsed != null) {
      url = Uri.parse(
        const AppConfig().apiBaseUrl,
      ).replace(path: parsed.path).toString();
    }
    final fallback = Image.asset(_defaultAvatarAsset, fit: BoxFit.cover);
    final image = url == null
        ? fallback
        : Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
    return ClipOval(child: image);
  }
}
