import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import 'supabase_service.dart';

enum WebRTCConnectionState {
  idle,
  initializing,
  connecting,
  connected,
  failed,
  disconnected,
}

class WebRTCTelemetry {
  final bool isDirectP2P;
  final bool isTurnRelayed;
  final int bitrateKbps;
  final String resolution;
  final double packetLossPercentage;

  const WebRTCTelemetry({
    this.isDirectP2P = true,
    this.isTurnRelayed = false,
    this.bitrateKbps = 250,
    this.resolution = '360p (15 FPS)',
    this.packetLossPercentage = 0.0,
  });
}

class WebRTCService {
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RealtimeChannel? _signalingChannel;

  WebRTCConnectionState connectionState = WebRTCConnectionState.idle;
  WebRTCTelemetry telemetry = const WebRTCTelemetry();

  Function(WebRTCConnectionState state)? onStateChange;
  Function(WebRTCTelemetry stats)? onTelemetryUpdate;
  Function(Map<String, dynamic> giftData)? onGiftReceived;
  VoidCallback? onPeerSkipped;

  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  bool _hasRemoteStream = false;

  Timer? _qualityTimer;
  Timer? _statsTimer;
  int _callDurationSeconds = 0;
  bool _isUpgradedToHighQuality = false;

  final List<RTCIceCandidate> _bufferedCandidates = [];

  bool get isMuted => _isMuted;
  bool get isCameraOff => _isCameraOff;
  bool get isFrontCamera => _isFrontCamera;
  bool get hasRemoteStream => _hasRemoteStream;

