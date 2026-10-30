class LeaderboardEntry {
  final int rank;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int score;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.score,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntry.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final uid = json['user_id']?.toString() ?? '';
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: uid,
      displayName: json['display_name'] as String? ?? 'Anonymous Star',
      avatarUrl: json['avatar_url'] as String?,
      score: (json['score'] as num?)?.toInt() ?? 0,
      isCurrentUser: currentUserId != null && uid == currentUserId,
    );
  }
}
