import 'dart:async';
import 'package:flutter/material.dart';
import '../models/leaderboard_entry.dart';
import '../models/user_state.dart';
import '../services/leaderboard_service.dart';
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
    final isStars = _selectedCategory == LeaderboardCategory.stars;
    final unitIcon = isStars ? '💎' : '🪙';
    final unitLabel = isStars ? 'Diamonds' : 'Coins';

    // Separate Top 3 from remaining
    LeaderboardEntry? first = _entries.isNotEmpty ? _entries[0] : null;
    LeaderboardEntry? second = _entries.length > 1 ? _entries[1] : null;
    LeaderboardEntry? third = _entries.length > 2 ? _entries[2] : null;
    List<LeaderboardEntry> runnersUp = _entries.length > 3 ? _entries.sublist(3) : [];

    return Scaffold(
      backgroundColor: const Color(0xFF090A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A14),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏆 ', style: TextStyle(fontSize: 20)),
            Text(
              'Leaderboard',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white60, size: 22),
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
                  color: const Color(0xFF14172B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCategoryTab(
                        title: 'Top Stars 💎',
                        subtitle: 'Earned Fans',
                        isSelected: _selectedCategory == LeaderboardCategory.stars,
                        activeGradient: const [Color(0xFF00F0FF), Color(0xFF7000FF)],
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
                        title: 'Top Gifters 🎁',
                        subtitle: 'Generous VIPs',
                        isSelected: _selectedCategory == LeaderboardCategory.gifters,
                        activeGradient: const [Color(0xFFFFB300), Color(0xFFFF007A)],
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
                  _buildTimeframePill('Daily ⚡', LeaderboardTimeframe.daily),
                  const SizedBox(width: 8),
                  _buildTimeframePill('Weekly 🏆', LeaderboardTimeframe.weekly),
                  const SizedBox(width: 8),
                  _buildTimeframePill('All-Time 👑', LeaderboardTimeframe.allTime),
                ],
              ),
            ),

            // 3. Live Reset Countdown Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1B1E38),
                      const Color(0xFF1B1E38).withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedTimeframe == LeaderboardTimeframe.daily
                        ? Colors.cyanAccent.withValues(alpha: 0.3)
                        : Colors.amberAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedTimeframe == LeaderboardTimeframe.allTime
                          ? Icons.military_tech_rounded
                          : Icons.timer_outlined,
                      color: _selectedTimeframe == LeaderboardTimeframe.daily
                          ? Colors.cyanAccent
                          : Colors.amberAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedTimeframe == LeaderboardTimeframe.allTime ? 'Rankings:' : 'Next Reset:',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      _formatDuration(_timeUntilReset),
                      style: TextStyle(
                        color: _selectedTimeframe == LeaderboardTimeframe.daily
                            ? Colors.cyanAccent
                            : Colors.amberAccent,
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
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF00F0FF)),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF00F0FF),
                      backgroundColor: const Color(0xFF14172B),
                      onRefresh: _fetchData,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        children: [
                          // 🥇 Podium Section (Top 3)
                          if (first != null) ...[
                            _buildPodium(first, second, third, unitIcon),
                            const SizedBox(height: 24),
                          ],

                          // 🏅 Section Header for Ranks 4+
                          if (runnersUp.isNotEmpty) ...[
                            const Row(
                              children: [
                                Text(
                                  'Contenders (4 - 50)',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(child: Divider(color: Colors.white12)),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],

                          // List of rank 4-50
                          ...runnersUp.map(
                            (entry) => _buildRankTile(entry, unitIcon),
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
      bottomSheet: _buildUserStandingBar(isStars, unitIcon, unitLabel),
    );
  }

  // --- Sub-Widgets ---

  Widget _buildCategoryTab({
    required String title,
    required String subtitle,
    required bool isSelected,
    required List<Color> activeGradient,
    required VoidCallback onTap,
  }) {
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
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? Colors.white.withValues(alpha: 0.85) : Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeframePill(String label, LeaderboardTimeframe timeframe) {
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
            color: isSelected ? const Color(0xFF262C52) : const Color(0xFF14172B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.8) : Colors.white10,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.cyanAccent : Colors.white60,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodium(
    LeaderboardEntry first,
    LeaderboardEntry? second,
    LeaderboardEntry? third,
    String unitIcon,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // #2 Silver (Left)
        if (second != null)
          Expanded(
            child: _buildPodiumColumn(
              entry: second,
              rank: 2,
              crownColor: const Color(0xFFC0C0C0),
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
            entry: first,
            rank: 1,
            crownColor: const Color(0xFFFFD700),
            podiumHeight: 155,
            unitIcon: unitIcon,
            isCenterFirst: true,
            gradient: const [Color(0xFFFFB300), Color(0xFFFF6F00)],
          ),
        ),

        const SizedBox(width: 12),

        // #3 Bronze (Right)
        if (third != null)
          Expanded(
            child: _buildPodiumColumn(
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
    required LeaderboardEntry entry,
    required int rank,
    required Color crownColor,
    required double podiumHeight,
    required String unitIcon,
    required List<Color> gradient,
    bool isCenterFirst = false,
  }) {
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
            color: const Color(0xFF1E2142),
          ),
          alignment: Alignment.center,
          child: Text(
            entry.displayName.isNotEmpty ? entry.displayName[0].toUpperCase() : '?',
            style: TextStyle(
              color: Colors.white,
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
            color: Colors.white,
            fontWeight: isCenterFirst ? FontWeight.bold : FontWeight.w600,
            fontSize: isCenterFirst ? 13 : 11,
          ),
        ),

        // Score Pill
        Container(
          margin: const EdgeInsets.only(top: 4, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF14172B),
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

  Widget _buildRankTile(LeaderboardEntry entry, String unitIcon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isCurrentUser ? const Color(0xFF262C52) : const Color(0xFF14172B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: entry.isCurrentUser
              ? Colors.cyanAccent.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2142),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                color: entry.rank <= 10 ? Colors.cyanAccent : Colors.white60,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Mini Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF2E335A),
            child: Text(
              entry.displayName.isNotEmpty ? entry.displayName[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
                        style: const TextStyle(
                          color: Colors.white,
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
                          color: Colors.cyanAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: Colors.cyanAccent,
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
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
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
                style: const TextStyle(
                  color: Colors.white,
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

  Widget _buildUserStandingBar(bool isStars, String unitIcon, String unitLabel) {
    final userScore = isStars ? widget.userState.diamonds : widget.userState.coins;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14172B),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF00F0FF).withValues(alpha: 0.2),
            child: const Icon(Icons.person, color: Colors.cyanAccent, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Standing',
                style: TextStyle(color: Colors.white60, fontSize: 11),
              ),
              Row(
                children: [
                  Text(unitIcon, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    _formatScore(userScore),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unitLabel,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isStars ? const Color(0xFF00F0FF) : const Color(0xFFFFB300),
              foregroundColor: Colors.black,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14172B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Text('🏆 ', style: TextStyle(fontSize: 20)),
            Text(
              'Leaderboard Rules',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚡ Daily Leaderboard',
              style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
            ),
            Text(
              'Resets every night at 00:00 UTC. Top 3 gain the Daily Crown & VIP badges for the next 24 hours.\n',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              '🏆 Weekly Leaderboard',
              style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
            ),
            Text(
              'Resets every Sunday at 00:00 UTC. Top contenders receive permanent prestige status.\n',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              '💎 Stars vs 🎁 Gifters',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text(
              'Stars are ranked by Diamonds earned from stranger gifts in live calls. Gifters are ranked by Coins spent sending gifts.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('GOT IT', style: TextStyle(color: Color(0xFF00F0FF))),
          ),
        ],
      ),
    );
  }
}
