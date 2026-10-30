import 'package:flutter/foundation.dart';
import '../models/leaderboard_entry.dart';
import 'supabase_service.dart';

enum LeaderboardCategory {
  stars, // Earned diamonds (Creators)
  gifters, // Spent coins (Supporters / Fans)
}

enum LeaderboardTimeframe {
  daily, // Resets every 24h at midnight UTC
  weekly, // Resets every Sunday at midnight UTC
  allTime, // Permanent Hall of Fame
}

class LeaderboardService {
  static final LeaderboardService instance = LeaderboardService._internal();
  LeaderboardService._internal();

  /// Fetches leaderboard rankings from Supabase RPC, falling back to dynamic simulated data if offline.
  Future<List<LeaderboardEntry>> getLeaderboard({
    required LeaderboardCategory category,
    required LeaderboardTimeframe timeframe,
    int limit = 50,
  }) async {
    final client = SupabaseService.instance.client;
    final currentUid = SupabaseService.instance.currentUserId;

    final categoryKey = category == LeaderboardCategory.stars ? 'stars' : 'gifters';
    final timeframeKey = switch (timeframe) {
      LeaderboardTimeframe.daily => 'daily',
      LeaderboardTimeframe.weekly => 'weekly',
      LeaderboardTimeframe.allTime => 'all_time',
    };

    if (client != null && SupabaseService.instance.isInitialized) {
      try {
        final response = await client.rpc('get_leaderboard', params: {
          'p_category': categoryKey,
          'p_timeframe': timeframeKey,
          'p_limit': limit,
        });

        if (response is List && response.isNotEmpty) {
          return response
              .map((item) => LeaderboardEntry.fromJson(
                    Map<String, dynamic>.from(item as Map),
                    currentUserId: currentUid,
                  ))
              .toList();
        }
      } catch (e) {
        debugPrint('⚠️ Supabase get_leaderboard notice: $e (Falling back to simulated data)');
      }
    }

    // Dynamic offline fallback with realistic community scores
    return _generateMockLeaderboard(category, timeframe, currentUid);
  }

  /// Calculates remaining duration until next reset (UTC)
  Duration getTimeUntilReset(LeaderboardTimeframe timeframe) {
    final now = DateTime.now().toUtc();
    if (timeframe == LeaderboardTimeframe.daily) {
      final tomorrowUtc = DateTime.utc(now.year, now.month, now.day + 1);
      return tomorrowUtc.difference(now);
    } else if (timeframe == LeaderboardTimeframe.weekly) {
      // Days until next Sunday midnight
      final daysUntilSunday = (7 - now.weekday) % 7;
      final nextSundayMidnight = DateTime.utc(
        now.year,
        now.month,
        now.day + (daysUntilSunday == 0 ? 7 : daysUntilSunday),
      );
      return nextSundayMidnight.difference(now);
    }
    return Duration.zero;
  }

  /// Generates realistic leaderboard contenders
  List<LeaderboardEntry> _generateMockLeaderboard(
    LeaderboardCategory category,
    LeaderboardTimeframe timeframe,
    String currentUserId,
  ) {
    final multiplier = switch (timeframe) {
      LeaderboardTimeframe.daily => 1,
      LeaderboardTimeframe.weekly => 5,
      LeaderboardTimeframe.allTime => 22,
    };

    final isStars = category == LeaderboardCategory.stars;

    final baseNames = isStars
        ? [
            'Luna_Aura',
            'Chloe.Live',
            'BellaStar',
            'Maya_Sky',
            'Zoe_Tokyo',
            'Aria_Vibes',
            'Elena_Rose',
            'Mia_Glow',
            'Sophia_Charm',
            'Nova_Spark',
            'Ruby_Echo',
            'Lily_Sun',
            'Kira_Moon',
            'Amber_Wave',
            'Daisy_Day',
          ]
        : [
            'King_Arthur_VIP',
            'CryptoWhale_07',
            'Phantom_Lord',
            'DiamondHands',
            'Apex_Titan',
            'Neon_Baron',
            'GoldenKnight',
            'Cyber_Chief',
            'Lord_Vader',
            'Shadow_Master',
            'Starlight_Don',
            'Alpha_Wolf',
            'Blaze_Rider',
            'Vortex_Prime',
            'Zenith_VIP',
          ];

    final baseScores = isStars
        ? [3420, 2850, 2190, 1780, 1420, 1150, 980, 840, 720, 610, 520, 440, 390, 310, 270]
        : [15400, 12800, 9750, 7600, 6200, 5100, 4300, 3700, 3200, 2800, 2400, 2100, 1850, 1600, 1350];

    final entries = <LeaderboardEntry>[];

    for (var i = 0; i < baseNames.length; i++) {
      entries.add(LeaderboardEntry(
        rank: i + 1,
        userId: 'mock_user_$i',
        displayName: baseNames[i],
        score: baseScores[i] * multiplier,
        isCurrentUser: false,
      ));
    }

    return entries;
  }
}
