part of 'aco_app_shell.dart';

// This extension renders the State-owned room UI and therefore legitimately
// uses State.setState while preserving the original lifecycle owner.
// ignore_for_file: invalid_use_of_protected_member

extension _VoiceRoomUi on _VoiceRoomPageState {
  void _recordRoomCheckInState(LiveRoom? room, bool isHost) {
    if (_emojiPickerVisible) {
      _recordCheckInButtonState(
        room,
        isHost: isHost,
        hiddenReason: 'emoji_picker_open',
      );
      return;
    }
    _recordCheckInButtonState(room, isHost: isHost);
  }

  double _meetingSidebarWidth(double maxWidth) =>
      (maxWidth * .15).clamp(58.0, 68.0).toDouble();

  Widget _buildMeetingParticipantsSidebar({
    required AcoPalette palette,
    required LiveRoom? room,
    required bool isHost,
    required BoxConstraints constraints,
  }) {
    final panelWidth = _meetingSidebarWidth(constraints.maxWidth);
    final panelHeight = math.min(420.0, constraints.maxHeight * .62);
    final participants = room == null
        ? const <LiveParticipant>[]
        : <LiveParticipant>[room.host, ...room.speakers, ...room.listeners];
    final seenUserIds = <int>{};
    final uniqueParticipants = participants
        .where((participant) => seenUserIds.add(participant.userId))
        .toList(growable: false);
    final showHandControl =
        room != null && !_canManageLiveMicrophones(room.viewerRole);
    final canRaiseHand = room?.canRaiseHand == true;
    final collapsedPanelHeight = showHandControl ? 194.0 : 146.0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      top: 12,
      right: 8,
      width: panelWidth,
      height: _shareMembersExpanded ? panelHeight : collapsedPanelHeight,
      child: Container(
        decoration: BoxDecoration(
          color: _black.withValues(alpha: _shareMembersExpanded ? .34 : .22),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _white.withValues(alpha: .10)),
        ),
        child: Column(
          children: [
            if (showHandControl)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _RoomControl(
                  iconAsset: 'assets/icons/live_hand.png',
                  label: _handRaised ? '已举手' : '举手',
                  background: palette.surfaceRaised,
                  foreground: palette.primaryText,
                  onPressed: canRaiseHand && !_handRaised ? _raiseHand : null,
                  large: false,
                  iconSize: 20,
                  subtle: true,
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _shareMembersExpanded
                    ? uniqueParticipants.length
                    : math.min(2, uniqueParticipants.length),
                itemBuilder: (context, index) {
                  final participant = uniqueParticipants[index];
                  final isHostParticipant =
                      participant.userId == room?.host.userId;
                  var muted = participant.muted;
                  if (participant.role == 'listener') {
                    muted = true;
                  } else if (isHostParticipant && isHost) {
                    muted = _muted || participant.muted;
                  } else if (participant.userId == room?.viewerUserId) {
                    muted = _muted;
                  }
                  final speaking =
                      !muted &&
                      _liveKitSpeakingParticipantIds.contains(
                        participant.userId.toString(),
                      );
                  final role = switch (participant.role) {
                    'host' => '主持人',
                    'cohost' => '联席主持',
                    'speaker' => '发言人',
                    _ => '听众',
                  };
                  return _AliyunShareMemberTile(
                    participant: participant,
                    role: role,
                    isHost: isHostParticipant,
                    muted: muted,
                    speaking: speaking,
                    palette: palette,
                    compact: !_shareMembersExpanded,
                  );
                },
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 38),
              onPressed: () => setState(
                () => _shareMembersExpanded = !_shareMembersExpanded,
              ),
              child: Icon(
                _shareMembersExpanded
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.chevron_down,
                color: palette.primaryText.withValues(alpha: .9),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingStage({
    required bool hasAliyunVideo,
    required AcoPalette palette,
    required LiveRoom? room,
    required bool isHost,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final checkIn = room?.checkIn;
      final showCheckIn =
          !_emojiPickerVisible &&
          checkIn != null &&
          _checkInIsActive(checkIn) &&
          (isHost || (!_checkingIn && !checkIn.viewerChecked));
      final raisedHandCount = room?.raisedHandCount ?? 0;

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          if (hasAliyunVideo) ...[
            const Positioned.fill(child: ColoredBox(color: _black)),
            Positioned.fill(
              child: AliPlayerView(
                onCreated: _onAliyunPlayerViewCreated,
                x: 0,
                y: 0,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                aliPlayerViewType: AliPlayerViewTypeForAndroid.displayview,
              ),
            ),
            if (_danmakuVisible)
              Positioned.fill(
                child: _RoomChatHistory(
                  palette: palette,
                  liveMessages: _chatBuffer.messages,
                  hasLive: widget.live != null,
                  scrollToLatestSignal: _scrollToLatestSignal,
                  showEmptyState: false,
                  isScreenShareOverlay: true,
                ),
              ),
          ] else if (_danmakuVisible)
            Positioned.fill(
              child: _RoomChatHistory(
                palette: palette,
                liveMessages: _chatBuffer.messages,
                hasLive: widget.live != null,
                scrollToLatestSignal: _scrollToLatestSignal,
                showEmptyState: false,
                isScreenShareOverlay: true,
              ),
            ),
          if (room != null && isHost && raisedHandCount > 0)
            Positioned(
              top: showCheckIn ? 14 : 44,
              left: showCheckIn ? 94 : 12,
              child: _RaisedHandIndicator(
                count: raisedHandCount,
                onPressed: () => unawaited(_showRaisedHandRequests()),
              ),
            ),
          _buildMeetingParticipantsSidebar(
            palette: palette,
            room: room,
            isHost: isHost,
            constraints: constraints,
          ),
          if (showCheckIn)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: _LiveRoomCheckInButton(
                  palette: palette,
                  checkIn: checkIn,
                  isHost: isHost,
                  size: 92,
                  onPressed: isHost ? null : _confirmCheckIn,
                  onShown: () =>
                      _recordCheckInButtonDisplayed(checkIn.deadline),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _buildRoom(BuildContext context) {
    final palette = widget.palette;
    final live = widget.live;
    final room = _room;
    final serverViewerRole = room?.viewerRole;
    final isHost = _isLiveHostRole(serverViewerRole);
    final canManageMicrophones = _canManageLiveMicrophones(serverViewerRole);
    // The room snapshot is only an authorization update. A listener becomes
    // a connected speaker in the UI only after the fresh LiveKit token has
    // connected and its local track has been initialized successfully.
    // Individual speaker unmute overrides the room-wide mute. Use the
    // viewer's persisted mute state for local microphone controls instead of
    // treating the global room flag as authoritative for every participant.
    final audioMuted = !isHost && (room?.viewerMuted ?? false);
    final canSpeak =
        live == null ||
        (_liveKitRoom != null &&
            (canManageMicrophones ||
                (serverViewerRole == 'speaker' && _liveKitPublishReady)));
    // The server keeps membership through a reconnect grace period, but do
    // not send mute requests while the realtime connection is recovering.
    // Keep the control enabled so a muted speaker can unmute themselves.
    final canToggleMicrophone = canSpeak && !_networkReconnecting;
    // A self-muted speaker becomes a listener and must raise their hand again.
    final chatMuted = room?.chatMuted == true && !isHost;
    // Do NOT add MediaQuery.viewInsetsOf: with adjustResize the window (and
    // this route) already sits above the keyboard, and CupertinoPageScaffold
    // zeroes viewInsets for the child. Adding the inset again would double
    // the keyboard height and leave a gap between the danmaku and the bar.
    final bottomOverlayInset =
        _roomBottomBarHeight +
        (_emojiPickerVisible ? _roomEmojiPickerHeight : 0);
    _recordRoomCheckInState(room, isHost);
    final aliyunPlayUrl = _aliyunLivePlayUrl;
    final hasAliyunVideo =
        aliyunPlayUrl != null && !isHost && !_screenBroadcasting;
    final hasMeetingBackground =
        !hasAliyunVideo && (live?.backgroundId.isNotEmpty ?? false);

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack());
      },
      child: _DetailScaffold(
        palette: palette,
        title: live?.title.trim().isNotEmpty == true ? live!.title : '语音房',
        titleFollowsBack: true,
        headerTopPadding: 0,
        headerRightPadding: 0,
        onBack: () => unawaited(_handleBack()),
        right: _LiveRoomHeaderActions(
          palette: palette,
          count: room?.participantCount,
          onMembers: _showMembers,
          onMinimize: switch (defaultTargetPlatform) {
            TargetPlatform.android => () => unawaited(_enterPictureInPicture()),
            TargetPlatform.iOS => () => unawaited(_startIOSPictureInPicture()),
            _ => null,
          },
          onMore: _showRoomActions,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: palette.background),
            if (hasMeetingBackground)
              Positioned.fill(
                child: Image.asset(
                  _meetingBackgroundAssetPath(live!.backgroundId),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            if (hasMeetingBackground)
              Positioned.fill(
                child: ColoredBox(
                  color: palette.dark
                      ? const Color(0x66000000)
                      : const Color(0x99FFFFFF),
                ),
              ),
            Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomOverlayInset),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _dismissKeyboard();
                        if (_emojiPickerVisible) {
                          setState(() => _emojiPickerVisible = false);
                        }
                      },
                      onPanDown: (_) {
                        if (_emojiPickerVisible) {
                          setState(() => _emojiPickerVisible = false);
                        }
                        _dismissKeyboard();
                      },
                      child: _buildMeetingStage(
                        hasAliyunVideo: hasAliyunVideo,
                        palette: palette,
                        room: room,
                        isHost: isHost,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 18,
                  child: _LiveRoomNetworkStatusChip(
                    wsReconnecting: _networkReconnecting,
                    liveKitConnecting: _liveKitConnecting,
                    liveKitConnected: _liveKitRoom != null,
                    liveKitReconnecting: _liveKitReconnecting,
                    liveKitReconnectStopped: _liveKitReconnectStopped,
                  ),
                ),
                if (isHost && _screenBroadcasting)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _black.withValues(alpha: .62),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _white.withValues(alpha: .12),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.rectangle_on_rectangle,
                                color: Color(0xFF9BEF00),
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '正在共享屏幕',
                                style: TextStyle(
                                  color: _white.withValues(alpha: .95),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isHost && _screenBroadcastStarting)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _black.withValues(alpha: .72),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 13,
                                height: 13,
                                child: CupertinoActivityIndicator(
                                  color: _white,
                                  radius: 7,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                '正在启动屏幕共享',
                                style: TextStyle(
                                  color: _white.withValues(alpha: .95),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_handRaiseNoticeVisible)
                  const Center(child: _LiveRoomInfoNotice()),
                if (_networkReconnecting ||
                    _liveKitConnecting ||
                    _liveKitReconnecting)
                  _LiveRoomNetworkNotice(
                    wsReconnecting: _networkReconnecting,
                    liveKitConnecting: _liveKitConnecting,
                    liveKitReconnecting: _liveKitReconnecting,
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: _emojiPickerVisible ? _roomEmojiPickerHeight : 0,
                  child: _RoomBottomBar(
                    palette: palette,
                    muted: _muted,
                    canSpeak: canSpeak,
                    audioMuted: audioMuted,
                    showDanmakuToggle: true,
                    danmakuVisible: _danmakuVisible,
                    onToggleDanmaku: () =>
                        setState(() => _danmakuVisible = !_danmakuVisible),
                    chatMuted: chatMuted,
                    onMic: canToggleMicrophone ? _toggleMicrophone : null,
                    controller: _messageController,
                    onEmojiPressed: _toggleEmojiPicker,
                    onImagePressed: _pickAndSendImage,
                    sendingImage: _sendingImage,
                    onSubmitted: _sendMessage,
                  ),
                ),
                if (_emojiPickerVisible)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _AcoEmojiPicker(
                      palette: palette,
                      controller: _messageController,
                      onEmojiSelected: () =>
                          setState(() => _emojiPickerVisible = false),
                    ),
                  ),
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _reentryCoolingDown
                        ? ColoredBox(
                            key: const ValueKey('live-room-reentry-cooldown'),
                            color: const Color(0xE6000000),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CupertinoActivityIndicator(radius: 14),
                                  const SizedBox(height: 14),
                                  Text(
                                    '正在准备重新进入会议',
                                    style: TextStyle(
                                      color: _white,
                                      fontSize: AcoTypography.bodyEmphasis,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '请稍候 $_reentryCooldownSeconds 秒',
                                    style: TextStyle(
                                      color: _white.withValues(alpha: .72),
                                      fontSize: AcoTypography.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
