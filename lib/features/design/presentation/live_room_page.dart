// ignore_for_file: experimental_member_use

part of 'aco_design_shell.dart';

class _LiveStreamPage extends StatelessWidget {
  const _LiveStreamPage({required this.palette, required this.onOpen});
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: '正在直播',
    right: AcoTopActions(palette: palette, onOpen: onOpen),
    child: _LiveListMessage(palette: palette, message: '请前往广场查看实时直播列表。'),
  );
}

enum LiveRoomExitReason { kicked }

class _VoiceRoomPage extends StatefulWidget {
  const _VoiceRoomPage({required this.palette, this.live, this.joinPassword});
  final AcoPalette palette;
  final LiveSession? live;
  final String? joinPassword;

  @override
  State<_VoiceRoomPage> createState() => _VoiceRoomPageState();
}

class _VoiceRoomPageState extends State<_VoiceRoomPage>
    with WidgetsBindingObserver {
  static const _liveAudioBackgroundChannel = MethodChannel(
    'aco/live-audio-background',
  );
  static const _liveAudioRouteChannel = MethodChannel('aco/live-audio-route');
  static const _communicationAudioSession = AudioSessionOptions.communication(
    apple: AppleAudioSessionConfiguration(
      category: AppleAudioCategory.playAndRecord,
      categoryOptions: {
        AppleAudioCategoryOption.allowBluetooth,
        AppleAudioCategoryOption.allowBluetoothA2DP,
        AppleAudioCategoryOption.allowAirPlay,
        AppleAudioCategoryOption.defaultToSpeaker,
      },
      mode: AppleAudioMode.videoChat,
    ),
  );
  static const _iosAudioUnitRecoveryDelay = Duration(milliseconds: 1200);
  static const _liveKitReentryCooldown = Duration(seconds: 5);
  static const _liveKitFallbackUrl = 'wss://api.aco.chat';
  static final Map<int, DateTime> _liveKitLeftAtByLiveID = <int, DateTime>{};
  static const _voiceRoomAudioCaptureOptions = AudioCaptureOptions(
    echoCancellation: true,
    noiseSuppression: true,
    autoGainControl: true,
    highPassFilter: false,
    voiceIsolation: true,
    typingNoiseDetection: true,
    // Keep the WebRTC capture and its echo-cancellation reference alive while
    // muted. Recreating the microphone track on every unmute makes the audio
    // processor re-converge and can briefly reintroduce feedback.
    stopAudioCaptureOnMute: false,
  );
  static Future<void>? _liveKitInitialization;

  bool _muted = false;
  bool _handRaised = false;
  bool _emojiPickerVisible = false;
  bool _sending = false;
  bool _transferringHost = false;
  bool _roomLoading = false;
  bool _leaving = false;
  bool _allowPop = false;
  bool _closingRoom = false;
  bool _handRaiseNoticeVisible = false;
  bool _networkReconnecting = false;
  bool _reentryCoolingDown = false;
  bool _checkingIn = false;
  int? _realtimeParticipantCount;
  // A concurrent realtime snapshot can lag behind a successful check-in.
  DateTime? _locallyConfirmedCheckInDeadline;
  DateTime? _realtimeCheckInDeadline;
  int? _realtimeCheckInCount;
  int _lastRoomSnapshotVersion = 0;
  int _roomLoadSequence = 0;
  final Map<String, int> _latestRealtimeEventVersions = <String, int>{};
  int _scrollToLatestSignal = 0;
  int _reentryCooldownSeconds = 0;
  LiveRoom? _room;
  late final LiveChatBuffer _chatBuffer;
  final LiveChatRateLimiter _chatRateLimiter = LiveChatRateLimiter();
  final Set<int> _knownParticipantIds = <int>{};
  late final LiveRealtimeClient _realtimeClient;
  Timer? _handRaiseNoticeTimer;
  Timer? _checkInTimer;
  Timer? _hostHeartbeatTimer;
  Room? _liveKitRoom;
  EventsListener<RoomEvent>? _liveKitEventListener;
  bool _liveKitConnecting = false;
  bool _liveKitReconnecting = false;
  bool _liveKitReconnectStopped = false;
  final Set<String> _liveKitSpeakingParticipantIds = <String>{};
  bool? _liveKitCanPublish;
  bool _liveKitPublishReady = false;
  String? _liveKitRole;
  bool _microphoneUpdating = false;
  bool _liveKitMicrophoneOperationInFlight = false;
  bool _liveKitPermissionReconnectInFlight = false;
  bool _speakerInviteDialogVisible = false;
  LocalAudioTrack? _listenerAudioWarmupTrack;
  bool? _localMuteOverride;
  late final AccountApiClient _apiClient;
  late final AccountSession _accountSession;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chatBuffer = LiveChatBuffer(
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    _realtimeClient = LiveRealtimeClient(
      onEvent: _handleRealtimeEvent,
      onReconnectingChanged: (reconnecting) {
        if (mounted) {
          setState(() {
            _networkReconnecting = reconnecting;
            if (reconnecting) _realtimeParticipantCount = null;
          });
        }
      },
      onReconnectStopped: () {
        if (mounted) _showNotice(context, '弹幕连接中断', '已停止自动重试，请重新进入直播间。');
      },
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(_setLiveRoomWakelock(true));
    _apiClient = AccountApiClient();
    _accountSession = AccountSession(_apiClient);
    if (widget.live != null) {
      unawaited(_initializeRoom());
    }
  }

  Future<void> _initializeRoom() async {
    final live = widget.live;
    if (live == null) return;
    if (mounted) setState(() => _roomLoading = true);
    await _waitForLiveKitReentryCooldown(live.id);
    if (!mounted || _leaving) return;
    // Load the current role before requesting the LiveKit token. Connecting
    // both requests concurrently can issue a second token refresh as soon as
    // the room snapshot arrives, creating two joins for the same participant.
    await _loadRoom(resetRole: true);
    await _connectLiveKit();
    // The auxiliary state stream is started in the background; chat itself is
    // handled by LiveKit data.
    unawaited(_connectRealtime(refreshRoom: false));
  }

  Future<void> _loadRoom({bool silent = false, bool resetRole = false}) async {
    final live = widget.live;
    if (live == null) return;
    final requestSequence = ++_roomLoadSequence;
    if (!silent && mounted) setState(() => _roomLoading = true);
    try {
      final room = await _accountSession.liveRoom(
        live.id,
        joinPassword: widget.joinPassword,
        resetRole: resetRole,
      );
      debugPrint(
        'Live room snapshot: source=api live=${live.id} '
        'role=${room.viewerRole} hostMuted=${room.host.muted} '
        'viewerMuted=${room.viewerMuted} resetRole=$resetRole',
      );
      if (requestSequence == _roomLoadSequence) {
        _applyRoomSnapshot(room);
      }
    } on AccountApiException catch (error) {
      if (requestSequence == _roomLoadSequence && !silent && mounted) {
        _showNotice(context, '无法进入直播间', error.localizedMessage);
      }
    } catch (_) {
      if (requestSequence == _roomLoadSequence && !silent && mounted) {
        _showNotice(context, '无法进入直播间', '请检查网络后重试。');
      }
    } finally {
      if (requestSequence == _roomLoadSequence && !silent && mounted) {
        setState(() => _roomLoading = false);
      }
    }
  }

  void _ensureHostHeartbeat(LiveRoom room) {
    if (room.viewerRole != 'host') {
      _hostHeartbeatTimer?.cancel();
      _hostHeartbeatTimer = null;
      return;
    }
    if (_hostHeartbeatTimer != null) return;
    _hostHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 200),
      (_) => unawaited(_sendHostHeartbeat()),
    );
    unawaited(_sendHostHeartbeat());
  }

  Future<void> _sendHostHeartbeat() async {
    final live = widget.live;
    if (live == null || _leaving) return;
    try {
      await _accountSession.keepLiveAlive(live.id);
    } catch (error) {
      // Heartbeat failures are transient and must not end the live locally.
      debugPrint('Live heartbeat failed: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _hostHeartbeatTimer?.cancel();
      _hostHeartbeatTimer = null;
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    final room = _room;
    if (room?.viewerRole != 'host') return;
    _ensureHostHeartbeat(room!);
    unawaited(_sendHostHeartbeat());
  }

  Future<void> _connectRealtime({bool refreshRoom = true}) async {
    final live = widget.live;
    if (live == null || !mounted || _leaving) return;
    if (refreshRoom) await _loadRoom(silent: true);
    await _realtimeClient.connect(
      uri: _liveWebsocketUri(live.id),
      ticketLoader: () => _accountSession.liveWebsocketTicket(live.id),
    );
  }

  Uri _liveWebsocketUri(int liveId) {
    final apiBase = Uri.parse(const AppConfig().apiBaseUrl);
    final path = apiBase.path.replaceFirst(
      RegExp(r'/api/v1/?$'),
      '/api/v1/lives/$liveId/ws',
    );
    return apiBase.replace(
      scheme: apiBase.scheme == 'https' ? 'wss' : 'ws',
      path: path,
    );
  }

  void _handleRealtimeEvent(dynamic rawEvent) {
    final event = LiveRealtimeEventParser.parse(rawEvent);
    if (event == null) return;
    final eventKey = _stateEventKey(event);
    if (eventKey != null && event.eventVersion > 0) {
      final previousVersion = _latestRealtimeEventVersions[eventKey];
      if (previousVersion != null && event.eventVersion <= previousVersion) {
        return;
      }
      _latestRealtimeEventVersions[eventKey] = event.eventVersion;
    }
    if (_networkReconnecting && mounted) {
      setState(() {
        _networkReconnecting = false;
      });
    }
    switch (event) {
      case LiveRoomSnapshotEvent(:final room):
        _applyRoomSnapshot(room);
      case LiveAudioMuteEvent(:final muted):
        _applyAudioMute(muted);
      case LiveChatMuteEvent(:final muted):
        _applyChatMute(muted);
      case LiveParticipantCountEvent(:final count):
        _applyParticipantCount(count);
      case LiveParticipantJoinedEvent(:final userId, :final nickname):
        if (_knownParticipantIds.add(userId)) {
          _appendChatMessage(nickname: '', text: '欢迎 $nickname 进入直播间');
        }
      case LiveCheckInEvent(
        :final deadline,
        :final checkedInCount,
        :final userId,
      ):
        _applyCheckInEvent(deadline, checkedInCount, userId);
      case LiveCheckInStartedEvent(:final deadline):
        _applyCheckInStarted(deadline);
      case LiveRaisedHandCountEvent(:final count):
        _applyRaisedHandCount(count);
      case LiveParticipantMuteEvent(:final userId, :final muted):
        _applyParticipantMute(userId, muted);
      case LiveKickedEvent():
        unawaited(_handleKicked());
    }
  }

  String? _stateEventKey(LiveRealtimeEvent event) => switch (event) {
    LiveRoomSnapshotEvent() => 'room.snapshot',
    LiveAudioMuteEvent() => 'room.audio_mute',
    LiveChatMuteEvent() => 'room.chat_mute',
    LiveParticipantCountEvent() => 'room.participant_count',
    LiveCheckInEvent(:final userId) => 'room.check_in:$userId',
    LiveCheckInStartedEvent() => 'room.check_in_started',
    LiveRaisedHandCountEvent() => 'room.raised_hand_count',
    LiveParticipantMuteEvent(:final userId) => 'room.participant_mute:$userId',
    LiveParticipantJoinedEvent() || LiveKickedEvent() => null,
  };

  Future<void> _handleKicked() async {
    if (_leaving || _closingRoom) return;
    _leaving = true;
    await _disconnectLiveKitForLeave();
    _closeRoom(LiveRoomExitReason.kicked);
  }

  void _applyParticipantCount(int participantCount) {
    final room = _room;
    if (room == null || !mounted) return;
    // Presence events can arrive late or out of order during reconnects. Do
    // not let an invalid server value render a negative audience count.
    final safeParticipantCount = participantCount < 0 ? 0 : participantCount;
    _realtimeParticipantCount = safeParticipantCount;
    setState(() {
      _room = LiveRoom(
        live: room.live,
        host: room.host,
        hostActive: room.hostActive,
        viewerUserId: room.viewerUserId,
        viewerRole: room.viewerRole,
        snapshotVersion: room.snapshotVersion,
        participantCount: safeParticipantCount,
        speakers: room.speakers,
        listeners: room.listeners,
        raisedHandCount: room.raisedHandCount,
        canRaiseHand: room.canRaiseHand,
        viewerMuted: room.viewerMuted,
        chatMuted: room.chatMuted,
        audioMuted: room.audioMuted,
        checkIn: room.checkIn,
      );
    });
  }

  void _applyCheckInEvent(DateTime deadline, int checkedInCount, int userId) {
    final room = _room;
    if (room == null || !mounted) return;
    final current = room.checkIn;
    if (current == null || current.deadline != deadline) return;
    _realtimeCheckInDeadline = deadline;
    _realtimeCheckInCount = checkedInCount > (_realtimeCheckInCount ?? 0)
        ? checkedInCount
        : _realtimeCheckInCount;
    final viewerChecked = current.viewerChecked || userId == room.viewerUserId;
    setState(() {
      _room = _copyRoom(
        room,
        participantCount: room.participantCount,
        checkIn: LiveCheckIn(
          deadline: deadline,
          checkedInCount: checkedInCount,
          viewerChecked: viewerChecked,
        ),
      );
    });
  }

  void _applyCheckInStarted(DateTime deadline) {
    final room = _room;
    if (room == null || !mounted) return;
    if (room.checkIn?.deadline == deadline) return;
    _realtimeCheckInDeadline = deadline;
    _realtimeCheckInCount = 0;
    setState(
      () => _room = _copyRoom(
        room,
        participantCount: room.participantCount,
        checkIn: LiveCheckIn(
          deadline: deadline,
          checkedInCount: 0,
          viewerChecked: false,
        ),
      ),
    );
  }

  void _applyRaisedHandCount(int count) {
    final room = _room;
    if (room == null || !mounted) return;
    setState(
      () => _room = _copyRoom(
        room,
        participantCount: room.participantCount,
        checkIn: room.checkIn,
        raisedHandCount: count,
      ),
    );
  }

  void _applyAudioMute(bool muted) {
    final room = _room;
    if (room == null || !mounted) return;
    final updatedRoom = LiveRoom(
      live: room.live,
      host: room.host,
      hostActive: room.hostActive,
      viewerUserId: room.viewerUserId,
      viewerRole: room.viewerRole,
      snapshotVersion: room.snapshotVersion,
      participantCount: room.participantCount,
      // The room-level event only changes the global control state. Individual
      // participant mute flags come from the next room snapshot; preserving
      // them here avoids a late global event undoing an individual unmute.
      speakers: room.speakers,
      listeners: room.listeners,
      raisedHandCount: room.raisedHandCount,
      canRaiseHand: room.canRaiseHand,
      viewerMuted: room.viewerMuted,
      chatMuted: room.chatMuted,
      audioMuted: muted,
      checkIn: room.checkIn,
    );
    setState(() {
      _room = updatedRoom;
      _muted = updatedRoom.viewerMuted;
    });
    _localMuteOverride = null;
    unawaited(_syncLiveKitPublishPermission(updatedRoom));
    // The event carries only the room-level flag. Reload the snapshot to get
    // authoritative per-participant mute states (including individual
    // unmute overrides) instead of guessing them locally.
    unawaited(_loadRoom(silent: true));
  }

  void _applyChatMute(bool muted) {
    final room = _room;
    if (room == null || !mounted) return;
    final updatedRoom = LiveRoom(
      live: room.live,
      host: room.host,
      hostActive: room.hostActive,
      viewerUserId: room.viewerUserId,
      viewerRole: room.viewerRole,
      snapshotVersion: room.snapshotVersion,
      participantCount: room.participantCount,
      speakers: room.speakers,
      listeners: room.listeners,
      raisedHandCount: room.raisedHandCount,
      canRaiseHand: room.canRaiseHand,
      viewerMuted: room.viewerMuted,
      chatMuted: muted,
      audioMuted: room.audioMuted,
      checkIn: room.checkIn,
    );
    setState(() => _room = updatedRoom);
    unawaited(_syncLiveKitPublishPermission(updatedRoom));
  }

  void _applyRoomSnapshot(LiveRoom room) {
    if (!mounted) return;
    if (room.snapshotVersion < _lastRoomSnapshotVersion) return;
    _lastRoomSnapshotVersion = room.snapshotVersion;
    if (room.live.status == 'ended') {
      _closeRoom(true);
      return;
    }
    final displayedParticipantCount =
        _realtimeParticipantCount ?? room.participantCount;
    final localCheckInDeadline = _locallyConfirmedCheckInDeadline;
    final incomingCheckIn = room.checkIn;
    var displayedCheckIn = incomingCheckIn;
    final realtimeCount = _realtimeCheckInDeadline == incomingCheckIn?.deadline
        ? _realtimeCheckInCount
        : null;
    if (incomingCheckIn != null &&
        realtimeCount != null &&
        realtimeCount > incomingCheckIn.checkedInCount) {
      displayedCheckIn = LiveCheckIn(
        deadline: incomingCheckIn.deadline,
        checkedInCount: realtimeCount,
        viewerChecked: incomingCheckIn.viewerChecked,
      );
    }
    if (localCheckInDeadline != null &&
        incomingCheckIn != null &&
        incomingCheckIn.deadline == localCheckInDeadline &&
        !incomingCheckIn.viewerChecked) {
      displayedCheckIn = LiveCheckIn(
        deadline: incomingCheckIn.deadline,
        checkedInCount: realtimeCount ?? incomingCheckIn.checkedInCount,
        viewerChecked: true,
      );
    } else if (localCheckInDeadline != null &&
        incomingCheckIn != null &&
        incomingCheckIn.deadline != localCheckInDeadline) {
      _locallyConfirmedCheckInDeadline = null;
    }
    final displayedRoom = _copyRoom(
      room,
      participantCount: displayedParticipantCount,
      checkIn: displayedCheckIn,
    );
    debugPrint(
      'Live room snapshot: source=state live=${room.live.id} '
      'role=${room.viewerRole} hostMuted=${room.host.muted} '
      'viewerMuted=${room.viewerMuted} localMuted=$_muted',
    );
    final invitePending =
        displayedRoom.viewerRole == 'listener' &&
        displayedRoom.listeners.any(
          (participant) =>
              participant.userId == displayedRoom.viewerUserId &&
              participant.speakerInvited,
        );
    if (invitePending && !_speakerInviteDialogVisible) {
      _speakerInviteDialogVisible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showSpeakerInviteDialog());
      });
    }
    _checkInTimer?.cancel();
    if (displayedRoom.checkIn != null) {
      _checkInTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (displayedRoom.checkIn!.deadline.isBefore(DateTime.now())) {
          _checkInTimer?.cancel();
          unawaited(_loadRoom(silent: true));
          return;
        }
        setState(() {});
      });
    }
    final participants = [
      displayedRoom.host,
      ...displayedRoom.speakers,
      ...displayedRoom.listeners,
    ];
    final participantIds = participants.map(
      (participant) => participant.userId,
    );
    final firstSnapshot = _knownParticipantIds.isEmpty;
    final newParticipants = firstSnapshot
        ? participants
              .where(
                (participant) =>
                    displayedRoom.viewerRole == 'listener' &&
                    participant.userId == displayedRoom.viewerUserId,
              )
              .toList(growable: false)
        : participants
              .where(
                (participant) =>
                    !_knownParticipantIds.contains(participant.userId),
              )
              .toList(growable: false);
    _knownParticipantIds
      ..clear()
      ..addAll(participantIds);
    if (newParticipants.isNotEmpty) {
      final timestamp = DateTime.now();
      _appendMessages(
        newParticipants.indexed.map(
          (entry) => LiveMessage(
            id: -timestamp.microsecondsSinceEpoch - entry.$1,
            nickname: '',
            text: '欢迎 ${entry.$2.nickname} 进入直播间',
            createdAt: timestamp,
          ),
        ),
      );
    }
    final localMuteOverride = _localMuteOverride;
    if (localMuteOverride != null && room.viewerMuted == localMuteOverride) {
      _localMuteOverride = null;
    }
    // A room refresh triggered by another member's moderation action may race
    // the mute broadcast. Never turn a locally muted host/speaker back on
    // from that stale snapshot; only an explicit local unmute may do so.
    final keepLocalMute =
        _muted &&
        _room?.viewerRole == displayedRoom.viewerRole &&
        displayedRoom.viewerRole != 'listener';
    // Active-speaker notifications are transport-level activity signals and
    // can arrive after the server has persisted a mute action. Remove stale
    // entries at the snapshot boundary; the widgets also re-check each
    // participant's muted flag when rendering.
    final mutedParticipantIds = <String>{
      if (displayedRoom.host.muted) displayedRoom.host.userId.toString(),
      ...displayedRoom.speakers
          .where((participant) => participant.muted)
          .map((participant) => participant.userId.toString()),
    };
    _liveKitSpeakingParticipantIds.removeAll(mutedParticipantIds);
    setState(() {
      _room = displayedRoom;
      // A realtime snapshot can arrive before the mute request completes.
      // Keep the user's latest local choice until the server echoes it back.
      _muted = localMuteOverride ?? displayedRoom.viewerMuted || keepLocalMute;
      if (displayedRoom.viewerRole != 'listener') _handRaised = false;
      if (displayedRoom.chatMuted && displayedRoom.viewerRole != 'host') {
        _emojiPickerVisible = false;
      }
    });
    unawaited(_syncLiveKitPublishPermission(displayedRoom));
    _ensureHostHeartbeat(displayedRoom);
  }

  LiveRoom _copyRoom(
    LiveRoom room, {
    required int participantCount,
    required LiveCheckIn? checkIn,
    int? raisedHandCount,
    LiveParticipant? host,
    List<LiveParticipant>? speakers,
    List<LiveParticipant>? listeners,
    bool? viewerMuted,
  }) => LiveRoom(
    live: room.live,
    host: host ?? room.host,
    hostActive: room.hostActive,
    viewerUserId: room.viewerUserId,
    viewerRole: room.viewerRole,
    snapshotVersion: room.snapshotVersion,
    participantCount: participantCount,
    speakers: speakers ?? room.speakers,
    listeners: listeners ?? room.listeners,
    raisedHandCount: raisedHandCount ?? room.raisedHandCount,
    canRaiseHand: room.canRaiseHand,
    viewerMuted: viewerMuted ?? room.viewerMuted,
    chatMuted: room.chatMuted,
    audioMuted: room.audioMuted,
    checkIn: checkIn,
  );

  void _applyParticipantMute(int userId, bool muted) {
    final room = _room;
    if (room == null || !mounted) return;
    LiveParticipant update(LiveParticipant participant) =>
        participant.userId == userId
        ? LiveParticipant(
            userId: participant.userId,
            nickname: participant.nickname,
            username: participant.username,
            avatarUrl: participant.avatarUrl,
            role: participant.role,
            handRaised: participant.handRaised,
            muted: muted,
            speakerInvited: participant.speakerInvited,
          )
        : participant;
    final isViewer = userId == room.viewerUserId;
    final updatedRoom = _copyRoom(
      room,
      participantCount: room.participantCount,
      checkIn: room.checkIn,
      host: update(room.host),
      speakers: room.speakers.map(update).toList(growable: false),
      listeners: room.listeners.map(update).toList(growable: false),
      viewerMuted: isViewer ? muted : null,
    );
    setState(() {
      _room = updatedRoom;
      if (isViewer) {
        _muted = muted;
        _localMuteOverride = null;
      }
    });
    if (isViewer) {
      unawaited(_syncLiveKitPublishPermission(updatedRoom));
    }
  }

  Future<void> _raiseHand() async {
    final live = widget.live;
    if (live == null || _handRaised || _networkReconnecting) return;
    try {
      await _accountSession.raiseLiveHand(live.id);
      if (!mounted) return;
      setState(() => _handRaised = true);
      _showHandRaiseNotice();
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '举手失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '举手失败', '请检查网络后重试。');
    }
  }

  void _showHandRaiseNotice() {
    _handRaiseNoticeTimer?.cancel();
    setState(() => _handRaiseNoticeVisible = true);
    _handRaiseNoticeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _handRaiseNoticeVisible = false);
    });
  }

  Future<void> _endLive() async {
    final live = widget.live;
    if (live == null) return;
    try {
      // The host action sheet is popped immediately before this method is
      // started. Wait until the room route is current before popping it, so a
      // fast API response cannot pop the still-closing sheet instead.
      while (mounted && !(ModalRoute.of(context)?.isCurrent ?? true)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (!mounted) return;
      await _accountSession.endLive(live.id);
      _closeRoom(true);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '结束失败', error.message);
    }
  }

  Future<void> _confirmEndLive() async {
    _dismissKeyboard();
    final shouldEnd = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('结束直播'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('确定要结束这场直播吗？'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            textStyle: TextStyle(color: widget.palette.accent),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('结束直播'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _dismissKeyboard();
    if (shouldEnd == true) {
      await _endLive();
    }
  }

  void _showMembers() {
    final room = _room;
    final live = widget.live;
    if (room == null || live == null) return;
    // Clear the room message field before presenting the member sheet. If it
    // remains focused, dismissing the sheet restores that focus and reopens
    // the keyboard underneath the sheet.
    _dismissKeyboard();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _LiveRoomMembersSheet(
        palette: widget.palette,
        initialTotal: room.participantCount,
        isModerator: room.viewerRole == 'host',
        currentUserId: room.viewerUserId,
        loadPage: (page, keyword) =>
            _accountSession.liveMembers(live.id, page: page, keyword: keyword),
        onMemberTap: room.viewerRole == 'host' ? _showMemberActions : null,
        audioMuted: room.audioMuted,
        onToggleAudioMute: room.viewerRole == 'host'
            ? (muted) async {
                await _setAudioMute(muted);
                await _loadRoom(silent: true);
              }
            : null,
        chatMuted: room.chatMuted,
        onToggleChatMute: room.viewerRole == 'host'
            ? (muted) async {
                await _setChatMute(muted);
                await _loadRoom(silent: true);
              }
            : null,
      ),
    );
  }

  Future<void> _showMemberActions(LiveParticipant member) async {
    final live = widget.live;
    if (live == null || member.role == 'host') return;
    final action = await showCupertinoModalPopup<_LiveMemberAction>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(
          member.nickname,
          style: const TextStyle(fontSize: AcoTypography.bodySmall),
        ),
        actions: [
          if (member.role == 'listener')
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(
                sheetContext,
              ).pop(_LiveMemberAction.approveSpeaker),
              child: const Text(
                '邀请上麦',
                style: TextStyle(fontSize: AcoTypography.bodySmall),
              ),
            ),
          if (member.role == 'speaker') ...[
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(_LiveMemberAction.toggleMute),
              child: Text(
                member.muted ? '解除静音' : '静音',
                style: const TextStyle(fontSize: AcoTypography.bodySmall),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(
                sheetContext,
              ).pop(_LiveMemberAction.transferHost),
              child: const Text(
                '转让主持人',
                style: TextStyle(fontSize: AcoTypography.bodySmall),
              ),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(
                sheetContext,
              ).pop(_LiveMemberAction.removeSpeaker),
              child: const Text(
                '移至听众',
                style: TextStyle(fontSize: AcoTypography.bodySmall),
              ),
            ),
          ],
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () =>
                Navigator.of(sheetContext).pop(_LiveMemberAction.kick),
            child: const Text(
              '踢出直播间',
              style: TextStyle(fontSize: AcoTypography.bodySmall),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text(
            '取消',
            style: TextStyle(fontSize: AcoTypography.bodySmall),
          ),
        ),
      ),
    );
    if (action == null) return;
    if (!mounted) return;
    if (action == _LiveMemberAction.kick && !await _confirmKickMember(member)) {
      return;
    }
    try {
      switch (action) {
        case _LiveMemberAction.approveSpeaker:
          debugPrint(
            'Live invite speaker: live=${live.id} target=${member.userId} '
            'beforeHostMuted=${_room?.host.muted} localMuted=$_muted',
          );
          await _accountSession.inviteLiveSpeaker(live.id, member.userId);
          if (mounted) _showNotice(context, '邀请已发送', '等待对方确认上麦。');
        case _LiveMemberAction.toggleMute:
          await _accountSession.setLiveSpeakerMute(
            live.id,
            member.userId,
            !member.muted,
          );
        case _LiveMemberAction.removeSpeaker:
          await _accountSession.removeLiveSpeaker(live.id, member.userId);
        case _LiveMemberAction.transferHost:
          await _transferHost(member);
        case _LiveMemberAction.kick:
          await _accountSession.kickLiveMember(live.id, member.userId);
      }
      await _loadRoom(silent: true);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '操作失败', error.localizedMessage);
    } catch (_) {
      if (mounted) _showNotice(context, '操作失败', '请检查网络后重试。');
    }
  }

  Future<void> _showSpeakerInviteDialog() async {
    final live = widget.live;
    if (live == null) return;
    final accepted = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('主持人邀请你上麦'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('同意后将连接麦克风并成为发言人。'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('拒绝'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('同意'),
          ),
        ],
      ),
    );
    _speakerInviteDialogVisible = false;
    if (!mounted) return;
    try {
      if (accepted == true) {
        await _accountSession.acceptLiveSpeakerInvite(live.id);
      } else {
        await _accountSession.declineLiveSpeakerInvite(live.id);
      }
      await _loadRoom(silent: true);
    } catch (_) {
      if (mounted) _showNotice(context, '上麦失败', '请稍后重试。');
    }
  }

  Future<bool> _confirmKickMember(LiveParticipant member) async {
    final shouldKick = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('踢出成员'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('确定要将 ${member.nickname} 移出本场直播吗？'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('踢出'),
          ),
        ],
      ),
    );
    return shouldKick == true;
  }

  Future<void> _setChatMute(bool muted) async {
    final live = widget.live;
    if (live == null) return;
    try {
      await _accountSession.setLiveChatMute(live.id, muted);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '设置失败', error.message);
      rethrow;
    } catch (_) {
      if (mounted) _showNotice(context, '设置失败', '请检查网络后重试。');
      rethrow;
    }
  }

  void _showCheckInDurations() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text(
          '发起签到',
          style: TextStyle(fontSize: AcoTypography.bodyEmphasis),
        ),
        message: const Text(
          '请选择签到时长，成员将在房间内看到签到提醒。',
          style: TextStyle(fontSize: AcoTypography.bodySmall),
        ),
        actions: [5, 10, 15, 30]
            .map(
              (minutes) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_startCheckIn(minutes * 60));
                },
                child: Text(
                  '$minutes 分钟',
                  style: const TextStyle(fontSize: AcoTypography.bodyEmphasis),
                ),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text(
            '取消',
            style: TextStyle(fontSize: AcoTypography.bodyEmphasis),
          ),
        ),
      ),
    );
  }

  Future<void> _startCheckIn(int durationSeconds) async {
    final live = widget.live;
    if (live == null) return;
    try {
      await _accountSession.startLiveCheckIn(live.id, durationSeconds);
      if (mounted) {
        showAcoAlertNotice(context, '签到已发起', '成员可在倒计时结束前完成签到。');
      }
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '发起失败', error.message);
    }
  }

  Future<void> _confirmCheckIn() async {
    final live = widget.live;
    if (live == null || _checkingIn || _room?.checkIn?.viewerChecked == true) {
      return;
    }
    if (mounted) setState(() => _checkingIn = true);
    try {
      await _accountSession.confirmLiveCheckIn(live.id);
      _locallyConfirmedCheckInDeadline = _room?.checkIn?.deadline;
      await _loadRoom(silent: true);
      if (mounted) _showNotice(context, '签到成功', '已完成本次直播签到。');
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '签到失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '签到失败', '请检查网络后重试。');
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  Future<void> _showRaisedHandRequests() async {
    final room = _room;
    final live = widget.live;
    if (room?.viewerRole != 'host' || live == null) return;
    try {
      final users = await _accountSession.raisedLiveHands(live.id);
      if (!mounted || users.isEmpty) return;
      _showRaisedHandRequestsDialog(users);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '无法加载举手列表', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '无法加载举手列表', '请检查网络后重试。');
    }
  }

  void _showRaisedHandRequestsDialog(List<LiveParticipant> users) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 320,
            maxHeight: math.min(280, MediaQuery.sizeOf(context).height * .42),
          ),
          child: CupertinoPopupSurface(
            child: _RaisedHandRequests(
              palette: widget.palette,
              users: users,
              onClose: () => Navigator.of(dialogContext).pop(),
              onApprove: (userId) {
                Navigator.of(dialogContext).pop();
                unawaited(_approveSpeaker(userId));
              },
              onReject: (userId) {
                Navigator.of(dialogContext).pop();
                unawaited(_rejectSpeakerRequest(userId));
              },
              onRejectAll: () {
                Navigator.of(dialogContext).pop();
                unawaited(_rejectAllSpeakerRequests(users));
              },
              maxHeight: 170,
            ),
          ),
        ),
      ),
    );
  }

  void _showHostActions() {
    final room = _room;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: widget.palette.dark ? Brightness.dark : Brightness.light,
          primaryColor: widget.palette.accent,
        ),
        child: CupertinoActionSheet(
          actions: [
            if (room?.checkIn == null)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _showCheckInDurations();
                },
                child: _hostActionLabel('发起签到'),
              ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                unawaited(_confirmEndLive());
              },
              child: _hostActionLabel('结束直播'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: _hostActionLabel('取消'),
          ),
        ),
      ),
    );
  }

  Widget _hostActionLabel(String label) =>
      Text(label, style: const TextStyle(fontSize: AcoTypography.body));

  Future<void> _handleBack() async {
    if (_room?.viewerRole == 'host') {
      await _confirmEndLive();
      return;
    }
    if (_leaving) return;
    _leaving = true;
    await _disconnectLiveKitForLeave();
    final live = widget.live;
    if (live != null) {
      try {
        await _accountSession.leaveLive(live.id);
      } catch (_) {
        // The server can clean up stale presence if the connection is lost.
      }
    }
    _closeRoom();
  }

  void _closeRoom([Object? result]) {
    if (!mounted || _closingRoom) return;
    _closingRoom = true;
    unawaited(_disconnectLiveKitForLeave());
    setState(() {
      _allowPop = true;
      _leaving = true;
    });
    Navigator.of(context).pop(result);
  }

  Future<void> _transferHost(LiveParticipant speaker) async {
    final live = widget.live;
    if (live == null || _transferringHost) return;
    setState(() => _transferringHost = true);
    try {
      await _accountSession.transferLiveHost(live.id, speaker.userId);
      // The room-state broadcast changes this participant from host to
      // listener. Keep the page open so the former host can continue watching.
      await _loadRoom(silent: true);
      if (mounted) _showNotice(context, '转让成功', '你已变为听众，仍可留在直播间。');
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '转让失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '转让失败', '请检查网络后重试。');
    } finally {
      if (mounted) setState(() => _transferringHost = false);
    }
  }

  Future<void> _approveSpeaker(int userId) async {
    await _updateSpeaker(
      userId: userId,
      action: _accountSession.approveLiveSpeaker,
      failureTitle: '批准失败',
    );
  }

  Future<void> _rejectSpeakerRequest(int userId) async {
    await _updateSpeaker(
      userId: userId,
      action: _accountSession.removeLiveSpeaker,
      failureTitle: '拒绝失败',
    );
  }

  Future<void> _rejectAllSpeakerRequests(List<LiveParticipant> users) async {
    for (final user in users) {
      await _rejectSpeakerRequest(user.userId);
    }
  }

  Future<void> _updateSpeaker({
    required int userId,
    required Future<void> Function(int liveId, int userId) action,
    required String failureTitle,
  }) async {
    final live = widget.live;
    if (live == null) return;
    try {
      await action(live.id, userId);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, failureTitle, error.message);
    }
  }

  @override
  void dispose() {
    unawaited(_setLiveRoomWakelock(false));
    _handRaiseNoticeTimer?.cancel();
    _checkInTimer?.cancel();
    _hostHeartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _chatBuffer.dispose();
    unawaited(_realtimeClient.dispose());
    unawaited(_disconnectLiveKitForLeave());
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(AudioManager.instance.deactivateAudioSession());
    }
    _apiClient.close();
    _messageController.dispose();
    super.dispose();
  }

  void _toggleEmojiPicker() =>
      setState(() => _emojiPickerVisible = !_emojiPickerVisible);

  void _handleLiveKitData(DataReceivedEvent event) {
    if (event.topic != 'chat' || _room?.chatMuted == true) return;
    try {
      final payload = jsonDecode(utf8.decode(event.data));
      if (payload is! Map<String, dynamic>) return;
      final text = payload['text'];
      if (text is! String || text.trim().isEmpty || text.length > 300) return;
      final nickname = event.participant?.name.trim();
      _appendChatMessage(
        nickname: nickname == null || nickname.isEmpty ? '成员' : nickname,
        text: text,
      );
    } catch (_) {
      // Ignore malformed or non-chat data packets from other clients.
    }
  }

  Future<void> _sendMessage() async {
    final live = widget.live;
    final text = _messageController.text.trim();
    final isViewerChatMuted =
        _room?.chatMuted == true && _room?.viewerRole != 'host';
    if (live == null ||
        text.isEmpty ||
        _sending ||
        _networkReconnecting ||
        isViewerChatMuted) {
      return;
    }
    final payload = utf8.encode(jsonEncode({'text': text}));
    if (!_checkMessageSendLimits(payload.length)) return;
    setState(() => _sending = true);
    try {
      final room = _liveKitRoom;
      if (room == null) {
        throw StateError('LiveKit room is not connected');
      }
      await room.localParticipant?.publishData(
        payload,
        reliable: true,
        topic: 'chat',
      );
      _appendChatMessage(nickname: _localChatNickname, text: text);
      if (!mounted) return;
      setState(() {
        _messageController.clear();
        // Sending is an explicit request to return to the active conversation,
        // even when the viewer was reading older messages.
        _scrollToLatestSignal++;
      });
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '发送失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '发送失败', '请检查网络后重试。');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _checkMessageSendLimits(int payloadBytes) {
    switch (_chatRateLimiter.check(payloadBytes)) {
      case LiveChatSendLimit.allowed:
        return true;
      case LiveChatSendLimit.payloadTooLarge:
        _showNotice(context, '发送失败', '弹幕内容过长，请控制在 512 字节以内。');
        return false;
      case LiveChatSendLimit.sentTooRecently:
        _showNotice(context, '发送太快', '请稍后再发送。');
        return false;
      case LiveChatSendLimit.rateLimited:
        _showNotice(context, '发送太快', '房间弹幕较多，请稍后再试。');
        return false;
    }
  }

  String get _localChatNickname {
    final room = _room;
    if (room != null && room.host.userId == room.viewerUserId) {
      return room.host.nickname;
    }
    return '我';
  }

  void _appendChatMessage({required String nickname, required String text}) {
    final now = DateTime.now();
    _chatBuffer.append(
      LiveMessage(
        id: -now.microsecondsSinceEpoch,
        nickname: nickname,
        text: text.trim(),
        createdAt: now,
      ),
    );
  }

  void _appendMessages(Iterable<LiveMessage> incomingMessages) {
    _chatBuffer.appendAll(incomingMessages);
  }

  @override
  Widget build(BuildContext context) => _buildRoom(context);
}

Future<void> _setLiveRoomWakelock(bool enabled) async {
  try {
    if (enabled) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  } on PlatformException {
    // Some targets (for example Flutter Web without a registered plugin)
    // do not provide the wakelock platform channel.
  } catch (_) {
    // Failing to keep the screen awake must not interrupt the live room.
  }
}
