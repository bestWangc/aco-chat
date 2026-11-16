part of 'aco_design_shell.dart';

// This extension renders the State-owned room UI and therefore legitimately
// uses State.setState while preserving the original lifecycle owner.
// ignore_for_file: invalid_use_of_protected_member

extension _VoiceRoomUi on _VoiceRoomPageState {
  Widget? _buildRoomOverview({
    required AcoPalette palette,
    required LiveRoom? room,
    required bool isHost,
  }) {
    if (_emojiPickerVisible) {
      _recordCheckInButtonState(
        room,
        isHost: isHost,
        hiddenReason: 'emoji_picker_open',
      );
      return null;
    }
    _recordCheckInButtonState(room, isHost: isHost);
    if (room != null) {
      return _LiveRoomOverview(
        palette: palette,
        room: room,
        isHost: isHost,
        // The initial room snapshot and the local LiveKit state can arrive in
        // either order. Treat either source reporting mute as authoritative so
        // a muted host avatar never falls back to the grey "not speaking"
        // treatment during entry or immediately after toggling.
        hostMuted: isHost ? (_muted || room.host.muted) : room.host.muted,
        viewerMuted: _muted,
        checkingIn: _checkingIn,
        speakingParticipantIds: _liveKitSpeakingParticipantIds,
        onCheckIn: _confirmCheckIn,
        onCheckInButtonShown: _recordCheckInButtonDisplayed,
        onShowRaisedHandRequests: () => unawaited(_showRaisedHandRequests()),
        // Member mute/unmute is managed from the members list. Keep avatars
        // display-only so tapping one does not open an action sheet.
        onSpeakerTap: null,
      );
    }
    if (_roomLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: CupertinoActivityIndicator(),
      );
    }
    return null;
  }

  Widget _buildAliyunShareStage({
    required BuildContext context,
    required AcoPalette palette,
    required LiveRoom? room,
    required bool isHost,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final panelWidth = (constraints.maxWidth * .15)
          .clamp(58.0, 68.0)
          .toDouble();
      final panelHeight = math.min(420.0, constraints.maxHeight * .62);
      final participants = room == null
          ? const <LiveParticipant>[]
          : <LiveParticipant>[room.host, ...room.speakers, ...room.listeners];
      final seenUserIds = <int>{};
      final uniqueParticipants = participants
          .where((participant) => seenUserIds.add(participant.userId))
          .toList(growable: false);
      final checkIn = room?.checkIn;
      final showCheckIn =
          checkIn != null &&
          _checkInIsActive(checkIn) &&
          (isHost || (!_checkingIn && !checkIn.viewerChecked));

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned.fill(child: ColoredBox(color: _black)),
          Positioned.fill(
            child: AliPlayerView(
              onCreated: _onAliyunPlayerViewCreated,
              x: 0,
              y: 0,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              aliPlayerViewType: AliPlayerViewTypeForAndroid.textureview,
            ),
          ),
          if (showCheckIn)
            Positioned(
              top: 10,
              left: 12,
              child: _LiveRoomCheckInButton(
                palette: palette,
                checkIn: checkIn,
                isHost: isHost,
                onPressed: isHost ? null : _confirmCheckIn,
                onShown: () => _recordCheckInButtonDisplayed(checkIn.deadline),
              ),
            ),
          if (room != null && isHost && (room.raisedHandCount ?? 0) > 0)
            Positioned(
              top: 14,
              left: showCheckIn ? 94 : 12,
              child: _RaisedHandIndicator(
                count: room.raisedHandCount!,
                onPressed: () => unawaited(_showRaisedHandRequests()),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            height: math.min(360.0, constraints.maxHeight * .52),
            child: _RoomChatHistory(
              palette: palette,
              liveMessages: _chatBuffer.messages,
              hasLive: widget.live != null,
              scrollToLatestSignal: _scrollToLatestSignal,
              showEmptyState: false,
              isScreenShareOverlay: true,
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            top: 12,
            right: 8,
            width: panelWidth,
            height: _shareMembersExpanded ? panelHeight : 146,
            child: Container(
              decoration: BoxDecoration(
                color: _black.withValues(
                  alpha: _shareMembersExpanded ? .34 : .22,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _white.withValues(alpha: .10)),
              ),
              child: Column(
                children: [
                  if (_shareMembersExpanded)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '成员 ${room?.participantCount ?? 0}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.primaryText.withValues(alpha: .9),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
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
                      size: 14,
                    ),
                  ),
                ],
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
    final roomOverview = _buildRoomOverview(
      palette: palette,
      room: room,
      isHost: isHost,
    );
    final aliyunPlayUrl = _aliyunLivePlayUrl;
    final hasAliyunVideo = aliyunPlayUrl != null;

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
          onMembers: hasAliyunVideo
              ? () => setState(
                  () => _shareMembersExpanded = !_shareMembersExpanded,
                )
              : _showMembers,
          onCopyDiagnostics: () => unawaited(_copyCheckInDiagnostics()),
          onMore: isHost ? _showHostActions : null,
        ),
        child: Stack(
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (hasAliyunVideo) {
                        return _buildAliyunShareStage(
                          context: context,
                          palette: palette,
                          room: room,
                          isHost: isHost,
                        );
                      }
                      const overviewChatGap = 6.0;
                      const minChatHeight = 160.0;
                      const screenShareHeight = 202.0;
                      final overviewMaxHeight = math.max(
                        0.0,
                        constraints.maxHeight -
                            overviewChatGap -
                            minChatHeight -
                            (hasAliyunVideo ? screenShareHeight : 0),
                      );
                      return Column(
                        children: [
                          if (hasAliyunVideo)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) =>
                                        AliPlayerView(
                                          onCreated: _onAliyunPlayerViewCreated,
                                          x: 0,
                                          y: 0,
                                          width: constraints.maxWidth,
                                          height: constraints.maxHeight,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          if (roomOverview != null)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: overviewMaxHeight,
                              ),
                              child: SingleChildScrollView(
                                primary: false,
                                child: roomOverview,
                              ),
                            ),
                          const SizedBox(height: overviewChatGap),
                          Expanded(
                            child: _RoomChatHistory(
                              palette: palette,
                              liveMessages: _chatBuffer.messages,
                              hasLive: live != null,
                              scrollToLatestSignal: _scrollToLatestSignal,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            if (_handRaiseNoticeVisible)
              const Center(child: _LiveRoomInfoNotice()),
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
                showHandControl: !canManageMicrophones,
                handRaised: _handRaised,
                chatMuted: chatMuted,
                onMic: canToggleMicrophone ? _toggleMicrophone : null,
                onHand: room?.canRaiseHand == true ? _raiseHand : null,
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
                        color: Color(0xE6000000),
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
      ),
    );
  }
}