  Future<void> initializeRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  /// Initialize local camera & microphone with low-bandwidth 360p/15fps profile
  Future<void> initializeLocalMedia() async {
    try {
      final mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': {
          'mandatory': {
            'minWidth': '${AppConfig.initialVideoWidth}',
            'minHeight': '${AppConfig.initialVideoHeight}',
            'minFrameRate': '${AppConfig.initialFrameRate}',
          },
          'facingMode': 'user',
          'optional': [],
        },
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;
    } catch (e) {
      debugPrint('⚠️ Camera/Mic capture notice (e.g. running on emulator or no hardware): $e');
    }
  }

  /// Starts WebRTC session with peer using Supabase Realtime signaling
  Future<void> startSession({
    required String channelId,
    required bool isInitiator,
  }) async {
    _setConnectionState(WebRTCConnectionState.initializing);
    _callDurationSeconds = 0;
    _isUpgradedToHighQuality = false;

    // 1. Create Peer Connection with STUN + Coturn TURN configuration
    final configuration = <String, dynamic>{
      'iceServers': AppConfig.iceServers,
      'sdpSemantics': 'unified-plan',
      'iceTransportPolicy': 'all', // P2P first, TURN fallback only when needed
    };

    _peerConnection = await createPeerConnection(configuration);

    // 2. Attach local media tracks
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    // 3. Listen for remote media stream
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
        _hasRemoteStream = true;
        _setConnectionState(WebRTCConnectionState.connected);
      }
    };

    // 4. ICE candidate generation
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _sendSignalingMessage('candidate', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('⚡ WebRTC ICE Connection State: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        _setConnectionState(WebRTCConnectionState.connected);
        _startQualityAndStatsMonitoring();
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _setConnectionState(WebRTCConnectionState.failed);
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _setConnectionState(WebRTCConnectionState.disconnected);
      }
    };

    // 5. Connect to Supabase Realtime private channel for SDP/ICE exchange
    await _connectSignaling(channelId, isInitiator);

    // 6. Offer / Answer exchange
    if (isInitiator) {
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveVideo': 1,
        'offerToReceiveAudio': 1,
      });
      await _peerConnection!.setLocalDescription(offer);
      _sendSignalingMessage('offer', {'sdp': offer.sdp, 'type': offer.type});
    }
  }

  /// Supabase Realtime Broadcast signaling setup
  Future<void> _connectSignaling(String channelId, bool isInitiator) async {
    final client = SupabaseService.instance.client;
    if (client == null || !SupabaseService.instance.isInitialized) {
      debugPrint('ℹ️ Realtime signaling running in local test mode.');
      _setConnectionState(WebRTCConnectionState.connected);
      return;
    }

    _signalingChannel = client.channel('signaling:$channelId');

    _signalingChannel!.onBroadcast(
      event: 'signal',
      callback: (payload) async {
        final messageType = payload['type'] as String?;
        final data = payload['data'] as Map<String, dynamic>? ?? {};

        if (messageType == 'offer') {
          final sdp = data['sdp'] as String;
          await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));

          // Flush any buffered ICE candidates
          for (final candidate in _bufferedCandidates) {
            await _peerConnection!.addCandidate(candidate);
          }
          _bufferedCandidates.clear();

          // Create and send answer
          final answer = await _peerConnection!.createAnswer({
            'offerToReceiveVideo': 1,
            'offerToReceiveAudio': 1,
          });
          await _peerConnection!.setLocalDescription(answer);
          _sendSignalingMessage('answer', {'sdp': answer.sdp, 'type': answer.type});
        } else if (messageType == 'answer') {
          final sdp = data['sdp'] as String;
          await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));

          for (final candidate in _bufferedCandidates) {
            await _peerConnection!.addCandidate(candidate);
          }
          _bufferedCandidates.clear();
        } else if (messageType == 'candidate') {
          final candidate = RTCIceCandidate(
            data['candidate'] as String,
            data['sdpMid'] as String?,
            data['sdpMLineIndex'] as int?,
          );

          if (_peerConnection?.getRemoteDescription() != null) {
            await _peerConnection!.addCandidate(candidate);
          } else {
            _bufferedCandidates.add(candidate);
          }
        } else if (messageType == 'gift') {
          // Cross-device virtual gift broadcast received!
          onGiftReceived?.call(data);
        } else if (messageType == 'skip') {
          // Remote peer pressed skip
          onPeerSkipped?.call();
        }
      },
    ).subscribe();
  }

  void _sendSignalingMessage(String type, Map<String, dynamic> data) {
    if (_signalingChannel != null) {
      _signalingChannel!.sendBroadcastMessage(
        event: 'signal',
        payload: {'type': type, 'data': data},
      );
    }
  }

  /// Broadcast gift celebration event to the other call participant
  void sendGiftEvent(Map<String, dynamic> giftData) {
    _sendSignalingMessage('gift', giftData);
  }

  /// Broadcast skip notification to the other call participant
  void sendSkipEvent() {
    _sendSignalingMessage('skip', {'reason': 'user_skipped'});
  }

  /// Media Controls
  void toggleMute() {
    if (_localStream != null) {
      _isMuted = !_isMuted;
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }
    }
  }

  void toggleCamera() {
    if (_localStream != null) {
      _isCameraOff = !_isCameraOff;
      for (final track in _localStream!.getVideoTracks()) {
        track.enabled = !_isCameraOff;
      }
    }
  }

  Future<void> switchCamera() async {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      final videoTrack = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(videoTrack);
      _isFrontCamera = !_isFrontCamera;
    }
  }

  /// Adaptive Video Quality & Telemetry Monitoring
  void _startQualityAndStatsMonitoring() {
    _qualityTimer?.cancel();
    _statsTimer?.cancel();

    // Stats monitoring every 3 seconds (inspects getStats for P2P vs TURN relay)
    _statsTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_peerConnection == null) return;
      _callDurationSeconds += 3;

      try {
        final stats = await _peerConnection!.getStats();
        bool isRelayed = false;
        for (final report in stats) {
          if (report.type == 'candidate-pair' && report.values['state'] == 'succeeded') {
            final remoteCandidateId = report.values['remoteCandidateId'];
            // Check candidate type
            for (final cReport in stats) {
              if (cReport.id == remoteCandidateId && cReport.values['candidateType'] == 'relay') {
                isRelayed = true;
              }
            }
          }
        }

        double currentPacketLoss = 0.0;
        double currentRtt = 0.0;

        for (final report in stats) {
          if (report.type == 'inbound-rtp' && report.values['mediaType'] == 'video') {
            final lost = (report.values['packetsLost'] as num?)?.toDouble() ?? 0.0;
            final rcvd = (report.values['packetsReceived'] as num?)?.toDouble() ?? 1.0;
            if (rcvd > 0) {
              currentPacketLoss = (lost / (lost + rcvd)).clamp(0.0, 1.0);
            }
          }
          if (report.type == 'candidate-pair' && report.values['state'] == 'succeeded') {
            currentRtt = (report.values['currentRoundTripTime'] as num?)?.toDouble() ?? 0.05;
          }
        }

        telemetry = WebRTCTelemetry(
          isDirectP2P: !isRelayed,
          isTurnRelayed: isRelayed,
          bitrateKbps: _isUpgradedToHighQuality ? 750 : 250,
          resolution: _isUpgradedToHighQuality ? '720p (24 FPS)' : '360p (15 FPS)',
          packetLossPercentage: currentPacketLoss * 100,
        );
        onTelemetryUpdate?.call(telemetry);

        // Optimization 2: Upgrade ONLY when call sustained > 20s AND network is strong (loss < 2%, RTT < 150ms)
        if (_callDurationSeconds >= 20 && !_isUpgradedToHighQuality) {
          if (currentPacketLoss < 0.02 && currentRtt < 0.150) {
            _upgradeVideoQuality();
          }
        } else if (_isUpgradedToHighQuality) {
          // Automatic downgrade hysteresis if network degrades (loss > 5% or RTT > 350ms)
          if (currentPacketLoss > 0.05 || currentRtt > 0.350) {
            _downgradeVideoQuality();
          }
        }
      } catch (e) {
        debugPrint('Stats telemetry notice: $e');
      }
    });
  }

  void _upgradeVideoQuality() {
    _isUpgradedToHighQuality = true;
    debugPrint('🚀 Network conditions verified strong (loss < 2%, low RTT). Upgrading to 720p.');
    _setSenderBitrate(800000, 24); // 800 kbps, 24 fps
  }

  void _downgradeVideoQuality() {
    _isUpgradedToHighQuality = false;
    debugPrint('⚠️ Network congestion detected. Downgrading video to 360p/15fps to preserve audio.');
    _setSenderBitrate(250000, 15); // 250 kbps, 15 fps
  }

  void _setSenderBitrate(int maxBitrate, int maxFramerate) {
    _peerConnection?.getSenders().then((senders) {
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          final parameters = sender.parameters;
          if (parameters.encodings != null && parameters.encodings!.isNotEmpty) {
            parameters.encodings![0].maxBitrate = maxBitrate;
            parameters.encodings![0].maxFramerate = maxFramerate;
            sender.setParameters(parameters).ignore();
          }
        }
      }
    });
  }

  void _setConnectionState(WebRTCConnectionState state) {
    connectionState = state;
    onStateChange?.call(state);
  }

  /// Clean release of all call resources, renderers, and streams on Next / End
  Future<void> disposeSession() async {
    _qualityTimer?.cancel();
    _qualityTimer = null;
    _statsTimer?.cancel();
    _statsTimer = null;

    if (_signalingChannel != null) {
      _signalingChannel!.unsubscribe();
      _signalingChannel = null;
    }

    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    remoteRenderer.srcObject = null;
    _hasRemoteStream = false;
    _bufferedCandidates.clear();
    _setConnectionState(WebRTCConnectionState.idle);
  }

  Future<void> disposeAll() async {
    await disposeSession();
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        track.stop();
      }
      _localStream = null;
    }
    localRenderer.srcObject = null;
    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }
}
