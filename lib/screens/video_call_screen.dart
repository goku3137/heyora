import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/gift.dart';
import '../models/user_state.dart';
import '../services/matchmaking_service.dart';
import '../services/moderation_service.dart';
import '../services/webrtc_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gift_bottom_sheet.dart';
import '../widgets/google_linking_sheet.dart';
import '../widgets/report_dialog.dart';

class VideoCallScreen extends StatefulWidget {
  final UserState userState;
  final String genderFilter;

  const VideoCallScreen({
    super.key,
    required this.userState,
    this.genderFilter = 'random',
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final WebRTCService _webrtcService = WebRTCService();
  final MatchmakingService _matchmaking = MatchmakingService.instance;

  // Stages: 1 = Handshake / Connecting, 2 = Connected (Safety Blur), 3 = Revealing / Live
  bool _isConnecting = true;
  String _statusMessage = 'Finding an online stranger...';
  int _handshakeCountdown = 2;
  int _blurCountdown = 3;

  Timer? _handshakeTimer;
  Timer? _countdownTimer;
  Timer? _callTimer;
  Timer? _giftDismissTimer;

  int _callDurationSeconds = 0;
  Gift? _activeGiftCelebration;
  bool _isSenderCelebration = true;

  String _currentChannelId = '';
  String? _currentCallId;
  String _strangerId = 'Stranger';
  String _strangerName = 'Stranger_942';
  String _strangerLocation = 'Live Video Discovery';
  int _strangerKarma = 100;
  bool _isSkipping = false;
  String? _userVote; // 'upvote' or 'downvote'

  WebRTCTelemetry _telemetry = const WebRTCTelemetry();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initWebRTCAndStartCall();
  }

  Future<void> _initWebRTCAndStartCall() async {
    await _webrtcService.initializeRenderers();
    await _webrtcService.initializeLocalMedia();

    _webrtcService.onTelemetryUpdate = (stats) {
      if (mounted) setState(() => _telemetry = stats);
    };

    _webrtcService.onGiftReceived = (giftMap) {
      if (mounted) {
        final gift = Gift.fromMap(giftMap);
        _triggerGiftCelebration(gift, isSender: false);
      }
    };

    _webrtcService.onPeerSkipped = () {
      if (mounted && !_isSkipping) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.black87,
            content: Text('⚡ Stranger skipped. Connecting with next stranger...'),
            duration: Duration(milliseconds: 900),
          ),
        );
        _nextStranger();
      }
    };

    _startMatchSession();
  }

  Future<void> _startMatchSession() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Matching with verified strangers...';
      _handshakeCountdown = 2;
      _blurCountdown = 3;
      _callDurationSeconds = 0;
      _userVote = null;
    });

    try {
      // 1. Enter atomic matchmaking queue
      final match = await _matchmaking.startMatchmaking(
        genderFilter: widget.genderFilter,
      );

      _currentChannelId = match.channelId;
      _currentCallId = match.callId;
      _strangerId = match.peerId;
      _strangerName = match.peerName;
      _strangerLocation = match.peerLocation;
      _strangerKarma = match.peerKarma;

      // 2. Stage 1 Handshake countdown (2 seconds)
      setState(() {
        _statusMessage = 'Stranger found! Handshaking in $_handshakeCountdown...';
      });

      _handshakeTimer?.cancel();
      _handshakeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_handshakeCountdown > 1) {
          if (mounted) {
            setState(() {
              _handshakeCountdown--;
              _statusMessage = 'Handshaking in $_handshakeCountdown...';
            });
          }
        } else {
          timer.cancel();
          _startMediaStream(match.isInitiator);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _statusMessage = 'No match found. Tap Next to retry.';
        });
      }
    }
  }

  Future<void> _startMediaStream(bool isInitiator) async {
    if (!mounted) return;
    setState(() {
      _isConnecting = false;
      _blurCountdown = 3;
    });

    // Start WebRTC session and signaling
    await _webrtcService.startSession(
      channelId: _currentChannelId,
      isInitiator: isInitiator,
    );

    // 3. Stage 2: 3-Second Safety Blur countdown (OmeTV Protocol)
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_blurCountdown > 0) {
        if (mounted) setState(() => _blurCountdown--);
      } else {
        timer.cancel();
      }
    });

    // Call duration timer
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _callDurationSeconds++);
    });
  }

  Future<void> _nextStranger() async {
    if (_isSkipping) return;
    _isSkipping = true;

    // Send skip event to peer so they seamlessly transition too
    _webrtcService.sendSkipEvent();

    // Release old call session
    _handshakeTimer?.cancel();
    _countdownTimer?.cancel();
    _callTimer?.cancel();

    if (_currentChannelId.isNotEmpty) {
      _matchmaking.endCall(_currentChannelId, reason: 'user_skipped');
    }
    await _webrtcService.disposeSession();

    await _startMatchSession();
    _isSkipping = false;
  }

  void _triggerGiftCelebration(Gift gift, {required bool isSender}) {
    setState(() {
      _activeGiftCelebration = gift;
      _isSenderCelebration = isSender;
    });

    if (!isSender) {
      widget.userState.receiveGift(gift);
    }

    _giftDismissTimer?.cancel();
    _giftDismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _activeGiftCelebration = null);
      }
    });
  }

  Future<void> _handleVote(String voteType) async {
    if (_userVote != null) return;

    // Action-gating: If guest, prompt to link Google account to keep vote genuine!
    if (widget.userState.isAnonymous) {
      GoogleLinkingSheet.show(
        context,
        title: 'Keep your HeyOra account safe',
        description: 'Sign in with Google to vote and help keep the community genuine.',
        onLinked: () {
          _submitVote(voteType);
        },
      );
      return;
    }

    _submitVote(voteType);
  }

  Future<void> _submitVote(String voteType) async {
    setState(() => _userVote = voteType);
    await ModerationService.instance.submitVote(
      targetUserId: _strangerId,
      callId: _currentCallId,
      voteType: voteType,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: voteType == 'upvote' ? Colors.green : Colors.redAccent,
          content: Text(
            voteType == 'upvote'
                ? '👍 Upvoted $_strangerName!'
                : '👎 Downvoted $_strangerName.',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      debugPrint('📱 App backgrounded/detached: Auto-terminating call session to save bandwidth and prevent ghost matching.');
      _webrtcService.sendSkipEvent();
      if (_currentChannelId.isNotEmpty) {
        _matchmaking.endCall(_currentChannelId, reason: 'app_backgrounded');
      }
      _webrtcService.disposeSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _handshakeTimer?.cancel();
    _countdownTimer?.cancel();
    _callTimer?.cancel();
    _giftDismissTimer?.cancel();

    if (_currentChannelId.isNotEmpty) {
      _matchmaking.endCall(_currentChannelId, reason: 'user_left');
    }
    _webrtcService.disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mins = (_callDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_callDurationSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Remote Stranger Video / WebRTC Remote Canvas
          Positioned.fill(
            child: Container(
              color: AppColors.cinema.background,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Real WebRTC Remote Video Stream
                  if (_webrtcService.hasRemoteStream)
                    Positioned.fill(
                      child: RTCVideoView(
                        _webrtcService.remoteRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    )
                  else
                    // Connecting / Handshaking / Avatar Placeholder
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.cinema.surface,
                              border: Border.all(
                                color: AppColors.cinema.divider,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _strangerName.isNotEmpty ? _strangerName[0] : 'S',
                                style: TextStyle(
                                  color: AppColors.cinema.textPrimary,
                                  fontSize: 44,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _strangerName,
                            style: TextStyle(
                              color: AppColors.cinema.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_on, color: AppColors.cinema.textSecondary, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _strangerLocation,
                                style: TextStyle(color: AppColors.cinema.textSecondary, fontSize: 14),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _strangerKarma >= 80
                                      ? Colors.greenAccent.withValues(alpha: 0.15)
                                      : Colors.amberAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _strangerKarma >= 80 ? Colors.greenAccent : Colors.amberAccent,
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _strangerKarma >= 80 ? Icons.star_rounded : Icons.shield_outlined,
                                      color: _strangerKarma >= 80 ? Colors.greenAccent : Colors.amberAccent,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$_strangerKarma Karma',
                                      style: TextStyle(
                                        color: _strangerKarma >= 80 ? Colors.greenAccent : Colors.amberAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_isConnecting)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.cinema.primaryCTA,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _statusMessage,
                                    style: TextStyle(color: AppColors.cinema.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                  // 3-Second Blur Handshake Overlay (OmeTV Safety Protocol)
                  if (!_isConnecting && _blurCountdown > 0)
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.55),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                              decoration: BoxDecoration(
                                color: AppColors.cinema.surface.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: AppColors.cinema.primaryCTA.withValues(alpha: 0.5)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '🛡️ 3-Sec Safety Handshake',
                                    style: TextStyle(
                                      color: AppColors.cinema.primaryCTA,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Revealing video in $_blurCountdown...',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Inspect motion and hit Next to skip bad actors.',
                                    style: TextStyle(color: Colors.white60, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. Gift Celebration Animation Banner
          if (_activeGiftCelebration != null)
            Positioned(
              top: 130,
              left: 20,
              right: 20,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 350),
                builder: (context, val, child) {
                  return Transform.scale(
                    scale: val,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.cinema.primaryCTA, AppColors.cinema.secondaryAccent],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cinema.primaryCTA.withValues(alpha: 0.35),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Text(_activeGiftCelebration!.emoji, style: const TextStyle(fontSize: 40)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isSenderCelebration
                                      ? 'You sent ${_activeGiftCelebration!.name}!'
                                      : 'Received ${_activeGiftCelebration!.name}!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '+${_activeGiftCelebration!.diamondValue} 💎 Popularity Earned',
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // 3. Top Status Bar (Duration, Connection Telemetry, Report, Close)
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Live call duration & Network Telemetry Pill
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$mins:$secs',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // WebRTC Telemetry Pill (P2P vs TURN Relay, Resolution)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _telemetry.isDirectP2P
                              ? Colors.greenAccent.withValues(alpha: 0.5)
                              : Colors.amberAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _telemetry.isDirectP2P ? Icons.bolt_rounded : Icons.sync_rounded,
                            color: _telemetry.isDirectP2P ? Colors.greenAccent : Colors.amberAccent,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _telemetry.isDirectP2P ? 'P2P (${_telemetry.resolution})' : 'TURN',
                            style: TextStyle(
                              color: _telemetry.isDirectP2P ? Colors.greenAccent : Colors.amberAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                Row(
                  children: [
                    // Upvote / Downvote buttons (Action-Gated Google Linking)
                    IconButton(
                      icon: Icon(
                        Icons.thumb_up_rounded,
                        color: _userVote == 'upvote' ? Colors.greenAccent : Colors.white60,
                        size: 20,
                      ),
                      onPressed: () => _handleVote('upvote'),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.thumb_down_rounded,
                        color: _userVote == 'downvote' ? Colors.redAccent : Colors.white60,
                        size: 20,
                      ),
                      onPressed: () => _handleVote('downvote'),
                    ),

                    // Report & Block Button (1-Tap UGC Protection)
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
                      ),
                      tooltip: 'Report & Block',
                      onPressed: () {
                        ReportDialog.show(
                          context,
                          strangerId: _strangerName,
                          onReported: (reason) {
                            widget.userState.blockUser(
                              _strangerId,
                              callId: _currentCallId,
                              category: reason,
                            );
                            _nextStranger();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.red,
                                content: Text('⚠️ $_strangerName reported for "$reason" and permanently blocked.'),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    // End call / Exit
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. Local User Camera PiP (Picture-in-Picture)
          Positioned(
            top: 110,
            right: 16,
            child: Container(
              width: 105,
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.cinema.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cinema.divider, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    // Real Local Camera WebRTC View
                    RTCVideoView(
                      _webrtcService.localRenderer,
                      mirror: _webrtcService.isFrontCamera,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),

                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () async {
                          await _webrtcService.switchCamera();
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. In-Call Floating Bottom Action Bar
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mute mic
                FloatingActionButton.small(
                  heroTag: 'mic_btn',
                  backgroundColor: _webrtcService.isMuted ? Colors.redAccent : Colors.white24,
                  onPressed: () {
                    _webrtcService.toggleMute();
                    setState(() {});
                  },
                  child: Icon(
                    _webrtcService.isMuted ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                  ),
                ),

                // 🛑 SKIP TO NEXT STRANGER (Central Big Button - Solar Coral)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cinema.primaryCTA,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 10,
                  ),
                  onPressed: _nextStranger,
                  icon: const Icon(Icons.skip_next_rounded, size: 28),
                  label: const Text(
                    'NEXT STRANGER',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                  ),
                ),

                // 🎁 Send Gift Button
                FloatingActionButton.small(
                  heroTag: 'gift_btn',
                  backgroundColor: AppColors.cinema.secondaryAccent,
                  onPressed: () {
                    GiftBottomSheet.show(
                      context,
                      userState: widget.userState,
                      onSendGift: (gift) {
                        _webrtcService.sendGiftEvent(gift.toMap());
                        _triggerGiftCelebration(gift, isSender: true);
                      },
                      onWatchAd: () {},
                    );
                  },
                  child: const Text('🎁', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
