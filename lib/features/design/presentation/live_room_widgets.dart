part of 'aco_design_shell.dart';

class _LiveRoomOverview extends StatelessWidget {
  const _LiveRoomOverview({
    required this.palette,
    required this.room,
    required this.isHost,
    required this.hostMuted,
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
                active: speakingParticipantIds.contains(
                  room.host.userId.toString(),
                ),
              ),
            ),
            if (isHost && room.checkIn != null)
              Positioned(
                top: 36,
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
                top: 36,
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
          speakingParticipantIds: speakingParticipantIds,
          onSpeakerTap: onSpeakerTap,
        ),
    ],
  );
}

class _LiveRoomCheckInButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final checked = checkIn.viewerChecked;
    final enabled = !checked && onPressed != null;
    final remaining = checkIn.deadline.difference(DateTime.now());
    final minutes = remaining.inMinutes.clamp(0, 99).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60)
        .clamp(0, 59)
        .toString()
        .padLeft(2, '0');
    if (isHost) {
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
    final background = checked ? palette.surfaceRaised : palette.accent;
    return Semantics(
      button: true,
      enabled: enabled,
      label: checked ? '已签到' : '立即签到',
      onTap: enabled ? onPressed : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(
              color: checked
                  ? palette.mutedText.withValues(alpha: .25)
                  : palette.accent.withValues(alpha: .72),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (checked ? _black : palette.accent).withValues(
                  alpha: .28,
                ),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '签到',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: checked ? palette.mutedText : _white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                shadows: const [
                  Shadow(
                    color: Color(0x99000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RaisedHandRequestsHeader(
              palette: palette,
              count: users.length,
              onClose: onClose,
              onRejectAll: onRejectAll,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
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
        AcoAvatar(size: 32, assetPath: _liveRoomListenerAvatarAsset),
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
    this.onMore,
  });

  final AcoPalette palette;
  final int? count;
  final VoidCallback? onMore;

  String get _countLabel {
    final value = count;
    if (value == null) return '—';
    return '${value < 0 ? 0 : value}';
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: palette.surfaceRaised,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.person_2, size: 14, color: palette.primaryText),
            const SizedBox(width: 3),
            Text(
              _countLabel,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: AcoTypography.caption,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      if (onMore != null)
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(36, 44),
          onPressed: onMore,
          child: Icon(
            CupertinoIcons.ellipsis_vertical,
            color: palette.primaryText,
            size: 20,
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
          color: palette.dark ? const Color(0xE6292929) : palette.surfaceRaised,
          border: Border.all(color: palette.accent.withValues(alpha: .52)),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 5, 9, 5),
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
                  child: Image.asset(
                    'assets/icons/live_hand.png',
                    width: 13,
                    height: 13,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  color: palette.accent,
                  fontSize: AcoTypography.caption,
                  fontWeight: FontWeight.w800,
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
      AcoAvatar(size: 76, assetPath: _liveRoomHostAvatarAsset),
      if (active) const Positioned.fill(child: _SpeakingRing()),
      Positioned(
        right: -3,
        bottom: -3,
        child: Container(
          width: 27,
          height: 27,
          decoration: BoxDecoration(
            color: muted ? _danger : palette.accent,
            shape: BoxShape.circle,
            border: Border.all(color: palette.background, width: 3),
          ),
          child: active
              ? const Center(child: _SpeakingBadge())
              : Image.asset(
                  muted
                      ? 'assets/icons/live_muted.png'
                      : 'assets/icons/live_mic.png',
                  width: 21,
                  height: 21,
                  fit: BoxFit.contain,
                ),
        ),
      ),
    ],
  );
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
    required this.speakingParticipantIds,
    this.onSpeakerTap,
  });

  final AcoPalette palette;
  final List<LiveParticipant> speakers;
  final List<LiveParticipant> listeners;
  final Set<String> speakingParticipantIds;
  final ValueChanged<LiveParticipant>? onSpeakerTap;

  @override
  Widget build(BuildContext context) {
    final activeSpeakers = speakers.where(
      (participant) =>
          speakingParticipantIds.contains(participant.userId.toString()),
    );
    final unmutedSpeakers = speakers.where(
      (participant) =>
          !speakingParticipantIds.contains(participant.userId.toString()) &&
          !participant.muted,
    );
    final mutedSpeakers = speakers.where(
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
      ...listeners.take(10 - visibleSpeakers.length),
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
                  isSpeaking: speakingParticipantIds.contains(
                    participant.userId.toString(),
                  ),
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
    required this.isSpeaking,
    this.onSpeakerTap,
  });

  final AcoPalette palette;
  final LiveParticipant participant;
  final double width;
  final double avatarSize;
  final bool isSpeaking;
  final ValueChanged<LiveParticipant>? onSpeakerTap;

  @override
  Widget build(BuildContext context) {
    final canMuteSpeaker =
        participant.role == 'speaker' && onSpeakerTap != null;
    final avatar = AcoAvatar(
      size: avatarSize,
      assetPath: _liveRoomListenerAvatarAsset,
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
              if (isSpeaking) const Positioned.fill(child: _SpeakingRing()),
              if (isSpeaking)
                const Positioned(right: -2, bottom: -2, child: _SpeakingBadge())
              else if (participant.role != 'speaker' || participant.muted)
                const Positioned(
                  right: -2,
                  bottom: -2,
                  child: _MutedMicrophoneBadge(),
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
    required this.palette,
    required this.reconnecting,
  });

  final AcoPalette palette;
  final bool reconnecting;

  @override
  Widget build(BuildContext context) {
    final statusColor = reconnecting ? _danger : palette.accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              reconnecting ? '重连中' : '网络正常',
              style: TextStyle(
                color: statusColor,
                fontSize: AcoTypography.caption,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveRoomNetworkNotice extends StatelessWidget {
  const _LiveRoomNetworkNotice();

  @override
  Widget build(BuildContext context) => Positioned(
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
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoActivityIndicator(radius: 7, color: _white),
              SizedBox(width: 8),
              Text(
                '网络较弱，正在重连…',
                style: TextStyle(
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

class _MutedMicrophoneBadge extends StatelessWidget {
  const _MutedMicrophoneBadge();

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/icons/live_muted.png',
    width: 21,
    height: 21,
    fit: BoxFit.contain,
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

class _SpeakingRing extends StatelessWidget {
  const _SpeakingRing();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF9BEF00), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x669BEF00), blurRadius: 8, spreadRadius: 1),
        ],
      ),
    ),
  );
}
