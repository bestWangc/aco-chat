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
  static const _maxLiveMessageCount = 200;
  static const _maxLiveMessageBytes = 512;
  static const _minLiveMessageInterval = Duration(milliseconds: 250);
  static const _liveMessageRateWindow = Duration(seconds: 1);
  static const _maxLiveMessagesPerWindow = 20;
  static const _liveMessageRefreshInterval = Duration(milliseconds: 75);
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
  bool _roomLoading = false;
  bool _leaving = false;
  bool _allowPop = false;
  bool _closingRoom = false;
  bool _handRaiseNoticeVisible = false;
  bool _networkReconnecting = false;
  bool _reentryCoolingDown = false;
  bool _checkingIn = false;
  int _scrollToLatestSignal = 0;
  int _reentryCooldownSeconds = 0;
  LiveRoom? _room;
  final Queue<LiveMessage> _messages = ListQueue<LiveMessage>();
  final Set<int> _knownMessageIds = <int>{};
  final Set<int> _knownParticipantIds = <int>{};
  WebSocketChannel? _eventChannel;
  StreamSubscription<dynamic>? _eventSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _realtimeReconnectStopped = false;
  Timer? _handRaiseNoticeTimer;
  Timer? _checkInTimer;
  Timer? _messageRefreshTimer;
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
  LocalAudioTrack? _listenerAudioWarmupTrack;
  bool? _localMuteOverride;
  DateTime? _lastMessageSentAt;
  DateTime? _messageRateWindowStartedAt;
  int _messageRateWindowCount = 0;
  late final AccountApiClient _apiClient;
  late final AccountSession _accountSession;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
    await _loadRoom();
    await _connectLiveKit();
    // The auxiliary state stream is started in the background; chat itself is
    // handled by LiveKit data.
    unawaited(_connectRealtime(refreshRoom: false));
  }

  Future<void> _connectLiveKit({bool showError = true}) async {
    final live = widget.live;
    if (live == null || !mounted || _leaving || _liveKitConnecting) return;
    _liveKitConnecting = true;
    setState(() {});
    _liveKitReconnectStopped = false;
    Room? connectingRoom;
    String? liveKitUrl;
    try {
      await _ensureLiveKitInitialized();
      await _configureLiveKitMicrophoneMuteMode();
      debugPrint('LiveKit connect: requesting join info for live ${live.id}');
      final joinInfo = await _accountSession.liveKitJoinInfo(
        live.id,
        joinPassword: widget.joinPassword,
      );
      liveKitUrl = joinInfo.url;
      debugPrint(
        'LiveKit connect: join info received, url=$liveKitUrl '
        'role=${joinInfo.role} canPublish=${joinInfo.canPublish} '
        'canPublishData=${joinInfo.canPublishData}',
      );
      var room = _createLiveKitRoom();
      connectingRoom = room;
      final previousRoom = _liveKitRoom;
      _liveKitRoom = null;
      _liveKitPublishReady = false;
      _liveKitEventListener?.dispose();
      _liveKitEventListener = null;
      _liveKitSpeakingParticipantIds.clear();
      await _disconnectLiveKitRoomSafely(previousRoom);
      await _prepareLiveKitAudioSession();
      var preConnectListener = room.createListener()
        ..on<TrackSubscribedEvent>((event) {
          if (event.track is RemoteAudioTrack) {
            debugPrint(
              'LiveKit remote audio subscribed before connect listener: '
              '${event.participant.identity}/${event.publication.sid}',
            );
            unawaited(
              _logRemoteAudioTrackStats(
                event.track as RemoteAudioTrack,
                event.publication.sid,
                event.publication.muted,
              ),
            );
          }
        })
        ..on<AudioPlaybackStatusChanged>((event) {
          if (event.isPlaying) {
            unawaited(_logLiveKitAudioRouteAfterSpeakerReset('audio-playback'));
          }
        });
      debugPrint('LiveKit connect: starting Room.connect ($liveKitUrl)');
      try {
        await room.connect(joinInfo.url, joinInfo.token);
      } catch (primaryError) {
        if (joinInfo.url == _liveKitFallbackUrl) rethrow;
        debugPrint(
          'LiveKit primary connect failed ($primaryError), '
          'retrying $_liveKitFallbackUrl',
        );
        await _disconnectLiveKitRoomSafely(room);
        room = _createLiveKitRoom();
        connectingRoom = room;
        liveKitUrl = _liveKitFallbackUrl;
        preConnectListener.dispose();
        preConnectListener = room.createListener()
          ..on<TrackSubscribedEvent>((event) {
            if (event.track is RemoteAudioTrack) {
              debugPrint(
                'LiveKit remote audio subscribed before connect listener: '
                '${event.participant.identity}/${event.publication.sid}',
              );
              unawaited(
                _logRemoteAudioTrackStats(
                  event.track as RemoteAudioTrack,
                  event.publication.sid,
                  event.publication.muted,
                ),
              );
            }
          })
          ..on<AudioPlaybackStatusChanged>((event) {
            if (event.isPlaying) {
              unawaited(
                _logLiveKitAudioRouteAfterSpeakerReset('audio-playback'),
              );
            }
          });
        await room.connect(_liveKitFallbackUrl, joinInfo.token);
      }
      preConnectListener.dispose();
      debugPrint('LiveKit connect: Room.connect completed');
      unawaited(_logLiveKitAudioRoute('room-connect-completed'));
      if (!mounted || _leaving) {
        await _disconnectLiveKitRoomSafely(room);
        return;
      }
      _liveKitRoom = room;
      _liveKitEventListener = room.createListener()
        ..on<DataReceivedEvent>(_handleLiveKitData)
        ..on<TrackSubscribedEvent>((event) {
          // Keep iOS output routing applied after the first remote audio track
          // creates/activates the native WebRTC audio engine.
          if (event.track is RemoteAudioTrack) {
            debugPrint(
              'LiveKit remote audio subscribed: '
              '${event.participant.identity}/${event.publication.sid}',
            );
            unawaited(
              _logRemoteAudioTrackStats(
                event.track as RemoteAudioTrack,
                event.publication.sid,
                event.publication.muted,
              ),
            );
          }
        })
        ..on<TrackUnsubscribedEvent>((event) {
          if (event.track is RemoteAudioTrack) {
            debugPrint(
              'LiveKit remote audio unsubscribed: '
              '${event.participant.identity}/${event.publication.sid}',
            );
          }
        })
        ..on<TrackUnpublishedEvent>((event) {
          if (event.publication.kind == TrackType.AUDIO) {
            debugPrint(
              'LiveKit remote audio unpublished: '
              '${event.participant.identity}/${event.publication.sid}',
            );
          }
        })
        ..on<TrackSubscriptionExceptionEvent>((event) {
          debugPrint(
            'LiveKit remote track subscription failed: '
            'participant=${event.participant?.identity} sid=${event.sid} '
            'reason=${event.reason}',
          );
        })
        ..on<AudioPlaybackStatusChanged>((event) {
          debugPrint('LiveKit audio playback status: ${event.isPlaying}');
          if (event.isPlaying) {
            unawaited(_logLiveKitAudioRouteAfterSpeakerReset('audio-playback'));
          }
        })
        ..on<ActiveSpeakersChangedEvent>((event) {
          if (!mounted) return;
          setState(() {
            _liveKitSpeakingParticipantIds
              ..clear()
              ..addAll(
                event.speakers.map((participant) => participant.identity),
              );
          });
        })
        ..on<RoomReconnectingEvent>((_) {
          _liveKitReconnecting = true;
          if (mounted) setState(() {});
        })
        ..on<RoomResumingEvent>((_) {
          _liveKitReconnecting = true;
          if (mounted) setState(() {});
        })
        ..on<RoomAttemptReconnectEvent>((event) {
          _liveKitReconnecting = true;
          if (mounted) setState(() {});
          // The SDK has its own retry loop. Stop it before it can turn into
          // an unbounded app-wide reconnect storm.
          if (event.attempt >= 3 && !_liveKitReconnectStopped) {
            _liveKitReconnectStopped = true;
            unawaited(_stopLiveKitAfterReconnectLimit(room));
          }
        })
        ..on<RoomReconnectedEvent>((_) {
          _liveKitReconnecting = false;
          if (mounted) setState(() {});
          final latestRoom = _room;
          if (latestRoom != null) {
            unawaited(_syncLiveKitPublishPermission(latestRoom));
          }
        })
        ..on<RoomDisconnectedEvent>((event) {
          _liveKitReconnecting = false;
          if (mounted) setState(() {});
          if (!_leaving && !_liveKitReconnectStopped && mounted) {
            _showNotice(context, '语音连接中断', '连接已停止自动重试，请重新进入直播间。');
          }
        });
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _liveAudioBackgroundChannel.invokeMethod<void>('start');
      }
      if (!joinInfo.canPublish) {
        await _startListenerAudioWarmup();
      } else {
        await _stopListenerAudioWarmup();
      }
      _liveKitCanPublish = joinInfo.canPublish;
      // The role in the newly issued token is authoritative. Using the
      // previous room snapshot here makes every later snapshot look like a
      // role change and can trigger an endless reconnect loop.
      _liveKitRole = joinInfo.role;
      var microphoneReady = false;
      if (joinInfo.canPublish) {
        final roomRole = _room?.viewerRole;
        final approvedSpeaker =
            joinInfo.role == 'speaker' && roomRole != 'speaker';
        if (approvedSpeaker && _localMuteOverride == null) {
          if (mounted) {
            setState(() => _muted = false);
          } else {
            _muted = false;
          }
        }
        microphoneReady = await _setLocalMicrophoneEnabledWithRecovery(!_muted);
        if (!microphoneReady && !_muted) {
          throw StateError('LiveKit did not create a local audio track');
        }
      }
      // A server role alone only means permission was granted. Do not let the
      // UI present this participant as connected until this client has both
      // joined LiveKit and successfully initialized its local audio track.
      _liveKitPublishReady = joinInfo.canPublish && (_muted || microphoneReady);
      debugPrint(
        'LiveKit audio engine after local publish: '
        '${AudioManager.instance.audioEngineState}',
      );
      await _setSpeakerOutputPreferred();
      // Approval can arrive while the old listener token is reconnecting. In
      // that race Room.connect succeeds, but the token is still receive-only;
      // recheck the latest snapshot after the connection lock is released so
      // we do not miss the speaker-token refresh.
      if (!joinInfo.canPublish) {
        final latestRoom = _room;
        if (latestRoom != null && _canPublishAudio(latestRoom)) {
          unawaited(
            Future<void>.delayed(const Duration(milliseconds: 300), () {
              if (mounted) unawaited(_syncLiveKitPublishPermission(latestRoom));
            }),
          );
        }
      }
    } catch (error, stackTrace) {
      // Keep the original connect/join failure visible. A disconnect can also
      // time out while unwinding a failed connection, and must not replace the
      // error that explains why Room.connect failed.
      debugPrint('LiveKit connect failed: $error');
      debugPrint('LiveKit URL: ${liveKitUrl ?? '<not received>'}');
      debugPrintStack(stackTrace: stackTrace);
      final room = connectingRoom;
      if (room != null) {
        if (identical(room, _liveKitRoom)) {
          _liveKitRoom = null;
        }
        _liveKitPublishReady = false;
        _liveKitEventListener?.dispose();
        _liveKitEventListener = null;
        _liveKitSpeakingParticipantIds.clear();
        unawaited(_disconnectLiveKitRoomSafely(room));
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        unawaited(_liveAudioBackgroundChannel.invokeMethod<void>('stop'));
      }
      if (mounted && showError) {
        _showNotice(context, '语音连接失败', '无法连接直播语音，请稍后重试。');
      }
    } finally {
      _liveKitConnecting = false;
      if (mounted) setState(() {});
    }
  }

  Room _createLiveKitRoom() {
    return Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioCaptureOptions: _voiceRoomAudioCaptureOptions,
        defaultAudioOutputOptions: AudioOutputOptions(speakerOn: true),
      ),
    );
  }

  Future<void> _disconnectLiveKitRoomSafely(Room? room) async {
    if (room == null) return;
    try {
      await room.disconnect().timeout(const Duration(seconds: 3));
    } catch (error, stackTrace) {
      debugPrint('LiveKit disconnect cleanup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _stopLiveKitAfterReconnectLimit(Room room) async {
    if (!identical(room, _liveKitRoom)) return;
    await room.disconnect();
    if (identical(room, _liveKitRoom)) {
      _liveKitRoom = null;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _liveAudioBackgroundChannel.invokeMethod<void>('stop');
    }
    if (mounted && !_leaving) {
      _showNotice(context, '语音连接中断', '网络不稳定，已停止自动重试，请重新进入直播间。');
    }
  }

  Future<void> _waitForLiveKitReentryCooldown(int liveID) async {
    final leftAt = _liveKitLeftAtByLiveID[liveID];
    if (leftAt == null) return;

    final remaining =
        _liveKitReentryCooldown - DateTime.now().difference(leftAt);
    if (remaining <= Duration.zero) {
      _liveKitLeftAtByLiveID.remove(liveID);
      return;
    }

    if (mounted) {
      setState(() {
        _reentryCoolingDown = true;
        _reentryCooldownSeconds = remaining.inSeconds.ceil();
      });
    }
    while (mounted) {
      final currentRemaining =
          _liveKitReentryCooldown - DateTime.now().difference(leftAt);
      if (currentRemaining <= Duration.zero) break;
      await Future<void>.delayed(
        currentRemaining > const Duration(seconds: 1)
            ? const Duration(seconds: 1)
            : currentRemaining,
      );
      if (mounted) {
        final updatedRemaining =
            _liveKitReentryCooldown - DateTime.now().difference(leftAt);
        setState(
          () => _reentryCooldownSeconds = updatedRemaining.inSeconds.ceil(),
        );
      }
    }
    _liveKitLeftAtByLiveID.remove(liveID);
    if (mounted) {
      setState(() {
        _reentryCoolingDown = false;
        _reentryCooldownSeconds = 0;
      });
    }
  }

  static Future<void> _ensureLiveKitInitialized() {
    return _liveKitInitialization ??= LiveKitClient.initialize(
      initialAudioSessionOptions: _communicationAudioSession,
    );
  }

  Future<void> _configureLiveKitMicrophoneMuteMode() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    await AudioManager.instance.setMicrophoneMuteMode(
      MicrophoneMuteMode.inputMixer,
    );
  }

  Future<void> _prepareLiveKitAudioSession() async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _setSpeakerOutputPreferred();
      return;
    }
    await AudioManager.instance.setAudioSessionOptions(
      // Keep iOS voice-room listeners on the communication session as well.
      // In this app, playback-only sessions can report a subscribed remote
      // track and an active playout engine while producing no audible output.
      _communicationAudioSession,
    );
    await AudioManager.instance.setEngineAvailability(
      AudioEngineAvailability.defaultAvailability,
    );
    await _setSpeakerOutputPreferred();
    debugPrint(
      'LiveKit audio engine before connect: '
      '${AudioManager.instance.audioEngineState}',
    );
    unawaited(_logLiveKitAudioRoute('before-connect'));
  }

  Future<void> _loadRoom({bool silent = false}) async {
    final live = widget.live;
    if (live == null) return;
    if (!silent && mounted) setState(() => _roomLoading = true);
    try {
      final room = await _accountSession.liveRoom(
        live.id,
        joinPassword: widget.joinPassword,
      );
      _applyRoomSnapshot(room);
    } on AccountApiException catch (error) {
      if (!silent && mounted) _showNotice(context, '无法进入直播间', error.message);
    } catch (_) {
      if (!silent && mounted) {
        _showNotice(context, '无法进入直播间', '请检查网络后重试。');
      }
    } finally {
      if (!silent && mounted) setState(() => _roomLoading = false);
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
      const Duration(seconds: 45),
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
    if (state == AppLifecycleState.resumed && _room?.viewerRole == 'host') {
      unawaited(_sendHostHeartbeat());
    }
  }

  Future<void> _connectRealtime({bool refreshRoom = true}) async {
    final live = widget.live;
    if (live == null || !mounted || _leaving) return;
    try {
      if (refreshRoom) await _loadRoom(silent: true);
      final ticket = await _accountSession.liveWebsocketTicket(live.id);
      final channel = WebSocketChannel.connect(
        _liveWebsocketUri(live.id, ticket),
      );
      await _eventSubscription?.cancel();
      await _eventChannel?.sink.close();
      _eventChannel = channel;
      _eventSubscription = channel.stream.listen(
        _handleRealtimeEvent,
        onError: (_) => _scheduleRealtimeReconnect(),
        onDone: _scheduleRealtimeReconnect,
      );
      _reconnectTimer?.cancel();
      _reconnectAttempt = 0;
      _realtimeReconnectStopped = false;
      if (mounted) setState(() => _networkReconnecting = false);
    } on AccountApiException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 409) {
        _reconnectTimer?.cancel();
        if (mounted) setState(() => _networkReconnecting = false);
        return;
      }
      _scheduleRealtimeReconnect();
    } catch (_) {
      _scheduleRealtimeReconnect();
    }
  }

  Uri _liveWebsocketUri(int liveId, String ticket) {
    final apiBase = Uri.parse(const AppConfig().apiBaseUrl);
    final path = apiBase.path.replaceFirst(
      RegExp(r'/api/v1/?$'),
      '/api/v1/lives/$liveId/ws',
    );
    return apiBase.replace(
      scheme: apiBase.scheme == 'https' ? 'wss' : 'ws',
      path: path,
      queryParameters: {'ticket': ticket},
    );
  }

  void _scheduleRealtimeReconnect() {
    if (!mounted ||
        widget.live == null ||
        _leaving ||
        _realtimeReconnectStopped) {
      return;
    }
    if (_reconnectAttempt >= 5) {
      _realtimeReconnectStopped = true;
      if (mounted) {
        setState(() => _networkReconnecting = false);
        _showNotice(context, '弹幕连接中断', '已停止自动重试，请重新进入直播间。');
      }
      return;
    }
    _reconnectTimer?.cancel();
    const retryDelays = [3, 6, 12, 30, 60];
    final delaySeconds = retryDelays[_reconnectAttempt];
    _reconnectAttempt++;
    setState(() => _networkReconnecting = true);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (mounted && !_leaving) unawaited(_connectRealtime());
    });
  }

  void _handleRealtimeEvent(dynamic rawEvent) {
    if (rawEvent is! String) return;
    try {
      final decoded = jsonDecode(rawEvent);
      if (decoded is! Map<String, dynamic>) return;
      final eventType = decoded['type'];
      if (eventType is! String) return;

      if (_networkReconnecting && mounted) {
        setState(() {
          _networkReconnecting = false;
          _reconnectAttempt = 0;
        });
      }

      switch (eventType) {
        case 'room.snapshot':
          final roomJson = decoded['room'];
          if (roomJson is Map<String, dynamic>) {
            _applyRoomSnapshot(LiveRoom.fromJson(roomJson));
          }
        case 'room.audio_mute':
          final audioMutedJson = decoded['audio_muted'];
          if (audioMutedJson is Map<String, dynamic>) {
            _applyAudioMute(audioMutedJson['muted'] as bool? ?? false);
          }
        case 'room.chat_mute':
          final chatMuted = decoded['chat_muted'];
          if (chatMuted is bool) {
            _applyChatMute(chatMuted);
          }
        case 'room.participant_count':
          final participantCount = decoded['participant_count'];
          if (participantCount is num) {
            _applyParticipantCount(participantCount.toInt());
          }
      }
    } on FormatException {
      debugPrint('Ignoring malformed live realtime event');
    } catch (error) {
      debugPrint('Ignoring invalid live realtime event: $error');
    }
  }

  void _applyParticipantCount(int participantCount) {
    final room = _room;
    if (room == null || !mounted) return;
    // Presence events can arrive late or out of order during reconnects. Do
    // not let an invalid server value render a negative audience count.
    final safeParticipantCount = participantCount < 0 ? 0 : participantCount;
    setState(() {
      _room = LiveRoom(
        live: room.live,
        host: room.host,
        hostActive: room.hostActive,
        viewerUserId: room.viewerUserId,
        viewerRole: room.viewerRole,
        participantCount: safeParticipantCount,
        speakers: room.speakers,
        listeners: room.listeners,
        raisedHands: room.raisedHands,
        canRaiseHand: room.canRaiseHand,
        viewerMuted: room.viewerMuted,
        chatMuted: room.chatMuted,
        audioMuted: room.audioMuted,
        checkIn: room.checkIn,
      );
    });
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
      participantCount: room.participantCount,
      speakers: room.speakers
          .map(
            (speaker) => LiveParticipant(
              userId: speaker.userId,
              nickname: speaker.nickname,
              role: speaker.role,
              handRaised: speaker.handRaised,
              muted: muted,
            ),
          )
          .toList(growable: false),
      listeners: room.listeners,
      raisedHands: room.raisedHands,
      canRaiseHand: room.canRaiseHand,
      viewerMuted: room.viewerRole == 'speaker' ? muted : room.viewerMuted,
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
      participantCount: room.participantCount,
      speakers: room.speakers,
      listeners: room.listeners,
      raisedHands: room.raisedHands,
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
    if (room.live.status == 'ended') {
      _closeRoom(true);
      return;
    }
    final displayedRoom = room;
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
    setState(() {
      _room = displayedRoom;
      // A realtime snapshot can arrive before the mute request completes.
      // Keep the user's latest local choice until the server echoes it back.
      _muted = localMuteOverride ?? displayedRoom.viewerMuted;
      _handRaised = room.raisedHands.any(
        (participant) => participant.userId == displayedRoom.viewerUserId,
      );
      if (displayedRoom.chatMuted && displayedRoom.viewerRole != 'host') {
        _emojiPickerVisible = false;
      }
    });
    unawaited(_syncLiveKitPublishPermission(displayedRoom));
    _ensureHostHeartbeat(displayedRoom);
  }

  Future<void> _syncLiveKitPublishPermission(LiveRoom room) async {
    // A stale listener snapshot can arrive after the server has promoted this
    // participant. Do not let it disable an already-publishable connection.
    if (_liveKitCanPublish == true &&
        _liveKitRole == 'speaker' &&
        room.viewerRole == 'listener') {
      return;
    }
    final canPublish = _canPublishAudio(room);
    if (_liveKitRoom == null || _liveKitConnecting || _liveKitReconnecting) {
      return;
    }
    if (canPublish && _liveKitCanPublish != true) {
      // A listener uses the media playback session. Promotion must reconnect
      // with a publishing token after switching to the communication session,
      // which recreates iOS's audio device instead of reusing a stopped one.
      if (_liveKitPermissionReconnectInFlight) return;
      _liveKitPermissionReconnectInFlight = true;
      try {
        await _connectLiveKit(showError: false);
      } finally {
        _liveKitPermissionReconnectInFlight = false;
      }
      return;
    }
    _liveKitCanPublish = canPublish;
    _liveKitRole = room.viewerRole;
    if (!canPublish) {
      _liveKitPublishReady = false;
      await _setLocalMicrophoneEnabled(false);
      return;
    }
    if (_liveKitMicrophoneOperationInFlight) return;
    try {
      _liveKitPublishReady = await _setLocalMicrophoneEnabledWithRecovery(
        !_muted,
      );
      await _setSpeakerOutputPreferred();
      if (mounted) setState(() {});
    } catch (error) {
      _liveKitPublishReady = false;
      // This synchronization is fire-and-forget from room state updates.
      // Surface the failure in logs without producing an unhandled exception;
      // an explicit microphone tap still reports its own failure to the UI.
      debugPrint('LiveKit permission microphone sync failed: $error');
    }
  }

  bool _canPublishAudio(LiveRoom room) {
    // Mute controls the track; the role controls publish permission.
    return room.viewerRole == 'host' || room.viewerRole == 'speaker';
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

  Future<void> _setAudioMute(bool muted) async {
    final live = widget.live;
    if (live == null) return;
    try {
      await _accountSession.setLiveAudioMute(live.id, muted);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '设置失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '设置失败', '请检查网络后重试。');
    }
  }

  Future<void> _toggleMicrophone() async {
    final live = widget.live;
    if (live == null || _microphoneUpdating) return;
    final nextMuted = !_muted;
    _microphoneUpdating = true;
    _localMuteOverride = nextMuted;
    try {
      if (nextMuted) {
        await _setLocalMicrophoneEnabledWithRecovery(false);
        await _accountSession.setLiveParticipantMute(live.id, true);
      } else {
        await _accountSession.setLiveParticipantMute(live.id, false);
        await _setLocalMicrophoneEnabledWithRecovery(true);
      }
      if (mounted) setState(() => _muted = nextMuted);
      final room = _room;
      if (!nextMuted && room != null) {
        // Synchronize the UI snapshot with the local microphone state.
        unawaited(_syncLiveKitPublishPermission(room));
      }
    } on AccountApiException catch (error) {
      _localMuteOverride = null;
      await _restoreMicrophone(!nextMuted);
      if (!mounted) return;
      _showNotice(context, '设置麦克风失败', error.message);
    } catch (_) {
      _localMuteOverride = null;
      await _restoreMicrophone(!nextMuted);
      if (!mounted) return;
      _showNotice(context, '设置麦克风失败', '请检查网络后重试。');
    } finally {
      _microphoneUpdating = false;
    }
  }

  Future<void> _restoreMicrophone(bool muted) async {
    if (!mounted) return;
    setState(() => _muted = muted);
    await _setLocalMicrophoneEnabledWithRecovery(!muted);
  }

  Future<bool> _setLocalMicrophoneEnabledWithRecovery(bool enabled) async {
    if (_liveKitMicrophoneOperationInFlight) return false;
    _liveKitMicrophoneOperationInFlight = true;
    try {
      return await _setLocalMicrophoneEnabled(enabled);
    } catch (error) {
      debugPrint('LiveKit microphone toggle failed, retrying: $error');
      if (defaultTargetPlatform == TargetPlatform.iOS && enabled) {
        // A receive-only listener may still own mediaPlayback when permission
        // changes to speaker. Reconfigure the capture session before retrying;
        // otherwise WebRTC returns -9001 while applying the recorder settings.
        await AudioManager.instance.setAudioSessionOptions(
          _communicationAudioSession,
        );
        await AudioManager.instance.setEngineAvailability(
          AudioEngineAvailability.defaultAvailability,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return await _setLocalMicrophoneEnabled(enabled);
    } finally {
      _liveKitMicrophoneOperationInFlight = false;
    }
  }

  Future<bool> _setLocalMicrophoneEnabled(bool enabled) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (enabled) {
        // The communication session is configured once before Room.connect.
        // Reapplying it on every mute toggle can reset iOS's AudioUnit.
        await AudioManager.instance.setEngineAvailability(
          AudioEngineAvailability.defaultAvailability,
        );
      }
      await _setSpeakerOutputPreferred();
      if (enabled) {
        // WebRTC may reset the iOS route while the audio device starts.
        unawaited(
          Future<void>.delayed(_iosAudioUnitRecoveryDelay, () async {
            if (!mounted) return;
            await _setSpeakerOutputPreferred();
            debugPrint(
              'LiveKit iOS speaker route reapplied: '
              'preferred=${AudioManager.instance.isSpeakerOutputPreferred} '
              'forced=${AudioManager.instance.isSpeakerOutputForced} '
              'engine=${AudioManager.instance.audioEngineState}',
            );
            await _logLiveKitAudioRoute('after-microphone-enable-route-reset');
          }),
        );
      }
    }
    final participant = _liveKitRoom?.localParticipant;
    if (participant == null) return false;
    // Keep iOS WebRTC's AudioUnit alive across mute/unmute. LiveKit's
    // maintainers document that restarting the AudioUnit on the second
    // setMicrophoneEnabled(true) can briefly publish packets with zero audio.
    final publication = await participant.setMicrophoneEnabled(
      enabled,
      audioCaptureOptions: _voiceRoomAudioCaptureOptions,
    );
    final track = publication?.track;
    final effectiveRole = _liveKitRole ?? _room?.viewerRole ?? '<unknown>';
    debugPrint(
      'LiveKit local microphone ${enabled ? 'enabled' : 'disabled'}: '
      'role=$effectiveRole canPublish=$_liveKitCanPublish '
      'publication=${publication?.sid ?? '<none>'} '
      'muted=${publication?.muted} active=${track?.isActive} '
      'processing=ec:${_voiceRoomAudioCaptureOptions.echoCancellation},'
      'ns:${_voiceRoomAudioCaptureOptions.noiseSuppression},'
      'agc:${_voiceRoomAudioCaptureOptions.autoGainControl},'
      'isolation:${_voiceRoomAudioCaptureOptions.voiceIsolation} '
      'engine=${AudioManager.instance.audioEngineState}',
    );
    unawaited(
      _logLiveKitAudioRoute('microphone-${enabled ? 'enabled' : 'disabled'}'),
    );
    if (enabled && track is LocalAudioTrack) {
      debugPrint(
        'LiveKit audio engine after microphone enable: '
        '${AudioManager.instance.audioEngineState}',
      );
      final stats = await track.getSenderStats();
      debugPrint(
        'LiveKit local audio uplink: role=$effectiveRole '
        'bytes=${stats?.bytesSent} packets=${stats?.packetsSent} '
        'audioLevel=${stats?.audioSourceStats?.audioLevel} '
        'totalEnergy=${stats?.audioSourceStats?.totalAudioEnergy} '
        'trackActive=${track.isActive} publicationMuted=${publication?.muted}',
      );
      // The sender is attached asynchronously during SDP negotiation. A
      // first stats read can therefore be empty even though publication
      // succeeded; sample again after the native sender has had time to bind.
      unawaited(
        Future<void>.delayed(const Duration(seconds: 2), () async {
          if (!mounted || !identical(track, publication?.track)) return;
          final delayedStats = await track.getSenderStats();
          debugPrint(
            'LiveKit local audio uplink delayed: role=$effectiveRole '
            'bytes=${delayedStats?.bytesSent} '
            'packets=${delayedStats?.packetsSent} '
            'audioLevel=${delayedStats?.audioSourceStats?.audioLevel} '
            'totalEnergy=${delayedStats?.audioSourceStats?.totalAudioEnergy} '
            'trackActive=${track.isActive} '
            'publicationMuted=${publication?.muted} '
            'engine=${AudioManager.instance.audioEngineState}',
          );
        }),
      );
    }
    return !enabled || track is LocalAudioTrack;
  }

  Future<void> _setSpeakerOutputPreferred() =>
      AudioManager.instance.setSpeakerOutputPreferred(true, force: true);

  Future<void> _startListenerAudioWarmup() async {
    if (defaultTargetPlatform != TargetPlatform.iOS ||
        _listenerAudioWarmupTrack != null) {
      return;
    }
    try {
      final track = await LocalAudioTrack.create(_voiceRoomAudioCaptureOptions);
      await track.start();
      _listenerAudioWarmupTrack = track;
      debugPrint(
        'LiveKit iOS listener audio warmup started: '
        'trackActive=${track.isActive} '
        'engine=${AudioManager.instance.audioEngineState}',
      );
    } catch (error) {
      debugPrint('LiveKit iOS listener audio warmup failed: $error');
    }
  }

  Future<void> _stopListenerAudioWarmup() async {
    final track = _listenerAudioWarmupTrack;
    _listenerAudioWarmupTrack = null;
    if (track == null) return;
    try {
      await track.stop();
      track.dispose();
      debugPrint('LiveKit iOS listener audio warmup stopped');
    } catch (error) {
      debugPrint('LiveKit iOS listener audio warmup cleanup failed: $error');
    }
  }

  Future<void> _logRemoteAudioTrackStats(
    RemoteAudioTrack track,
    String publicationSid,
    bool publicationMuted,
  ) async {
    Future<void> log(String sample) async {
      final stats = await track.getReceiverStats();
      debugPrint(
        'LiveKit remote audio downlink $sample: '
        'publication=$publicationSid '
        'trackActive=${track.isActive} '
        'publicationMuted=$publicationMuted '
        'packets=${stats?.packetsReceived} '
        'bytes=${stats?.bytesReceived} '
        'audioLevel=${stats?.audioSourceStats?.audioLevel} '
        'totalEnergy=${stats?.totalAudioEnergy}',
      );
      final receiver = track.receiver;
      if (receiver == null) return;
      final rawReports = await receiver.getStats();
      for (final report in rawReports.where(
        (report) => report.type == 'inbound-rtp' || report.type == 'track',
      )) {
        final values = report.values;
        debugPrint(
          'LiveKit remote audio raw stats $sample: '
          'publication=$publicationSid type=${report.type} '
          'enabled=${track.mediaStreamTrack.enabled} '
          'packetsReceived=${values['packetsReceived']} '
          'bytesReceived=${values['bytesReceived']} '
          'audioLevel=${values['audioLevel']} '
          'totalAudioEnergy=${values['totalAudioEnergy']} '
          'totalSamplesDuration=${values['totalSamplesDuration']}',
        );
      }
    }

    try {
      await log('immediate');
      await Future<void>.delayed(const Duration(seconds: 2));
      await log('delayed');
    } catch (error) {
      debugPrint(
        'LiveKit remote audio downlink stats failed: '
        'publication=$publicationSid error=$error',
      );
    }
  }

  Future<void> _logLiveKitAudioRoute(String reason) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final route = await _liveAudioRouteChannel.invokeMethod<Object?>(
        'routeInfo',
      );
      debugPrint('LiveKit iOS audio route: reason=$reason route=$route');
    } catch (error) {
      debugPrint(
        'LiveKit iOS audio route read failed: reason=$reason error=$error',
      );
    }
  }

  Future<void> _logLiveKitAudioRouteAfterSpeakerReset(String reason) async {
    await _setSpeakerOutputPreferred();
    await _logLiveKitAudioRoute(reason);
    debugPrint(
      'LiveKit audio engine after $reason: '
      '${AudioManager.instance.audioEngineState}',
    );
  }

  Future<void> _confirmSpeakerMute(LiveParticipant speaker) async {
    final shouldMute = !speaker.muted;
    final actionLabel = shouldMute ? '静音' : '解除静音';
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text('$actionLabel ${speaker.nickname}'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('是否要$actionLabel该用户？'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            textStyle: TextStyle(color: widget.palette.accent),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: shouldMute,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final live = widget.live;
    if (live == null) return;
    try {
      await _accountSession.setLiveSpeakerMute(
        live.id,
        speaker.userId,
        shouldMute,
      );
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '设置麦克风失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '设置麦克风失败', '请检查网络后重试。');
    }
  }

  Future<void> _setChatMute(bool muted) async {
    final live = widget.live;
    if (live == null) return;
    try {
      await _accountSession.setLiveChatMute(live.id, muted);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '设置失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '设置失败', '请检查网络后重试。');
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

  void _showRaisedHandRequests() {
    final room = _room;
    if (room == null || room.raisedHands.isEmpty) return;
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
              users: room.raisedHands,
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
                unawaited(_rejectAllSpeakerRequests(room.raisedHands));
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
    final speakers = _room?.speakers ?? const <LiveParticipant>[];
    final hasSpeakers = speakers.isNotEmpty;
    final chatMuted = room?.chatMuted ?? false;
    final audioMuted = room?.audioMuted ?? false;
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
              onPressed: () {
                Navigator.of(sheetContext).pop();
                unawaited(_setAudioMute(!audioMuted));
              },
              child: _hostActionLabel(audioMuted ? '解除全员静音' : '全员静音'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                unawaited(_setChatMute(!chatMuted));
              },
              child: _hostActionLabel(chatMuted ? '解除全员禁言' : '全员禁言'),
            ),
            if (hasSpeakers)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _showHostTransferPicker(speakers);
                },
                child: _hostActionLabel('转让主持人'),
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

  Future<void> _disconnectLiveKitForLeave() async {
    final liveID = widget.live?.id;
    if (liveID != null) {
      _liveKitLeftAtByLiveID[liveID] = DateTime.now();
    }
    final room = _liveKitRoom;
    _liveKitRoom = null;
    _liveKitEventListener?.dispose();
    _liveKitEventListener = null;
    await _stopListenerAudioWarmup();
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_liveAudioBackgroundChannel.invokeMethod<void>('stop'));
    }
    if (room == null) return;
    try {
      // Tell LiveKit immediately that this participant has left before the UI
      // permits another room join. Do not hold navigation indefinitely if the
      // network is already unavailable.
      await room.disconnect().timeout(const Duration(seconds: 2));
    } catch (_) {
      // A lost network cannot send Leave; the server's disconnect timeout
      // remains the fallback cleanup path.
    }
  }

  void _closeRoom([bool? result]) {
    if (!mounted || _closingRoom) return;
    _closingRoom = true;
    unawaited(_disconnectLiveKitForLeave());
    setState(() {
      _allowPop = true;
      _leaving = true;
    });
    Navigator.of(context).pop(result);
  }

  void _showHostTransferPicker(List<LiveParticipant> speakers) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('转让主持人'),
        message: const Text('选择一位正在发言的成员成为新主持人。直播不会中断，你将成为普通成员。'),
        actions: speakers
            .map((speaker) => _transferHostAction(sheetContext, speaker))
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  CupertinoActionSheetAction _transferHostAction(
    BuildContext sheetContext,
    LiveParticipant speaker,
  ) => CupertinoActionSheetAction(
    onPressed: () {
      Navigator.of(sheetContext).pop();
      unawaited(_transferHost(speaker));
    },
    child: Text(speaker.nickname),
  );

  Future<void> _transferHost(LiveParticipant speaker) async {
    final live = widget.live;
    if (live == null) return;
    try {
      await _accountSession.transferLiveHost(live.id, speaker.userId);
      _closeRoom();
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '转让失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '转让失败', '请检查网络后重试。');
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
    _reconnectTimer?.cancel();
    _handRaiseNoticeTimer?.cancel();
    _checkInTimer?.cancel();
    _hostHeartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _messageRefreshTimer?.cancel();
    unawaited(_eventSubscription?.cancel());
    unawaited(_eventChannel?.sink.close());
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
        reliable: false,
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
    if (payloadBytes > _maxLiveMessageBytes) {
      _showNotice(context, '发送失败', '弹幕内容过长，请控制在 512 字节以内。');
      return false;
    }

    final now = DateTime.now();
    final lastSentAt = _lastMessageSentAt;
    if (lastSentAt != null &&
        now.difference(lastSentAt) < _minLiveMessageInterval) {
      _showNotice(context, '发送太快', '请稍后再发送。');
      return false;
    }

    final windowStartedAt = _messageRateWindowStartedAt;
    if (windowStartedAt == null ||
        now.difference(windowStartedAt) >= _liveMessageRateWindow) {
      _messageRateWindowStartedAt = now;
      _messageRateWindowCount = 0;
    }
    if (_messageRateWindowCount >= _maxLiveMessagesPerWindow) {
      _showNotice(context, '发送太快', '房间弹幕较多，请稍后再试。');
      return false;
    }

    _lastMessageSentAt = now;
    _messageRateWindowCount++;
    return true;
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
    _appendMessages([
      LiveMessage(
        id: -now.microsecondsSinceEpoch,
        nickname: nickname,
        text: text.trim(),
        createdAt: now,
      ),
    ]);
  }

  void _appendMessages(Iterable<LiveMessage> incomingMessages) {
    var hasNewMessages = false;
    for (final message in incomingMessages) {
      if (!_knownMessageIds.add(message.id)) continue;
      _messages.addLast(message);
      hasNewMessages = true;

      while (_messages.length > _maxLiveMessageCount) {
        final evictedMessage = _messages.removeFirst();
        _knownMessageIds.remove(evictedMessage.id);
      }
    }
    if (!hasNewMessages || !mounted) return;
    _scheduleMessageRefresh();
  }

  void _scheduleMessageRefresh() {
    if (_messageRefreshTimer != null) return;

    // Coalesce bursts of incoming chat messages into one rebuild. The queue is
    // updated immediately, while the UI is refreshed at most once per window.
    _messageRefreshTimer = Timer(_liveMessageRefreshInterval, () {
      _messageRefreshTimer = null;
      if (mounted) setState(() {});
    });
  }

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
        onShowRaisedHandRequests: _showRaisedHandRequests,
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

  @override
  Widget build(BuildContext context) {
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
    final canToggleMicrophone = canSpeak && !audioMuted;
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
                            liveMessages: _messages.toList(growable: false),
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
