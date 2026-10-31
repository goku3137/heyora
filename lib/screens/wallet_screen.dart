import 'package:flutter/material.dart';
import '../models/user_state.dart';
import '../theme/app_colors.dart';
import '../widgets/coin_purchase_sheet.dart';
import '../widgets/google_linking_sheet.dart';
import 'settings_screen.dart';

class WalletScreen extends StatelessWidget {
  final UserState userState;

  const WalletScreen({super.key, required this.userState});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AnimatedBuilder(
      animation: userState,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Wallet & Status',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            iconTheme: IconThemeData(color: colors.textPrimary),
            actions: [
              IconButton(
                icon: Icon(Icons.settings_outlined, color: colors.textPrimary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsScreen(userState: userState),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // 1. Diamonds Popularity Card (Subtle Violet Accent Glow)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.secondaryAccent.withValues(alpha: 0.25)),
                      boxShadow: [
                        BoxShadow(
                          color: colors.secondaryAccent.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.secondaryAccent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('💎', style: TextStyle(fontSize: 40)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${userState.diamonds} Diamonds',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Accumulated fan appreciation earned from virtual gifts received during live calls.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textSecondary, fontSize: 13),
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
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.divider),
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
                                  style: TextStyle(
                                    color: colors.premiumGold,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'For luxury gifts & filters',
                                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.premiumGold,
                            foregroundColor: colors.isDark ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            elevation: 0,
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
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              userState.isAnonymous ? Icons.person_outline : Icons.verified_user_rounded,
                              color: userState.isAnonymous ? colors.textSecondary : Colors.greenAccent,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              userState.isAnonymous ? 'Guest Mode' : 'Verified Google Account',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          userState.isAnonymous
                              ? 'You are chatting as an anonymous guest. Link your Google account to sync your coins and diamond status.'
                              : 'Your wallet, coins, and popularity are backed up securely.',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
                        ),
                        if (userState.isAnonymous) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: colors.primaryCTA),
                                foregroundColor: colors.primaryCTA,
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
                        ] else ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  userState.userEmail,
                                  style: TextStyle(color: colors.primaryCTA, fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await userState.unlinkGoogle();
                                },
                                child: Text('Disconnect', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. App Theme Appearance Selector (Dual Theme + Cinema Mode)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.palette_outlined, color: colors.primaryCTA, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              'App Appearance',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Video calls always run in Cinema Mode to preserve natural camera lighting.',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.divider),
                          ),
                          child: Row(
                            children: [
                              _buildThemeOption(context, 'System', ThemeMode.system, Icons.brightness_auto, userState, colors),
                              _buildThemeOption(context, 'Dark', ThemeMode.dark, Icons.dark_mode_outlined, userState, colors),
                              _buildThemeOption(context, 'Light', ThemeMode.light, Icons.light_mode_outlined, userState, colors),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. Compliance Notice (Cashouts Paused)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.divider),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: colors.textSecondary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Cashout is paused for initial Google Play release. Diamonds represent in-app popularity score and are non-withdrawable.',
                            style: TextStyle(color: colors.textSecondary, fontSize: 11),
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

  Widget _buildThemeOption(
    BuildContext context,
    String label,
    ThemeMode mode,
    IconData icon,
    UserState userState,
    AppColorScheme colors,
  ) {
    final isSelected = userState.themeMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () => userState.setThemeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: colors.isDark ? 0.3 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? colors.primaryCTA : colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? colors.textPrimary : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
