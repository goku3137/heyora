import 'package:flutter/material.dart';
import '../models/user_state.dart';
import '../services/admob_service.dart';
import '../theme/app_colors.dart';
import '../widgets/coin_purchase_sheet.dart';
import '../widgets/safety_dialog.dart';
import 'video_call_screen.dart';
import 'wallet_screen.dart';
import 'leaderboard_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserState userState;

  const HomeScreen({super.key, required this.userState});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String _matchFilter = 'random'; // 'random' or 'female'

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Prompt for 18+ Safety Consent on first launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.userState.hasAccepted18Plus) {
        SafetyDialog.show(context, () {
          widget.userState.accept18Plus();
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startMatch() async {
    if (!widget.userState.hasAccepted18Plus) {
      SafetyDialog.show(context, () {
        widget.userState.accept18Plus();
        _proceedToCall();
      });
      return;
    }

    if (_matchFilter == 'female') {
      final success = await widget.userState.spendCoins(
        10,
        transactionType: 'gender_filter',
        referenceId: 'gender_filter_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: const Text('Need 10 Coins for Girls Only filter. Top up or watch a quick ad!'),
              action: SnackBarAction(
                label: 'GET COINS',
                textColor: Colors.white,
                onPressed: () {
                  CoinPurchaseSheet.show(context, userState: widget.userState);
                },
              ),
            ),
          );
        }
        return;
      }
    }

    _proceedToCall();
  }

  void _proceedToCall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          userState: widget.userState,
          genderFilter: _matchFilter,
        ),
      ),
    );
  }

  Future<void> _watchRewardedAd() async {
    await AdMobService.instance.showRewardedAd(
      onRewardEarned: (coins) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text('🎉 Video Ad Completed! +15 Free Coins added!'),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AnimatedBuilder(
      animation: widget.userState,
      builder: (context, _) {
        final state = widget.userState;

        return Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // 1. Top Header (Logo + Rank + Coins + Diamonds)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // App Brand
                      Row(
                        children: [
                          const Text('⚡ ', style: TextStyle(fontSize: 22)),
                          Text(
                            'HeyOra',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          // Leaderboard Trophy Pill
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LeaderboardScreen(userState: state),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: colors.divider),
                              ),
                              child: Row(
                                children: [
                                  const Text('🏆 ', style: TextStyle(fontSize: 11)),
                                  Text(
                                    'Rank',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),

                          // Coins pill: opens Coin Purchase Sheet
                          GestureDetector(
                            onTap: () {
                              CoinPurchaseSheet.show(context, userState: state);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: colors.premiumGold.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Text('🪙 ', style: TextStyle(fontSize: 12)),
                                  Text(
                                    '${state.coins}',
                                    style: TextStyle(
                                      color: colors.premiumGold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(Icons.add_circle, color: colors.premiumGold, size: 14),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),

                          // Popularity Diamonds Pill
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WalletScreen(userState: state),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: colors.secondaryAccent.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                children: [
                                  const Text('💎 ', style: TextStyle(fontSize: 12)),
                                  Text(
                                    '${state.diamonds}',
                                    style: TextStyle(
                                      color: colors.secondaryAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),

                          // Settings Icon
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SettingsScreen(userState: state),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: colors.divider),
                              ),
                              child: Icon(
                                Icons.settings_outlined,
                                color: colors.textPrimary,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // 2. Central Radar / Pulsing 1-Click Match Button (Solar Coral - Flat & High-Converting)
                  Column(
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: GestureDetector(
                          onTap: _startMatch,
                          child: Container(
                            width: 190,
                            height: 190,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.primaryCTA.withValues(alpha: 0.16),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primaryCTA.withValues(alpha: 0.22),
                                  blurRadius: 36,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 156,
                                height: 156,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.primaryCTA,
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.videocam_rounded,
                                      color: Colors.white,
                                      size: 52,
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'START MATCH',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        '1-Click Instant Video Match',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Meet verified strangers worldwide with zero friction',
                        style: TextStyle(color: colors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // 3. Match Preference Selector (Clean & Minimal)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.surfaceCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.divider),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _matchFilter = 'random'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _matchFilter == 'random'
                                    ? colors.surface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _matchFilter == 'random'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: colors.isDark ? 0.2 : 0.06),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '🎲 Random (Free)',
                                style: TextStyle(
                                  color: _matchFilter == 'random' ? colors.textPrimary : colors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _matchFilter = 'female'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _matchFilter == 'female'
                                    ? colors.primaryCTA
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '👩 Girls Only (🪙 10)',
                                style: TextStyle(
                                  color: _matchFilter == 'female' ? Colors.white : colors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 4. Free Coins Promo Banner (Real AdMob Rewarded Video Ad)
                  InkWell(
                    onTap: _watchRewardedAd,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.divider),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.ondemand_video_rounded, color: colors.premiumGold, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Get +15 Free Coins',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Watch a quick 30s ad to unlock filters and gifts',
                                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, color: colors.textSecondary, size: 14),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 5. Safety & Community Guidelines Link (Opens Settings & Legal Policies)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsScreen(userState: state),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, color: colors.textSecondary, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '18+ Adult Community Guidelines & Privacy',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
