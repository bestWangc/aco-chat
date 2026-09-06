part of 'aco_design_shell.dart';

// LiveKit audio-session APIs are experimental in the current SDK. The
// extension intentionally calls State methods to keep the room state machine
// in one object while this file owns the transport implementation.
// ignore_for_file: experimental_member_use, invalid_use_of_protected_member

Future<void> _initializeLiveKitClient() {
  return _VoiceRoomPageState
      ._liveKitInitialization ??= LiveKitClient.initialize(
    initialAudioSessionOptions: _VoiceRoomPageState._communicationAudioSession,
  );
}

extension _VoiceRoomLiveKit on _VoiceRoomPageState {
  Future<void> _connectLiveKit({bool showError = true}) async {
    final live = widget.live;
    if (live == null || !mounted || _leaving || _liveKitConnecting) return;
    _liveKitConnecting = true;
    setState(() {});
    _liveKitReconnectStopped = false;
    Room? connectingRoom;
    String? liveKitUrl;
    try {
      await _initializeLiveKitClient();
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
        ..on<DataReceivedEvent>(_handleLiveKitData)
        ..on<TrackSubscribedEvent>((event) {
          if (event.track is RemoteAudioTrack) {
            debugPrint(
              'LiveKit remote audio subscribed before connect listener: '
              '${event.participant.identity}/${event.publication.sid}',
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
        if (joinInfo.url == _VoiceRoomPageState._liveKitFallbackUrl) rethrow;
        debugPrint(
          'LiveKit primary connect failed ($primaryError), '
          'retrying $_VoiceRoomPageState._liveKitFallbackUrl',
        );
        await _disconnectLiveKitRoomSafely(room);
        room = _createLiveKitRoom();
        connectingRoom = room;
        liveKitUrl = _VoiceRoomPageState._liveKitFallbackUrl;
        preConnectListener.dispose();
        preConnectListener = room.createListener()
          ..on<DataReceivedEvent>(_handleLiveKitData)
          ..on<TrackSubscribedEvent>((event) {
            if (event.track is RemoteAudioTrack) {
              debugPrint(
                'LiveKit remote audio subscribed before connect listener: '
                '${event.participant.identity}/${event.publication.sid}',
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
        await room.connect(
          _VoiceRoomPageState._liveKitFallbackUrl,
          joinInfo.token,
        );
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
        ..on<LocalTrackPublishedEvent>((event) {
          if (event.publication.kind == TrackType.AUDIO) {
            debugPrint(
              '[LIVEKIT诊断][本地发布] sid=${event.publication.sid} '
              'muted=${event.publication.muted} '
              'active=${event.publication.track?.isActive}',
            );
          }
        })
        ..on<LocalTrackUnpublishedEvent>((event) {
          if (event.publication.kind == TrackType.AUDIO) {
            debugPrint(
              '[LIVEKIT诊断][本地取消发布] sid=${event.publication.sid} '
              'muted=${event.publication.muted} '
              'active=${event.publication.track?.isActive}',
            );
          }
        })
        ..on<ParticipantPermissionsUpdatedEvent>((event) {
          debugPrint(
            '[LIVEKIT诊断][本地权限变化] '
            'canPublish=${event.permissions.canPublish} '
            '旧canPublish=${event.oldPermissions.canPublish} '
            'canPublishData=${event.permissions.canPublishData}',
          );
        })
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
        ..on<TrackMutedEvent>((event) {
          if (event.publication.kind == TrackType.AUDIO) {
            debugPrint(
              '[LIVEKIT诊断][远端静音] '
              'participant=${event.participant.identity} '
              'sid=${event.publication.sid}',
            );
          }
        })
        ..on<TrackUnmutedEvent>((event) {
          if (event.publication.kind == TrackType.AUDIO) {
            debugPrint(
              '[LIVEKIT诊断][远端取消静音] '
              'participant=${event.participant.identity} '
              'sid=${event.publication.sid}',
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
            _showNotice(context, '语音连接中断', '连接已停止自动重试，请重新进入会议。');
          }
        });
      if (_supportsBackgroundAudio) {
        await _VoiceRoomPageState._liveAudioBackgroundChannel
            .invokeMethod<void>('start', <String, Object?>{
              'title': live.title,
            });
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
      if (_supportsBackgroundAudio) {
        unawaited(
          _VoiceRoomPageState._liveAudioBackgroundChannel.invokeMethod<void>(
            'stop',
          ),
        );
      }
      if (mounted && showError) {
        _showNotice(context, '语音连接失败', '无法连接会议语音，请稍后重试。');
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
        defaultAudioCaptureOptions:
            _VoiceRoomPageState._voiceRoomAudioCaptureOptions,
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
    if (_supportsBackgroundAudio) {
      await _VoiceRoomPageState._liveAudioBackgroundChannel.invokeMethod<void>(
        'stop',
      );
    }
    if (mounted && !_leaving) {
      _showNotice(context, '语音连接中断', '网络不稳定，已停止自动重试，请重新进入会议。');
    }
  }

  Future<void> _waitForLiveKitReentryCooldown(int liveID) async {
    final leftAt = _VoiceRoomPageState._liveKitLeftAtByLiveID[liveID];
    if (leftAt == null) return;

    final remaining =
        _VoiceRoomPageState._liveKitReentryCooldown -
        DateTime.now().difference(leftAt);
    if (remaining <= Duration.zero) {
      _VoiceRoomPageState._liveKitLeftAtByLiveID.remove(liveID);
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
          _VoiceRoomPageState._liveKitReentryCooldown -
          DateTime.now().difference(leftAt);
      if (currentRemaining <= Duration.zero) break;
      await Future<void>.delayed(
        currentRemaining > const Duration(seconds: 1)
            ? const Duration(seconds: 1)
            : currentRemaining,
      );
      if (mounted) {
        final updatedRemaining =
            _VoiceRoomPageState._liveKitReentryCooldown -
            DateTime.now().difference(leftAt);
        setState(
          () => _reentryCooldownSeconds = updatedRemaining.inSeconds.ceil(),
        );
      }
    }
    _VoiceRoomPageState._liveKitLeftAtByLiveID.remove(liveID);
    if (mounted) {
      setState(() {
        _reentryCoolingDown = false;
        _reentryCooldownSeconds = 0;
      });
    }
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
    if (_supportsBackgroundAudio) {
      await _setSpeakerOutputPreferred();
      return;
    }
    await AudioManager.instance.setAudioSessionOptions(
      // Keep iOS voice-room listeners on the communication session as well.
      // In this app, playback-only sessions can report a subscribed remote
      // track and an active playout engine while producing no audible output.
      _VoiceRoomPageState._communicationAudioSession,
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
    // A receive-only token can still report the speaker role while approval
    // propagation is catching up. Once this connection has adopted that same
    // role, retrying on every room snapshot creates an endless reconnect loop.
    if (canPublish &&
        _liveKitCanPublish != true &&
        _liveKitRole != room.viewerRole) {
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
      _liveKitPublishReady = await _setLocalMicrophoneMuted(_muted);
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

  Future<void> _setAudioMute(bool muted) async {
    final live = widget.live;
    if (live == null) return;
    try {
      await _accountSession.setLiveAudioMute(live.id, muted);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '设置失败', error.localizedMessage);
      rethrow;
    } catch (_) {
      if (mounted) _showNotice(context, '设置失败', '请检查网络后重试。');
      rethrow;
    }
  }

  Future<void> _toggleMicrophone() async {
    final live = widget.live;
    if (live == null || _microphoneUpdating) return;
    final nextMuted = !_muted;
    _microphoneUpdating = true;
    _localMuteOverride = nextMuted;
    debugPrint(
      'LiveKit mute toggle: requested muted=$nextMuted '
      'beforeEngine=${AudioManager.instance.audioEngineState}',
    );
    unawaited(_logLiveKitAudioRoute('mute-toggle-before'));
    unawaited(_logAllRemoteAudioTrackStats('开关麦前'));
    try {
      if (nextMuted) {
        // Persist the state first, then mute the existing publication so the
        // LiveKit audio session and remote playback stay alive.
        await _accountSession.setLiveParticipantMute(live.id, true);
        debugPrint(
          'LiveKit mute toggle: server muted=true '
          'engine=${AudioManager.instance.audioEngineState}',
        );
        unawaited(_logLiveKitAudioRoute('mute-toggle-after-server'));
        await _setLocalMicrophoneMuted(true);
      } else {
        await _accountSession.setLiveParticipantMute(live.id, false);
        debugPrint(
          'LiveKit mute toggle: server muted=false '
          'engine=${AudioManager.instance.audioEngineState}',
        );
        unawaited(_logLiveKitAudioRoute('mute-toggle-after-server'));
        await _setLocalMicrophoneMuted(false);
      }
      debugPrint(
        'LiveKit mute toggle: local complete muted=$nextMuted '
        'engine=${AudioManager.instance.audioEngineState}',
      );
      unawaited(_logLiveKitAudioRoute('mute-toggle-after-local'));
      unawaited(_logAllRemoteAudioTrackStats('本地静音完成'));
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 1500), () async {
          if (!mounted) return;
          debugPrint(
            'LiveKit mute toggle: delayed check muted=$nextMuted '
            'engine=${AudioManager.instance.audioEngineState}',
          );
          await _logLiveKitAudioRoute('mute-toggle-delayed');
          await _logAllRemoteAudioTrackStats('延迟检查');
        }),
      );
      if (mounted) setState(() => _muted = nextMuted);
      final room = _room;
      if (!nextMuted && room != null) {
        // Synchronize the UI snapshot with the local microphone state.
        unawaited(_syncLiveKitPublishPermission(room));
      }
    } on AccountApiException catch (error) {
      _localMuteOverride = null;
      await _restoreMicrophone(!nextMuted);
      if (error.isLiveParticipantMissing) {
        unawaited(_loadRoom(silent: true));
      }
      if (!mounted) return;
      _showNotice(context, '设置麦克风失败', error.localizedMessage);
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

  Future<bool> _setLocalMicrophoneMuted(bool muted) async {
    final participant = _liveKitRoom?.localParticipant;
    final publication = participant?.audioTrackPublications.firstOrNull;
    if (publication == null) {
      return _setLocalMicrophoneEnabledWithRecovery(!muted);
    }
    if (publication.muted == muted) return true;
    if (_liveKitMicrophoneOperationInFlight) return false;
    _liveKitMicrophoneOperationInFlight = true;
    try {
      if (muted) {
        await publication.mute(stopOnMute: false);
      } else {
        await publication.unmute(stopOnMute: false);
      }
      return true;
    } finally {
      _liveKitMicrophoneOperationInFlight = false;
    }
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
          _VoiceRoomPageState._communicationAudioSession,
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
          Future<void>.delayed(
            _VoiceRoomPageState._iosAudioUnitRecoveryDelay,
            () async {
              if (!mounted) return;
              await _setSpeakerOutputPreferred();
              debugPrint(
                'LiveKit iOS speaker route reapplied: '
                'preferred=${AudioManager.instance.isSpeakerOutputPreferred} '
                'forced=${AudioManager.instance.isSpeakerOutputForced} '
                'engine=${AudioManager.instance.audioEngineState}',
              );
              await _logLiveKitAudioRoute(
                'after-microphone-enable-route-reset',
              );
            },
          ),
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
      audioCaptureOptions: _VoiceRoomPageState._voiceRoomAudioCaptureOptions,
    );
    final track = publication?.track;
    final effectiveRole = _liveKitRole ?? _room?.viewerRole ?? '<unknown>';
    debugPrint(
      'LiveKit local microphone ${enabled ? 'enabled' : 'disabled'}: '
      'role=$effectiveRole canPublish=$_liveKitCanPublish '
      'publication=${publication?.sid ?? '<none>'} '
      'muted=${publication?.muted} active=${track?.isActive} '
      'processing=ec:${_VoiceRoomPageState._voiceRoomAudioCaptureOptions.echoCancellation},'
      'ns:${_VoiceRoomPageState._voiceRoomAudioCaptureOptions.noiseSuppression},'
      'agc:${_VoiceRoomPageState._voiceRoomAudioCaptureOptions.autoGainControl},'
      'isolation:${_VoiceRoomPageState._voiceRoomAudioCaptureOptions.voiceIsolation} '
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

  Future<void> _setSpeakerOutputPreferred() async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(true, force: true);
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _VoiceRoomPageState._liveAudioRouteChannel.invokeMethod<bool>(
          'forceSpeaker',
        );
      }
      debugPrint(
        'LiveKit speaker output requested: platform=$defaultTargetPlatform '
        'preferred=${AudioManager.instance.isSpeakerOutputPreferred} '
        'forced=${AudioManager.instance.isSpeakerOutputForced} '
        'engine=${AudioManager.instance.audioEngineState}',
      );
    } catch (error, stackTrace) {
      debugPrint('LiveKit speaker output request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _startListenerAudioWarmup() async {
    if (defaultTargetPlatform != TargetPlatform.iOS ||
        _listenerAudioWarmupTrack != null) {
      return;
    }
    try {
      final track = await LocalAudioTrack.create(
        _VoiceRoomPageState._voiceRoomAudioCaptureOptions,
      );
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
        '[LIVEKIT诊断][远端接收统计][$sample] '
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
          '[LIVEKIT诊断][远端原始统计][$sample] '
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

  Future<void> _logAllRemoteAudioTrackStats(String sample) async {
    final room = _liveKitRoom;
    if (room == null) return;
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications) {
        final track = publication.track;
        if (track == null) {
          debugPrint(
            '[LIVEKIT诊断][远端下行][$sample] '
            'participant=${participant.identity} publication=${publication.sid} '
            'track=<none> subscribed=${publication.subscribed} '
            'muted=${publication.muted}',
          );
          continue;
        }
        debugPrint(
          '[LIVEKIT诊断][远端状态][$sample] '
          'participant=${participant.identity} publication=${publication.sid} '
          'subscribed=${publication.subscribed} muted=${publication.muted} '
          'trackActive=${track.isActive}',
        );
        await _logRemoteAudioTrackStats(
          track,
          publication.sid,
          publication.muted,
        );
      }
    }
  }

  Future<void> _logLiveKitAudioRoute(String reason) async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      final route = await _VoiceRoomPageState._liveAudioRouteChannel
          .invokeMethod<Object?>('routeInfo');
      debugPrint(
        '[LIVEKIT诊断][音频路由] platform=$defaultTargetPlatform reason=$reason route=$route',
      );
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

  Future<void> _disconnectLiveKitForLeave() async {
    final liveID = widget.live?.id;
    if (liveID != null) {
      _VoiceRoomPageState._liveKitLeftAtByLiveID[liveID] = DateTime.now();
    }
    final room = _liveKitRoom;
    _liveKitRoom = null;
    _liveKitEventListener?.dispose();
    _liveKitEventListener = null;
    await _stopListenerAudioWarmup();
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(
        _VoiceRoomPageState._liveAudioBackgroundChannel.invokeMethod<void>(
          'stop',
        ),
      );
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
}
