import 'package:flutter/material.dart';
import '../models/gift.dart';
import '../models/user_state.dart';
import '../services/admob_service.dart';
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
    // Action-gating: If guest, prompt to link Google account to protect roses/gifts
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
    return AnimatedBuilder(
      animation: userState,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFF14162B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5),
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
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header & Coin balance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Send Virtual Gift 🎁',
                      style: TextStyle(
                        color: Colors.white,
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
                          color: const Color(0xFF262847),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Text('🪙 ', style: TextStyle(fontSize: 14)),
                            Text(
                              '${userState.coins}',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.add_circle, color: Colors.amberAccent, size: 16),
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
                              ? const Color(0xFF1E213D)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: canAfford
                                ? Colors.cyanAccent.withValues(alpha: 0.3)
                                : Colors.white10,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(gift.emoji, style: const TextStyle(fontSize: 34)),
                            const SizedBox(height: 4),
                            Text(
                              gift.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: canAfford
                                    ? Colors.amber.withValues(alpha: 0.2)
                                    : Colors.white10,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '🪙 ${gift.coinCost}',
                                style: TextStyle(
                                  color: canAfford ? Colors.amberAccent : Colors.white38,
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C13D1), Color(0xFF9E00FF)],
                      ),
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
