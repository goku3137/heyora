import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'supabase_service.dart';

class MatchResult {
  final String channelId;
  final String callId;
  final String peerId;
  final String peerName;
  final String peerLocation;
  final bool isInitiator;
  final int peerKarma;

  MatchResult({
    required this.channelId,
    required this.callId,
    required this.peerId,
    required this.peerName,
    required this.peerLocation,
    required this.isInitiator,
    this.peerKarma = 100,
  });
}

class MatchmakingService {
  static final MatchmakingService instance = MatchmakingService._internal();
  MatchmakingService._internal();

  RealtimeChannel? _queueSubscription;
  Completer<MatchResult>? _matchCompleter;
  Timer? _queueTimeoutTimer;

  /// Enters atomic matchmaking queue
  Future<MatchResult> startMatchmaking({String genderFilter = 'random'}) async {
    final supabase = SupabaseService.instance;
    final client = supabase.client;

    // Local fallback if Supabase cloud is not configured
    if (!supabase.isInitialized || client == null) {
      await Future.delayed(const Duration(milliseconds: 1200));
      final mockCallId = const Uuid().v4();
      final mockChannelId = 'call_local_${const Uuid().v4().substring(0, 8)}';
      return MatchResult(
        channelId: mockChannelId,
        callId: mockCallId,
        peerId: 'peer_${const Uuid().v4().substring(0, 6)}',
        peerName: 'Stranger_${const Uuid().v4().substring(0, 4)}',
        peerLocation: 'Bangalore, India',
        isInitiator: true,
      );
    }

    try {
      // 1. Call atomic PostgreSQL RPC function
      final response = await client.rpc(
        'enter_match_queue',
        params: {'p_preferred_gender': genderFilter},
      );

      final data = Map<String, dynamic>.from(response as Map);

      if (data['status'] == 'matched') {
        // Instant match! Another user was already waiting in queue
        return MatchResult(
          channelId: data['channel_id'] as String,
          callId: data['call_id'] as String,
          peerId: data['peer_id'] as String,
          peerName: 'Stranger_${(data['peer_id'] as String).substring(0, 4)}',
          peerLocation: 'Live Video Peer',
          isInitiator: data['is_initiator'] as bool? ?? false,
          peerKarma: (data['peer_karma'] as int?) ?? 100,
        );
      }

      // 2. Waiting in queue: Listen for Realtime match pairing event
      _matchCompleter = Completer<MatchResult>();
      final myUserId = supabase.currentUserId;

      _queueSubscription = client
          .channel('public:match_queue:user_id=eq.$myUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'match_queue',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: myUserId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord['status'] == 'matched' &&
                  !_matchCompleter!.isCompleted) {
                _cleanupQueueListener();
                _matchCompleter!.complete(
                  MatchResult(
                    channelId: newRecord['channel_id'] as String,
                    callId: const Uuid().v4(),
                    peerId: (newRecord['matched_user_id'] as String?) ?? 'peer_matched',
                    peerName: 'Stranger_${(newRecord['matched_user_id'] as String? ?? '987').substring(0, 4)}',
                    peerLocation: 'Live Video Peer',
                    isInitiator: true, // User A who was waiting acts as WebRTC offer initiator
                  ),
                );
              }
            },
          )
          .subscribe();

      // Timeout after 30 seconds if no match found
      _queueTimeoutTimer = Timer(const Duration(seconds: 30), () {
        if (_matchCompleter != null && !_matchCompleter!.isCompleted) {
          cancelMatchmaking();
          _matchCompleter!.completeError(
            TimeoutException('No online strangers found in queue. Please retry!'),
          );
        }
      });

      return await _matchCompleter!.future;
    } catch (e) {
      debugPrint('⚠️ Matchmaking error: $e');
      _cleanupQueueListener();
      rethrow;
    }
  }

  /// Cancel queue entry
  void cancelMatchmaking() {
    _cleanupQueueListener();
    final client = SupabaseService.instance.client;
    if (client != null && SupabaseService.instance.isInitialized) {
      client.rpc('leave_match_queue').ignore();
    }
  }

  /// Inform backend that call ended
  void endCall(String channelId, {String reason = 'user_skipped'}) {
    final client = SupabaseService.instance.client;
    if (client != null && SupabaseService.instance.isInitialized) {
      client.rpc('end_call', params: {
        'p_channel_id': channelId,
        'p_reason': reason,
      }).ignore();
    }
  }

  void _cleanupQueueListener() {
    _queueTimeoutTimer?.cancel();
    _queueTimeoutTimer = null;
    if (_queueSubscription != null) {
      _queueSubscription!.unsubscribe();
      _queueSubscription = null;
    }
  }
}
