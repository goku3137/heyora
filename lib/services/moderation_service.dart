import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

class ModerationService {
  static final ModerationService instance = ModerationService._internal();
  ModerationService._internal();

  final Set<String> _blockedUserIds = {};
  bool _hasAccepted18Plus = false;

  bool get hasAccepted18Plus => _hasAccepted18Plus;
  Set<String> get blockedUserIds => Set.unmodifiable(_blockedUserIds);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _hasAccepted18Plus = prefs.getBool('heyora_18plus_accepted') ?? false;

    final blockedList = prefs.getStringList('heyora_blocked_users') ?? [];
    _blockedUserIds.addAll(blockedList);
  }

  Future<void> accept18Plus() async {
    _hasAccepted18Plus = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('heyora_18plus_accepted', true);
  }

  /// 1-Tap Report & Block user (accessible directly to anonymous guests)
  Future<void> reportAndBlockUser({
    required String reportedUserId,
    required String? callId,
    required String category,
    String? description,
  }) async {
    _blockedUserIds.add(reportedUserId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('heyora_blocked_users', _blockedUserIds.toList());

    final client = SupabaseService.instance.client;
    if (client != null && SupabaseService.instance.isInitialized) {
      try {
        await client.rpc('report_and_block_user', params: {
          'p_reported_id': reportedUserId,
          'p_call_id': callId,
          'p_category': category,
          'p_description': description,
        });
      } catch (e) {
        debugPrint('Report RPC notice: $e');
      }
    }
  }

  /// Submit upvote or downvote with backend anti-abuse integrity
  Future<bool> submitVote({
    required String targetUserId,
    required String? callId,
    required String voteType, // 'upvote' or 'downvote'
  }) async {
    final client = SupabaseService.instance.client;
    if (client != null && SupabaseService.instance.isInitialized) {
      try {
        final response = await client.rpc('submit_vote', params: {
          'p_target_user_id': targetUserId,
          'p_call_id': callId,
          'p_vote_type': voteType,
        });
        final data = Map<String, dynamic>.from(response as Map);
        return data['success'] == true;
      } catch (e) {
        debugPrint('Vote RPC notice: $e');
        return false;
      }
    }
    return true;
  }

  bool isBlocked(String userId) => _blockedUserIds.contains(userId);
}
