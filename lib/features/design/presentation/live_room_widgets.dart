part of 'aco_design_shell.dart';

class _LiveRoomOverview extends StatelessWidget {
  const _LiveRoomOverview({
    required this.palette,
    required this.room,
    required this.isHost,
    required this.hostMuted,
    required this.viewerMuted,
    required this.checkingIn,
    required this.speakingParticipantIds,
    required this.onCheckIn,
    required this.onShowRaisedHandRequests,
    this.onSpeakerTap,
  });

  final AcoPalette palette;
  final LiveRoom room;
  final bool isHost;
  final bool hostMuted;
  final bool viewerMuted;
  final bool checkingIn;
  final Set<String> speakingParticipantIds;
  final VoidCallback onCheckIn;
  final VoidCallback onShowRaisedHandRequests;
  final ValueChanged<LiveParticipant>? onSpeakerTap;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: _LiveRoomHostCard(
                palette: palette,
                host: room.host,
                muted: hostMuted,
                // LiveKit active-speaker events can arrive after the mute
                // snapshot. Never show the speaking animation for a muted
                // host, even while that stale event is still present.
                active:
                    !hostMuted &&
                    speakingParticipantIds.contains(
                      room.host.userId.toString(),
                    ),
              ),
            ),
            if (isHost && room.checkIn != null)
              Positioned(
                top: 24,
                left: 12,
                child: _LiveRoomCheckInButton(
                  palette: palette,
                  checkIn: room.checkIn!,
                  isHost: true,
                  onPressed: null,
                ),
              ),
            if (!isHost &&
                room.checkIn != null &&
                !checkingIn &&
                !room.checkIn!.viewerChecked)
              Positioned(
                top: 24,
                right: 14,
                child: _LiveRoomCheckInButton(
                  palette: palette,
                  checkIn: room.checkIn!,
                  isHost: false,
                  onPressed: onCheckIn,
                ),
              ),
            if (isHost && (room.raisedHandCount ?? 0) > 0)
              Positioned(
                top: 36,
                right: 14,
                child: _RaisedHandIndicator(
                  palette: palette,
                  count: room.raisedHandCount!,
                  onPressed: onShowRaisedHandRequests,
                ),
              ),
          ],
        ),
      ),
      if (room.speakers.isNotEmpty || room.listeners.isNotEmpty)
        _LiveRoomParticipantSection(
          palette: palette,
          speakers: room.speakers,
          listeners: room.listeners,
          viewerUserId: room.viewerUserId,
          viewerMuted: viewerMuted,
          speakingParticipantIds: speakingParticipantIds,
          onSpeakerTap: onSpeakerTap,
        ),
    ],
  );
}

class _LiveRoomCheckInButton extends StatefulWidget {
  const _LiveRoomCheckInButton({
    required this.palette,
    required this.checkIn,
    required this.isHost,
    required this.onPressed,
  });

  final AcoPalette palette;
  final LiveCheckIn checkIn;
  final bool isHost;
  final VoidCallback? onPressed;

  @override
  State<_LiveRoomCheckInButton> createState() => _LiveRoomCheckInButtonState();
}

