import 'dart:async';
import 'package:flutter/material.dart';
import '../models/leaderboard_entry.dart';
import '../models/user_state.dart';
import '../services/leaderboard_service.dart';
import '../theme/app_colors.dart';
import '../widgets/coin_purchase_sheet.dart';

class LeaderboardScreen extends StatefulWidget {
  final UserState userState;

  const LeaderboardScreen({super.key, required this.userState});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  LeaderboardCategory _selectedCategory = LeaderboardCategory.stars;
  LeaderboardTimeframe _selectedTimeframe = LeaderboardTimeframe.daily;

  List<LeaderboardEntry> _entries = [];
  bool _isLoading = true;
  Timer? _countdownTimer;
  Duration _timeUntilReset = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _updateResetTime();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateResetTime();
      }
    });
  }

  void _updateResetTime() {
    setState(() {
      _timeUntilReset = LeaderboardService.instance.getTimeUntilReset(_selectedTimeframe);
    });
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final data = await LeaderboardService.instance.getLeaderboard(
      category: _selectedCategory,
      timeframe: _selectedTimeframe,
    );
    if (mounted) {
      setState(() {
        _entries = data;
        _isLoading = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    if (_selectedTimeframe == LeaderboardTimeframe.allTime) {
      return 'Permanent Hall of Fame';
    }
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (days > 0) {
      return '${days}d ${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${hours.toString().padLeft(2, '0')}h : ${minutes.toString().padLeft(2, '0')}m : ${seconds.toString().padLeft(2, '0')}s';
  }

  String _formatScore(int score) {
    if (score >= 1000000) {
      return '${(score / 1000000).toStringAsFixed(1)}M';
    } else if (score >= 10000) {
      return '${(score / 1000).toStringAsFixed(1)}K';
    }
    return score.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isStars = _selectedCategory == LeaderboardCategory.stars;
    final unitIcon = isStars ? '💎' : '🪙';
    final unitLabel = isStars ? 'Diamonds' : 'Coins';

    // Separate Top 3 from remaining
    LeaderboardEntry? first = _entries.isNotEmpty ? _entries[0] : null;
    LeaderboardEntry? second = _entries.length > 1 ? _entries[1] : null;
    LeaderboardEntry? third = _entries.length > 2 ? _entries[2] : null;
    List<LeaderboardEntry> runnersUp = _entries.length > 3 ? _entries.sublist(3) : [];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆 ', style: TextStyle(fontSize: 20)),
            Text(
              'Leaderboard',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline_rounded, color: colors.textSecondary, size: 22),
            onPressed: () => _showRulesDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Category Switch (Stars 💎 vs Gifters 🎁)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCategoryTab(
                        context: context,
                        title: 'Top Stars 💎',
                        subtitle: 'Earned Fans',
                        isSelected: _selectedCategory == LeaderboardCategory.stars,
                        activeGradient: [colors.primaryCTA, colors.secondaryAccent],
                        onTap: () {
                          if (_selectedCategory != LeaderboardCategory.stars) {
                            setState(() => _selectedCategory = LeaderboardCategory.stars);
                            _fetchData();
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildCategoryTab(
                        context: context,
                        title: 'Top Gifters 🎁',
                        subtitle: 'Generous VIPs',
                        isSelected: _selectedCategory == LeaderboardCategory.gifters,
                        activeGradient: [colors.premiumGold, colors.primaryCTA],
                        onTap: () {
                          if (_selectedCategory != LeaderboardCategory.gifters) {
                            setState(() => _selectedCategory = LeaderboardCategory.gifters);
                            _fetchData();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Timeframe Selection Pills (Daily ⚡, Weekly 🏆, All-Time 👑)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  _buildTimeframePill(context, 'Daily ⚡', LeaderboardTimeframe.daily),
                  const SizedBox(width: 8),
                  _buildTimeframePill(context, 'Weekly 🏆', LeaderboardTimeframe.weekly),
                  const SizedBox(width: 8),
                  _buildTimeframePill(context, 'All-Time 👑', LeaderboardTimeframe.allTime),
                ],
              ),
            ),

            // 3. Live Reset Countdown Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.divider),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedTimeframe == LeaderboardTimeframe.allTime
                          ? Icons.military_tech_rounded
                          : Icons.timer_outlined,
                      color: colors.premiumGold,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedTimeframe == LeaderboardTimeframe.allTime ? 'Rankings:' : 'Next Reset:',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      _formatDuration(_timeUntilReset),
                      style: TextStyle(
                        color: colors.premiumGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Main Scrollable List (Podium + Rank Cards)
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: colors.primaryCTA),
                    )
                  : RefreshIndicator(
                      color: colors.primaryCTA,
                      backgroundColor: colors.surface,
                      onRefresh: _fetchData,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        children: [
                          // 🥇 Podium Section (Top 3)
                          if (first != null) ...[
                            _buildPodium(context, first, second, third, unitIcon),
                            const SizedBox(height: 24),
                          ],

                          // 🏅 Section Header for Ranks 4+
                          if (runnersUp.isNotEmpty) ...[
                            Row(
                              children: [
                                Text(
                                  'Contenders (4 - 50)',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Divider(color: colors.divider)),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],

                          // List of rank 4-50
                          ...runnersUp.map(
                            (entry) => _buildRankTile(context, entry, unitIcon),
                          ),

                          const SizedBox(height: 90), // Bottom sheet spacing
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),

      // 5. Sticky Bottom Bar ("Your Rank & Status")
      bottomSheet: _buildUserStandingBar(context, isStars, unitIcon, unitLabel),
    );
  }

  // --- Sub-Widgets ---

  Widget _buildCategoryTab({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isSelected,
    required List<Color> activeGradient,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isSelected ? LinearGradient(colors: activeGradient) : null,
          color: isSelected ? null : Colors.transparent,
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : colors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? Colors.white.withValues(alpha: 0.85) : colors.textSecondary.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeframePill(BuildContext context, String label, LeaderboardTimeframe timeframe) {
    final colors = AppColors.of(context);
    final isSelected = _selectedTimeframe == timeframe;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTimeframe != timeframe) {
            setState(() => _selectedTimeframe = timeframe);
            _fetchData();
            _updateResetTime();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.primaryCTA.withValues(alpha: 0.12) : colors.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? colors.primaryCTA : colors.divider,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? colors.primaryCTA : colors.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodium(
    BuildContext context,
    LeaderboardEntry first,
    LeaderboardEntry? second,
    LeaderboardEntry? third,
    String unitIcon,
  ) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // #2 Silver (Left)
        if (second != null)
          Expanded(
            child: _buildPodiumColumn(
              context: context,
              entry: second,
              rank: 2,
              crownColor: const Color(0xFF9E9E9E),
              podiumHeight: 120,
              unitIcon: unitIcon,
              gradient: const [Color(0xFF8A95A5), Color(0xFF4B5563)],
            ),
          )
        else
          const Expanded(child: SizedBox()),

        const SizedBox(width: 12),

        // #1 Gold (Center, Taller, Glowing)
        Expanded(
          child: _buildPodiumColumn(
            context: context,
            entry: first,
            rank: 1,
            crownColor: colors.premiumGold,
            podiumHeight: 155,
            unitIcon: unitIcon,
            isCenterFirst: true,
            gradient: [colors.premiumGold, colors.primaryCTA],
          ),
        ),

        const SizedBox(width: 12),

        // #3 Bronze (Right)
        if (third != null)
          Expanded(
            child: _buildPodiumColumn(
              context: context,
              entry: third,
              rank: 3,
              crownColor: const Color(0xFFCD7F32),
              podiumHeight: 95,
              unitIcon: unitIcon,
              gradient: const [Color(0xFFB87333), Color(0xFF6E3F1A)],
            ),
          )
        else
          const Expanded(child: SizedBox()),
      ],
    );
  }

  Widget _buildPodiumColumn({
    required BuildContext context,
    required LeaderboardEntry entry,
    required int rank,
    required Color crownColor,
    required double podiumHeight,
    required String unitIcon,
    required List<Color> gradient,
    bool isCenterFirst = false,
  }) {
    final colors = AppColors.of(context);
    final avatarSize = isCenterFirst ? 68.0 : 54.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown Icon
        Text(
          rank == 1 ? '👑' : (rank == 2 ? '🥈' : '🥉'),
          style: TextStyle(fontSize: isCenterFirst ? 26 : 20),
        ),
        const SizedBox(height: 2),

        // Avatar with Glowing Ring
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: crownColor, width: isCenterFirst ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: crownColor.withValues(alpha: isCenterFirst ? 0.45 : 0.25),
                blurRadius: isCenterFirst ? 16 : 8,
                spreadRadius: 1,
              ),
            ],
            color: colors.surfaceCard,
          ),
          alignment: Alignment.center,
          child: Text(
            entry.displayName.isNotEmpty ? entry.displayName[0].toUpperCase() : '?',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: isCenterFirst ? 24 : 18,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Name
        Text(
          entry.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: isCenterFirst ? FontWeight.bold : FontWeight.w600,
            fontSize: isCenterFirst ? 13 : 11,
          ),
        ),

        // Score Pill
        Container(
          margin: const EdgeInsets.only(top: 4, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: crownColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(unitIcon, style: const TextStyle(fontSize: 10)),
              const SizedBox(width: 3),
              Text(
                _formatScore(entry.score),
                style: TextStyle(
                  color: crownColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),

        // The Physical Podium Pillar
        Container(
          height: podiumHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            gradient: LinearGradient(
              colors: [
                gradient[0].withValues(alpha: 0.85),
                gradient[1].withValues(alpha: 0.45),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(color: crownColor.withValues(alpha: 0.4)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '#$rank',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: isCenterFirst ? 24 : 18,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankTile(BuildContext context, LeaderboardEntry entry, String unitIcon) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? colors.primaryCTA.withValues(alpha: 0.12)
            : colors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: entry.isCurrentUser
              ? colors.primaryCTA.withValues(alpha: 0.6)
              : colors.divider,
        ),
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                color: entry.rank <= 10 ? colors.primaryCTA : colors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Mini Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.surface,
            child: Text(
              entry.displayName.isNotEmpty ? entry.displayName[0].toUpperCase() : '?',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // User Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (entry.isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.primaryCTA.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'YOU',
                          style: TextStyle(
                            color: colors.primaryCTA,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  entry.rank <= 10 ? 'VIP Star' : 'Member',
                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),

          // Score
          Row(
            children: [
              Text(unitIcon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                _formatScore(entry.score),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserStandingBar(BuildContext context, bool isStars, String unitIcon, String unitLabel) {
    final colors = AppColors.of(context);
    final userScore = isStars ? widget.userState.diamonds : widget.userState.coins;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.6 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(color: colors.divider),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.primaryCTA.withValues(alpha: 0.15),
            child: Icon(Icons.person, color: colors.primaryCTA, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Standing',
                style: TextStyle(color: colors.textSecondary, fontSize: 11),
              ),
              Row(
                children: [
                  Text(unitIcon, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    _formatScore(userScore),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unitLabel,
                    style: TextStyle(color: colors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isStars ? colors.primaryCTA : colors.premiumGold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              if (isStars) {
                // Return to home and start matching to earn diamonds
                Navigator.pop(context);
              } else {
                // Open coin purchase sheet
                CoinPurchaseSheet.show(context, userState: widget.userState);
              }
            },
            child: Text(
              isStars ? 'Go Live 🚀' : 'Get Coins 🪙',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showRulesDialog(BuildContext context) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Text('🏆 ', style: TextStyle(fontSize: 20)),
            Text(
              'Leaderboard Rules',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚡ Daily Leaderboard',
              style: TextStyle(color: colors.primaryCTA, fontWeight: FontWeight.bold),
            ),
            Text(
              'Resets every night at 00:00 UTC. Top 3 gain the Daily Crown & VIP badges for the next 24 hours.\n',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            Text(
              '🏆 Weekly Leaderboard',
              style: TextStyle(color: colors.premiumGold, fontWeight: FontWeight.bold),
            ),
            Text(
              'Resets every Sunday at 00:00 UTC. Top contenders receive permanent prestige status.\n',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            Text(
              '💎 Stars vs 🎁 Gifters',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
            ),
            Text(
              'Stars are ranked by Diamonds earned from stranger gifts in live calls. Gifters are ranked by Coins spent sending gifts.',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('GOT IT', style: TextStyle(color: colors.primaryCTA)),
          ),
        ],
      ),
    );
  }
}
