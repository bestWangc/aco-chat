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
    if (_emojiPickerVisible) return null;
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
        checkingIn: _checkingIn,
        speakingParticipantIds: _liveKitSpeakingParticipantIds,
        onCheckIn: _confirmCheckIn,
        onShowRaisedHandRequests: () => unawaited(_showRaisedHandRequests()),
        onSpeakerTap: isHost ? _confirmSpeakerMute : null,
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

  Widget _buildRoom(BuildContext context) {
    final palette = widget.palette;
    final live = widget.live;
    final room = _room;
    final serverViewerRole = room?.viewerRole;
    final isHost = serverViewerRole == 'host';
    // The room snapshot is only an authorization update. A listener becomes
    // a connected speaker in the UI only after the fresh LiveKit token has
    // connected and its local track has been initialized successfully.
    final audioMuted = !isHost && (room?.audioMuted ?? false);
    final canSpeak =
        live == null ||
        (_liveKitPublishReady && (isHost || serverViewerRole == 'speaker'));
    // The server keeps membership through a reconnect grace period, but do
    // not send mute requests while the realtime connection is recovering.
    final canToggleMicrophone = canSpeak && !audioMuted && !_networkReconnecting;
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
          onMore: isHost ? _showHostActions : null,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomOverlayInset),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final overviewMaxHeight = math.max(
                      0.0,
                      constraints.maxHeight - 14,
                    );
                    return Column(
                      children: [
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
                        const SizedBox(height: 14),
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
            if (_handRaiseNoticeVisible)
              const Center(child: _LiveRoomInfoNotice()),
            if (_liveKitConnecting || _liveKitReconnecting)
              Positioned(
                top: 48,
                left: 0,
                right: 0,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CupertinoActivityIndicator(radius: 8),
                          const SizedBox(width: 8),
                          Text(
                            _liveKitConnecting ? '正在连接语音…' : '语音重连中…',
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              left: 18,
              child: _LiveRoomNetworkStatusChip(
                palette: palette,
                reconnecting: _networkReconnecting,
              ),
            ),
            if (_networkReconnecting) const _LiveRoomNetworkNotice(),
            Positioned(
              left: 0,
              right: 0,
              bottom: _emojiPickerVisible ? _roomEmojiPickerHeight : 0,
              child: _RoomBottomBar(
                palette: palette,
                muted: _muted,
                canSpeak: canSpeak,
                audioMuted: audioMuted,
                showHandControl: !isHost,
                handRaised: _handRaised,
                chatMuted: chatMuted,
                onMic: canToggleMicrophone ? _toggleMicrophone : null,
                onHand: room?.canRaiseHand == true ? _raiseHand : null,
                controller: _messageController,
                onEmojiPressed: _toggleEmojiPicker,
                onSubmitted: _sendMessage,
              ),
            ),
            if (_emojiPickerVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _RoomEmojiPicker(
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
                                '正在准备重新进入直播间',
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