class _LiveRoomCheckInButtonState extends State<_LiveRoomCheckInButton> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(_LiveRoomCheckInButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checkIn.deadline != widget.checkIn.deadline) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final checkIn = widget.checkIn;
    final checked = checkIn.viewerChecked;
    final enabled = !checked && widget.onPressed != null;
    final remaining = checkIn.deadline.difference(DateTime.now());
    final minutes = remaining.inMinutes.clamp(0, 99).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60)
        .clamp(0, 59)
        .toString()
        .padLeft(2, '0');
    if (widget.isHost) {
      return Semantics(
        label: '签到进行中，已签到 ${checkIn.checkedInCount} 人，剩余 $minutes:$seconds',
        child: Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                palette.accent.withValues(alpha: .22),
                palette.accent.withValues(alpha: .08),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: palette.accent.withValues(alpha: .68)),
            boxShadow: [
              BoxShadow(
                color: palette.accent.withValues(alpha: .16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '签到中',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${checkIn.checkedInCount} 人',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.primaryText.withValues(alpha: .82),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '$minutes:$seconds',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: checked ? '已签到' : '立即签到',
      onTap: enabled ? widget.onPressed : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? widget.onPressed : null,
        child: SizedBox.square(
          dimension: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!checked)
                Positioned.fill(
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/check_in_button.png',
                      fit: BoxFit.cover,
                      semanticLabel: '签到按钮',
                    ),
                  ),
                ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  checked ? '已签到' : '签到',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: checked ? palette.mutedText : _black,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaisedHandRequests extends StatelessWidget {
  const _RaisedHandRequests({
    required this.palette,
    required this.users,
    required this.onClose,
    required this.onApprove,
    required this.onReject,
    required this.onRejectAll,
    this.maxHeight = 248,
  });

  final AcoPalette palette;
  final List<LiveParticipant> users;
  final VoidCallback onClose;
  final ValueChanged<int> onApprove;
  final ValueChanged<int> onReject;
  final VoidCallback onRejectAll;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();
    final listMaxHeight = math.min(maxHeight, users.length * 57.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF21F1F1F),
        border: Border.all(color: _white.withValues(alpha: .12)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RaisedHandRequestsHeader(
              palette: palette,
              count: users.length,
              onClose: onClose,
              onRejectAll: onRejectAll,
            ),
            const SizedBox(height: 2),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: listMaxHeight),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: users.length,
                separatorBuilder: (_, _) =>
                    Container(height: 1, color: _white.withValues(alpha: .08)),
                itemBuilder: (_, index) => _RaisedHandRequestChip(
                  palette: palette,
                  user: users[index],
                  onApprove: onApprove,
                  onReject: onReject,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaisedHandRequestsHeader extends StatelessWidget {
  const _RaisedHandRequestsHeader({
    required this.palette,
    required this.count,
    required this.onClose,
    required this.onRejectAll,
  });

  final AcoPalette palette;
  final int count;
  final VoidCallback onClose;
  final VoidCallback onRejectAll;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: palette.accent,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          CupertinoIcons.hand_raised_fill,
          color: _black,
          size: 15,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          '申请发言',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodySmall,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Container(
        constraints: const BoxConstraints(minWidth: 24),
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            color: palette.accent,
            fontSize: AcoTypography.caption,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      CupertinoButton(
        padding: const EdgeInsets.only(left: 8),
        minimumSize: const Size(30, 28),
        onPressed: onRejectAll,
        child: Text(
          '全部拒绝',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.caption,
          ),
        ),
      ),
      CupertinoButton(
        padding: const EdgeInsets.only(left: 8),
        minimumSize: const Size(28, 28),
        onPressed: onClose,
        child: Icon(CupertinoIcons.xmark, color: palette.mutedText, size: 18),
      ),
    ],
  );
}

class _RaisedHandRequestChip extends StatelessWidget {
  const _RaisedHandRequestChip({
    required this.palette,
    required this.user,
    required this.onApprove,
    required this.onReject,
  });

  final AcoPalette palette;
  final LiveParticipant user;
  final ValueChanged<int> onApprove;
  final ValueChanged<int> onReject;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Row(
      children: [
        AcoAvatar(
          size: 32,
          assetPath: _liveRoomListenerAvatarAsset,
          imageUrl: user.avatarUrl,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            user.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.bodySmall,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
        _RaisedHandAction(
          icon: CupertinoIcons.checkmark,
          label: '允许',
          color: palette.accent,
          onPressed: () => onApprove(user.userId),
        ),
        const SizedBox(width: 4),
        _RaisedHandAction(
          icon: CupertinoIcons.xmark,
          label: '拒绝',
          color: palette.mutedText,
          onPressed: () => onReject(user.userId),
        ),
      ],
    ),
  );
}

class _LiveRoomHeaderActions extends StatelessWidget {
  const _LiveRoomHeaderActions({
    required this.palette,
    required this.count,
    required this.onMembers,
    this.onMore,
  });

  final AcoPalette palette;
  final int? count;
  final VoidCallback onMembers;
  final VoidCallback? onMore;

  // Provided livestream viewer-count glyph.
  static final _viewerCountIcon = base64Decode(
    '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',
  );

  String get _countLabel {
    final value = count;
    if (value == null) return '—';
    return '${value < 0 ? 0 : value}';
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(62, 36),
        onPressed: onMembers,
        child: Container(
          constraints: const BoxConstraints(minHeight: 26),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: palette.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icons/live_viewers_custom.png',
                width: 14,
                height: 12,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => Image.memory(
                  _viewerCountIcon,
                  width: 14,
                  height: 12,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                _countLabel,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
      if (onMore != null)
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(36, 44),
          onPressed: onMore,
          child: Image.asset(
            'assets/icons/live_more.png',
            width: 12,
            height: 28,
            fit: BoxFit.contain,
          ),
        ),
    ],
  );
}

class _RaisedHandIndicator extends StatelessWidget {
  const _RaisedHandIndicator({
    required this.palette,
    required this.count,
    required this.onPressed,
  });

  final AcoPalette palette;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$count 人申请发言',
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(3, 3, 7, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF111111),
                      BlendMode.srcIn,
                    ),
                    child: Image.asset(
                      'assets/icons/live_hand.png',
                      width: 13,
                      height: 13,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LiveRoomHostCard extends StatelessWidget {
  const _LiveRoomHostCard({
    required this.palette,
    required this.host,
    required this.muted,
    required this.active,
  });

  final AcoPalette palette;
  final LiveParticipant host;
  final bool muted;
  final bool active;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 12),
    child: Column(
      children: [
        _buildHostAvatar(),
        const SizedBox(height: 14),
        Text(
          host.nickname,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '主持人',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.caption,
          ),
        ),
      ],
    ),
  );

  Widget _buildHostAvatar() => Stack(
    clipBehavior: Clip.none,
    children: [
      AcoAvatar(
        size: 76,
        assetPath: _liveRoomHostAvatarAsset,
        imageUrl: host.avatarUrl,
      ),
      Positioned(
        right: -3,
        bottom: -3,
        child: Container(
          width: 27,
          height: 27,
          decoration: BoxDecoration(
            color: muted ? palette.surfaceRaised : palette.accent,
            shape: BoxShape.circle,
            border: Border.all(color: palette.background, width: 3),
          ),
          child: _buildStatusBadge(),
        ),
      ),
    ],
  );

  Widget _buildStatusBadge() {
    if (active) return const Center(child: _SpeakingBadge());
    if (muted) {
      return _MutedMicrophoneBadge(background: palette.surfaceRaised);
    }
    return Image.asset(
      'assets/icons/live_mic.png',
      width: 21,
      height: 21,
      fit: BoxFit.contain,
    );
  }
}

class _LiveRoomInfoNotice extends StatelessWidget {
  const _LiveRoomInfoNotice();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xE6000000),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        '已举手，请等待主持人批准',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _white,
          fontSize: AcoTypography.bodySmall,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _RaisedHandAction extends StatelessWidget {
  const _RaisedHandAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size(30, 30),
    onPressed: onPressed,
    child: Semantics(
      button: true,
      label: label,
      child: Icon(icon, color: color, size: 17),
    ),
  );
}

