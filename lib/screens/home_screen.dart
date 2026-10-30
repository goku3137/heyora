import 'package:flutter/material.dart';
import '../models/user_state.dart';
import '../services/admob_service.dart';
import '../widgets/coin_purchase_sheet.dart';
import '../widgets/safety_dialog.dart';
import 'video_call_screen.dart';
import 'wallet_screen.dart';
import 'leaderboard_screen.dart';

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
    return AnimatedBuilder(
      animation: widget.userState,
      builder: (context, _) {
        final state = widget.userState;

        return Scaffold(
          backgroundColor: const Color(0xFF090A14),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // 1. Top Header (Logo + Coins + Diamonds)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // App Brand
                      const Row(
                        children: [
                          Text('⚡ ', style: TextStyle(fontSize: 22)),
                          Text(
                            'HeyOra',
                            style: TextStyle(
                              color: Colors.white,
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
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2142),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                              ),
                              child: const Row(
                                children: [
                                  Text('🏆 ', style: TextStyle(fontSize: 12)),
                                  Text(
                                    'Rank',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Coins pill: opens Coin Purchase Sheet
                          GestureDetector(
                            onTap: () {
                              CoinPurchaseSheet.show(context, userState: state);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2142),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Text('🪙 ', style: TextStyle(fontSize: 13)),
                                  Text(
                                    '${state.coins}',
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.add_circle, color: Colors.amberAccent, size: 16),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Popularity Diamonds Pill (Cashout disabled)
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2142),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Text('💎 ', style: TextStyle(fontSize: 13)),
                                  Text(
                                    '${state.diamonds}',
                                    style: const TextStyle(
                                      color: Colors.cyanAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // 2. Central Radar / Pulsing 1-Click Match Button
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
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00F0FF), Color(0xFF9E00FF), Color(0xFFFF007A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                                  blurRadius: 35,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF0C0E1E),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.videocam_rounded,
                                      color: Colors.white,
                                      size: 54,
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'START MATCH',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
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
                      const Text(
                        '1-Click Instant Video Match',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Meet verified strangers worldwide with zero friction',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // 3. Match Preference Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14162B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
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
                                    ? Colors.cyanAccent
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '🎲 Random (Free)',
                                style: TextStyle(
                                  color: _matchFilter == 'random' ? Colors.black : Colors.white70,
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
                                    ? const Color(0xFFFF2A85)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '👩 Girls Only (🪙 10)',
                                style: TextStyle(
                                  color: _matchFilter == 'female' ? Colors.white : Colors.white70,
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
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF8A2BE2).withValues(alpha: 0.35),
                            const Color(0xFF00E5FF).withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.ondemand_video_rounded, color: Colors.cyanAccent, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Get +15 Free Coins',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Watch a quick 30s ad to unlock filters and gifts',
                                  style: TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 5. Safety & Community Guidelines Link
                  GestureDetector(
                    onTap: () {
                      SafetyDialog.show(context, () {});
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.white38, size: 16),
                        SizedBox(width: 6),
                        Text(
                          '18+ Adult Community Guidelines & Privacy',
                          style: TextStyle(
                            color: Colors.white38,
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
