import 'package:flutter/material.dart';
import '../models/gift.dart';
import '../models/user_state.dart';
import '../services/admob_service.dart';
import '../theme/app_colors.dart';
import 'coin_purchase_sheet.dart';
import 'google_linking_sheet.dart';

class GiftBottomSheet extends StatelessWidget {
  final UserState userState;
  final Function(Gift gift) onSendGift;
  final VoidCallback onWatchAd;

  const GiftBottomSheet({
    super.key,
    required this.userState,
    required this.onSendGift,
    required this.onWatchAd,
  });

  static Future<void> show(
    BuildContext context, {
    required UserState userState,
    required Function(Gift gift) onSendGift,
    required VoidCallback onWatchAd,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GiftBottomSheet(
        userState: userState,
        onSendGift: onSendGift,
        onWatchAd: onWatchAd,
      ),
    );
  }

  void _handleGiftTap(BuildContext context, Gift gift) {
    if (userState.isAnonymous) {
      GoogleLinkingSheet.show(
        context,
        title: 'Keep your roses safe',
        description: 'Connect your Google account to send gifts and protect your wallet.',
        onLinked: () {
          _processSendGift(context, gift);
        },
      );
      return;
    }

    _processSendGift(context, gift);
  }

  Future<void> _processSendGift(BuildContext context, Gift gift) async {
    final success = await userState.spendCoins(
      gift.coinCost,
      transactionType: 'gift_sent',
      referenceId: 'gift_${gift.id}_${DateTime.now().millisecondsSinceEpoch}',
    );

    if (success) {
      if (context.mounted) Navigator.pop(context);
      onSendGift(gift);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Need ${gift.coinCost} coins! Top up or watch a quick ad.'),
            action: SnackBarAction(
              label: 'GET COINS',
              textColor: Colors.white,
              onPressed: () {
                CoinPurchaseSheet.show(context, userState: userState);
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AnimatedBuilder(
      animation: userState,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: colors.isDark ? 0.6 : 0.15),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header & Coin balance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Send Virtual Gift 🎁',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        CoinPurchaseSheet.show(context, userState: userState);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.surfaceCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colors.premiumGold.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text('🪙 ', style: TextStyle(fontSize: 14)),
                            Text(
                              '${userState.coins}',
                              style: TextStyle(
                                color: colors.premiumGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.add_circle, color: colors.premiumGold, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Grid of Gifts
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.95,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: Gift.defaultGifts.length,
                  itemBuilder: (context, index) {
                    final gift = Gift.defaultGifts[index];
                    final canAfford = userState.coins >= gift.coinCost;

                    return InkWell(
                      onTap: () => _handleGiftTap(context, gift),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: canAfford
                              ? colors.surfaceCard
                              : colors.surfaceCard.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: canAfford
                                ? colors.secondaryAccent.withValues(alpha: 0.35)
                                : colors.divider,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(gift.emoji, style: const TextStyle(fontSize: 34)),
                            const SizedBox(height: 4),
                            Text(
                              gift.name,
                              style: TextStyle(
                                color: canAfford ? colors.textPrimary : colors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.premiumGold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '🪙 ${gift.coinCost}',
                                style: TextStyle(
                                  color: colors.premiumGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Watch Ad for Free Coins banner
                InkWell(
                  onTap: () async {
                    await AdMobService.instance.showRewardedAd(
                      onRewardEarned: (coins) {
                        onWatchAd();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Colors.green,
                              content: Text('🎉 Video Ad Completed! +15 Free Coins added!'),
                            ),
                          );
                        }
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.secondaryAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Watch Video Ad for +15 Free Coins 🪙',
                          style: TextStyle(
                            color: Colors.white,
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
          ),
        );
      },
    );
  }
}
