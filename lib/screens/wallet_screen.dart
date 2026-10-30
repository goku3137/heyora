import 'package:flutter/material.dart';
import '../models/user_state.dart';
import '../widgets/coin_purchase_sheet.dart';
import '../widgets/google_linking_sheet.dart';

class WalletScreen extends StatelessWidget {
  final UserState userState;

  const WalletScreen({super.key, required this.userState});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: userState,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0C0E1E),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Wallet & Popularity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // 1. Diamonds Popularity Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00E5FF).withValues(alpha: 0.15),
                          const Color(0xFF9E00FF).withValues(alpha: 0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('💎', style: TextStyle(fontSize: 42)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${userState.diamonds} Diamonds',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Accumulated fan appreciation score earned from virtual gifts received during live calls.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Caller Coins Card (With Top-Up button)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14162B),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🪙', style: TextStyle(fontSize: 32)),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${userState.coins} Coins',
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'For gifts & gender filters',
                                  style: TextStyle(color: Colors.white60, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amberAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onPressed: () {
                            CoinPurchaseSheet.show(context, userState: userState);
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Top Up', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Google Account Identity Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14162B),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              userState.isAnonymous ? Icons.person_outline : Icons.verified_user_rounded,
                              color: userState.isAnonymous ? Colors.white60 : Colors.greenAccent,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              userState.isAnonymous ? 'Guest Mode' : 'Verified Google Account',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          userState.isAnonymous
                              ? 'You are chatting as an anonymous guest. Link your Google account to sync your coins and diamond status across devices.'
                              : 'Your wallet and diamonds are backed up securely to your Google account.',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        if (userState.isAnonymous) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.cyanAccent),
                                foregroundColor: Colors.cyanAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                GoogleLinkingSheet.show(
                                  context,
                                  title: 'Link Your Google Account',
                                  description: 'Keep your coins, diamonds, and reputation safe across device reinstalls.',
                                  onLinked: () {},
                                );
                              },
                              icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
                              label: const Text('Link with Google', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. Compliance Notice (Cashouts Paused)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white54, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Cashout is paused for initial Google Play release. Diamonds represent in-app popularity score and are non-withdrawable.',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