class _LiveRoomParticipantSection extends StatelessWidget {
  const _LiveRoomParticipantSection({
    required this.palette,
    required this.speakers,
    required this.listeners,
    required this.viewerUserId,
    required this.viewerMuted,
    required this.speakingParticipantIds,
    this.onSpeakerTap,
  });

  final AcoPalette palette;
  final List<LiveParticipant> speakers;
  final List<LiveParticipant> listeners;
  final int viewerUserId;
  final bool viewerMuted;
  final Set<String> speakingParticipantIds;
  final ValueChanged<LiveParticipant>? onSpeakerTap;

  LiveParticipant _withViewerMute(LiveParticipant participant) {
    if (participant.userId != viewerUserId) return participant;
    return LiveParticipant(
      userId: participant.userId,
      nickname: participant.nickname,
      username: participant.username,
      avatarUrl: participant.avatarUrl,
      role: participant.role,
      handRaised: participant.handRaised,
      muted: viewerMuted,
      speakerInvited: participant.speakerInvited,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSpeakers = speakers
        .map(_withViewerMute)
        .toList(growable: false);
    final effectiveListeners = listeners
        .map(_withViewerMute)
        .toList(growable: false);
    final activeSpeakers = effectiveSpeakers.where(
      (participant) =>
          !participant.muted &&
          speakingParticipantIds.contains(participant.userId.toString()),
    );
    final unmutedSpeakers = effectiveSpeakers.where(
      (participant) =>
          !speakingParticipantIds.contains(participant.userId.toString()) &&
          !participant.muted,
    );
    final mutedSpeakers = effectiveSpeakers.where(
      (participant) =>
          !speakingParticipantIds.contains(participant.userId.toString()) &&
          participant.muted,
    );
    // Keep people who are actively speaking visible even when the room has
    // more speakers than the ten available audience-grid slots.
    final visibleSpeakers = [
      ...activeSpeakers,
      ...unmutedSpeakers,
      ...mutedSpeakers,
    ].take(10).toList(growable: false);
    final participants = [
      ...visibleSpeakers,
      ...effectiveListeners.take(10 - visibleSpeakers.length),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useFiveColumns = constraints.maxWidth >= 300;
          final columns = useFiveColumns ? 5 : 4;
          const spacing = 8.0;
          final cardWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          final avatarSize = useFiveColumns ? 48.0 : 54.0;
          return Wrap(
            alignment: WrapAlignment.start,
            spacing: spacing,
            runSpacing: 14,
            children: [
              for (final participant in participants)
                _LiveRoomParticipantCard(
                  palette: palette,
                  participant: participant,
                  width: cardWidth,
                  avatarSize: avatarSize,
                  speakingParticipantIds: speakingParticipantIds,
                  onSpeakerTap: onSpeakerTap,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LiveRoomParticipantCard extends StatelessWidget {
  const _LiveRoomParticipantCard({
    required this.palette,
    required this.participant,
    required this.width,
    required this.avatarSize,
    required this.speakingParticipantIds,
    this.onSpeakerTap,
  });

  final AcoPalette palette;
  final LiveParticipant participant;
  final double width;
  final double avatarSize;
  final Set<String> speakingParticipantIds;
  final ValueChanged<LiveParticipant>? onSpeakerTap;

  @override
  Widget build(BuildContext context) {
    final isSpeaking =
        !participant.muted &&
        speakingParticipantIds.contains(participant.userId.toString());
    final canMuteSpeaker =
        participant.role == 'speaker' && onSpeakerTap != null;
    final avatar = AcoAvatar(
      size: avatarSize,
      assetPath: _liveRoomListenerAvatarAsset,
      imageUrl: participant.avatarUrl,
    );
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              canMuteSpeaker
                  ? CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () => onSpeakerTap!(participant),
                      child: avatar,
                    )
                  : avatar,
              if (isSpeaking)
                const Positioned(right: -2, bottom: -2, child: _SpeakingBadge())
              else if (participant.role != 'speaker' || participant.muted)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: _MutedMicrophoneBadge(
                    background: palette.surfaceRaised,
                  ),
                )
              else
                const Positioned(
                  right: -2,
                  bottom: -2,
                  child: _LiveMicrophoneBadge(),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            participant.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.bodySmall,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            participant.role == 'speaker'
                ? (participant.muted ? '静音' : '发言中')
                : '听众',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveRoomNetworkStatusChip extends StatelessWidget {
  const _LiveRoomNetworkStatusChip({
    required this.wsReconnecting,
    required this.liveKitConnecting,
    required this.liveKitConnected,
    required this.liveKitReconnecting,
    required this.liveKitReconnectStopped,
  });

  final bool wsReconnecting;
  final bool liveKitConnecting;
  final bool liveKitConnected;
  final bool liveKitReconnecting;
  final bool liveKitReconnectStopped;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showStatusDetails(context),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusIcon(
              label: '实时消息连接',
              reconnecting: wsReconnecting,
              disconnected: false,
            ),
            const SizedBox(width: 10),
            _buildStatusIcon(
              label: '语音连接',
              reconnecting: liveKitConnecting || liveKitReconnecting,
              disconnected: liveKitReconnectStopped || !liveKitConnected,
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusDetails(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('连接状态'),
        message: Text(
          '实时消息：${_statusText(wsReconnecting, false)}\n'
          '语音：${_statusText(liveKitConnecting || liveKitReconnecting, liveKitReconnectStopped || !liveKitConnected)}',
        ),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text(
            '关闭',
            style: TextStyle(fontSize: AcoTypography.bodySmall),
          ),
        ),
      ),
    );
  }

  String _statusText(bool reconnecting, bool disconnected) {
    if (reconnecting) return '连接中';
    if (disconnected) return '已断开';
    return '正常';
  }

  Widget _buildStatusIcon({
    required String label,
    required bool reconnecting,
    required bool disconnected,
  }) {
    Color color;
    String status;
    if (reconnecting) {
      color = CupertinoColors.systemOrange;
      status = '连接中';
    } else if (disconnected) {
      color = _danger;
      status = '已断开';
    } else {
      color = const Color(0xFF9BEF00);
      status = '正常';
    }
    return Semantics(
      label: '$label：$status',
      child: _SignalStrengthIcon(color: color),
    );
  }
}

class _SignalStrengthIcon extends StatelessWidget {
  const _SignalStrengthIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 14,
    height: 14,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [_bar(4), _bar(7), _bar(10), _bar(13)],
    ),
  );

  Widget _bar(double height) => Container(
    width: 2,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(1),
    ),
  );
}

class _LiveRoomNetworkNotice extends StatelessWidget {
  const _LiveRoomNetworkNotice({
    required this.wsReconnecting,
    required this.liveKitConnecting,
    required this.liveKitReconnecting,
  });

  final bool wsReconnecting;
  final bool liveKitConnecting;
  final bool liveKitReconnecting;

  @override
  Widget build(BuildContext context) {
    final String message;
    if (wsReconnecting && (liveKitConnecting || liveKitReconnecting)) {
      message = '实时消息和语音连接中…';
    } else if (wsReconnecting) {
      message = '实时消息连接中…';
    } else {
      message = '语音连接中…';
    }
    return Positioned(
      top: 48,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE61D1D1D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _white.withValues(alpha: .12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CupertinoActivityIndicator(radius: 7, color: _white),
                const SizedBox(width: 8),
                Text(
                  message,
                  style: const TextStyle(
                    color: _white,
                    fontSize: AcoTypography.bodySmall,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MutedMicrophoneBadge extends StatelessWidget {
  const _MutedMicrophoneBadge({required this.background});

  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: 21,
    height: 21,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: ColorFiltered(
      colorFilter: const ColorFilter.mode(Color(0xFFFF3347), BlendMode.srcIn),
      child: Image.asset(
        'assets/icons/live_muted_red.png',
        width: 17,
        height: 21,
        fit: BoxFit.contain,
      ),
    ),
  );
}

class _SpeakingBadge extends StatefulWidget {
  const _SpeakingBadge();

  @override
  State<_SpeakingBadge> createState() => _SpeakingBadgeState();
}

class _SpeakingBadgeState extends State<_SpeakingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 680),
    lowerBound: .72,
    upperBound: 1.12,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => Opacity(
      opacity: .58 + (_controller.value - .72) / .4 * .42,
      child: Transform.scale(scale: _controller.value, child: child),
    ),
    child: const _LiveMicrophoneBadge(),
  );
}

class _LiveMicrophoneBadge extends StatelessWidget {
  const _LiveMicrophoneBadge();

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/icons/live_speaking.png',
    width: 21,
    height: 21,
    fit: BoxFit.contain,
  );
}

class _MemberRoleBadge extends StatelessWidget {
  const _MemberRoleBadge({required this.label, this.isHost = false});

  final String label;
  final bool isHost;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: isHost ? const Color(0x269BEF00) : const Color(0x14000000),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(
        color: isHost ? const Color(0x669BEF00) : const Color(0x26000000),
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: isHost ? const Color(0xFF6E9900) : const Color(0xFF555555),
        fontSize: 11,
        height: 1.1,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

enum _LiveMemberAction { toggleMute, removeSpeaker, transferHost, kick }

class _LiveRoomMembersSheet extends StatefulWidget {
  const _LiveRoomMembersSheet({
    required this.palette,
    required this.initialTotal,
    required this.isModerator,
    required this.currentUserId,
    required this.loadPage,
    this.onMemberTap,
    this.audioMuted = false,
    this.onToggleAudioMute,
    this.chatMuted = false,
    this.onToggleChatMute,
  });

  final AcoPalette palette;
  final int initialTotal;
  final bool isModerator;
  final int currentUserId;
  final Future<LiveMembersPage> Function(int page, String keyword) loadPage;
  final Future<void> Function(LiveParticipant member)? onMemberTap;
  final bool audioMuted;
  final Future<void> Function(bool muted)? onToggleAudioMute;
  final bool chatMuted;
  final Future<void> Function(bool muted)? onToggleChatMute;

  @override
  State<_LiveRoomMembersSheet> createState() => _LiveRoomMembersSheetState();
}

class _LiveRoomMembersSheetState extends State<_LiveRoomMembersSheet> {
  final _searchController = TextEditingController();
  final _membersScrollController = ScrollController();
  final _members = <LiveParticipant>[];
  // Start idle so the initial request in initState is not blocked by the
  // duplicate-load guard.
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _page = 0;
  int _total = 0;
  bool _hasMore = false;
  late bool _audioMuted = widget.audioMuted;
  late bool _chatMuted = widget.chatMuted;

  @override
  void initState() {
    super.initState();
    _total = widget.initialTotal;
    _membersScrollController.addListener(_onMembersScroll);
    _load(reset: true);
  }

  void _onMembersScroll() {
    if (!_membersScrollController.hasClients ||
        _loading ||
        _loadingMore ||
        !_hasMore) {
      return;
    }
    if (_membersScrollController.position.extentAfter < 120) {
      _load(reset: false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _membersScrollController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if ((!reset && (_loading || _loadingMore || !_hasMore)) ||
        (reset && _loading)) {
      return;
    }
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final result = await widget.loadPage(
        reset ? 1 : _page + 1,
        _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _members.clear();
        final existingIds = _members.map((member) => member.userId).toSet();
        for (final member in result.members) {
          if (existingIds.add(member.userId)) {
            _members.add(member);
          }
        }
        _page = result.page;
        if (result.total != null) _total = result.total!;
        _hasMore = result.hasMore;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '成员列表加载失败，请重试。');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Widget _buildMemberSubtitle(LiveParticipant member) {
    final badges = <Widget>[];
    if (member.role == 'host') {
      badges.add(const _MemberRoleBadge(label: '主持人', isHost: true));
    }
    if (member.userId == widget.currentUserId) {
      badges.add(const _MemberRoleBadge(label: '我'));
    }
    if (badges.isNotEmpty) {
      return Wrap(spacing: 4, runSpacing: 2, children: badges);
    }
    return Text(
      member.username.isEmpty ? member.nickname : member.username,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Color(0xFF6F6F6F), fontSize: 13),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.sizeOf(context).height * .78,
    decoration: BoxDecoration(
      color: CupertinoColors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: SafeArea(
      top: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismissKeyboard,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 6),
              child: Row(
                children: [
                  const SizedBox(width: 44),
                  Expanded(
                    child: Center(
                      child: Text(
                        '管理成员 ($_total)',
                        style: TextStyle(
                          color: const Color(0xFF151515),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(10),
                    minimumSize: const Size(44, 44),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Icon(
                      CupertinoIcons.xmark,
                      color: const Color(0xFF151515),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: CupertinoTextField(
                controller: _searchController,
                placeholder: '搜索成员',
                style: const TextStyle(color: Color(0xFF151515), fontSize: 14),
                placeholderStyle: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 14,
                ),
                cursorColor: const Color(0xFF151515),
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    CupertinoIcons.search,
                    color: const Color(0xFF777777),
                    size: 22,
                  ),
                ),
                suffix: _searchController.text.isEmpty
                    ? null
                    : CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: Size.zero,
                        onPressed: () {
                          _searchController.clear();
                          _load(reset: true);
                        },
                        child: const Icon(
                          CupertinoIcons.clear_circled_solid,
                          size: 20,
                        ),
                      ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _load(reset: true),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x26000000)),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
            if (widget.isModerator &&
                widget.onToggleAudioMute != null &&
                widget.onToggleChatMute != null)
              _buildMuteActions(),
          ],
        ),
      ),
    ),
  );

  Widget _buildMuteActions() => Container(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
    decoration: const BoxDecoration(
      color: CupertinoColors.white,
      border: Border(top: BorderSide(color: Color(0x14000000))),
    ),
    child: SafeArea(
      top: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMuteButton(
            label: _audioMuted ? '解除全体静音' : '全体静音',
            currentMuted: _audioMuted,
            targetMuted: !_audioMuted,
            onToggle: widget.onToggleAudioMute!,
            onChanged: (muted) => _audioMuted = muted,
          ),
          const SizedBox(width: 24),
          _buildMuteButton(
            label: _chatMuted ? '解除全员禁言' : '全员禁言',
            currentMuted: _chatMuted,
            targetMuted: !_chatMuted,
            onToggle: widget.onToggleChatMute!,
            onChanged: (muted) => _chatMuted = muted,
          ),
        ],
      ),
    ),
  );

  Widget _buildMuteButton({
    required String label,
    required bool currentMuted,
    required bool targetMuted,
    required Future<void> Function(bool muted) onToggle,
    required void Function(bool muted) onChanged,
  }) => SizedBox(
    width: 110,
    height: 34,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      borderRadius: BorderRadius.circular(6),
      color: const Color(0xFF202020),
      onPressed: () async {
        if (currentMuted == targetMuted) return;
        try {
          await onToggle(targetMuted);
          if (mounted) setState(() => onChanged(targetMuted));
        } catch (_) {
          // The parent reports request failures to the user.
        }
      },
      child: Text(
        label,
        style: TextStyle(
          color: CupertinoColors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );

  Widget _buildMemberAudioIcon(LiveParticipant member) {
    final isSpeaker = member.role == 'host' || member.role == 'speaker';
    final showMuted = member.role == 'listener' || (isSpeaker && member.muted);
    if (showMuted) {
      return Image.asset(
        'assets/icons/live_muted_red.png',
        width: 18,
        height: 23,
        fit: BoxFit.contain,
      );
    }
    if (isSpeaker) {
      return Image.asset(
        'assets/icons/live_mic_open.png',
        width: 18,
        height: 23,
        fit: BoxFit.contain,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CupertinoActivityIndicator(color: Color(0xFF666666)),
      );
    }
    if (_error != null && _members.isEmpty) {
      return Center(
        child: CupertinoButton(
          onPressed: () => _load(reset: true),
          child: Text(_error!),
        ),
      );
    }
    if (_members.isEmpty) {
      return Center(
        child: Text('没有找到成员', style: const TextStyle(color: Color(0xFF6F6F6F))),
      );
    }
    return ListView.builder(
      controller: _membersScrollController,
      padding: EdgeInsets.zero,
      itemCount: _members.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _members.length) {
          return const SizedBox(
            height: 36,
            child: Center(
              child: CupertinoActivityIndicator(color: Color(0xFF666666)),
            ),
          );
        }
        final member = _members[index];
        final canManage =
            widget.isModerator &&
            member.userId != widget.currentUserId &&
            member.role != 'host';
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 7),
              onPressed: canManage && widget.onMemberTap != null
                  ? () async {
                      await widget.onMemberTap!(member);
                      if (mounted) _load(reset: true);
                    }
                  : null,
              child: Row(
                children: [
                  AcoAvatar(size: 32, imageUrl: member.avatarUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF151515),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        _buildMemberSubtitle(member),
                      ],
                    ),
                  ),
                  _buildMemberAudioIcon(member),
                  if (canManage)
                    Icon(
                      CupertinoIcons.ellipsis_circle,
                      color: const Color(0xFF777777),
                      size: 23,
                    ),
                ],
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 28),
              color: const Color(0x14000000),
            ),
          ],
        );
      },
    );
  }
}
