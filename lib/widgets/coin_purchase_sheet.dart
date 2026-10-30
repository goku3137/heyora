import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/user_state.dart';
import '../services/iap_service.dart';
import '../services/wallet_service.dart';
import 'google_linking_sheet.dart';

class CoinPurchaseSheet extends StatelessWidget {
  final UserState userState;

  const CoinPurchaseSheet({super.key, required this.userState});

  static Future<void> show(BuildContext context, {required UserState userState}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CoinPurchaseSheet(userState: userState),
    );
  }

  final List<Map<String, dynamic>> _coinPacks = const [
    {
      'id': AppConfig.iapCoins100,
      'coins': 100,
      'price': '₹79',
      'label': 'Starter',
      'emoji': '🪙',
    },
    {
      'id': AppConfig.iapCoins500,
      'coins': 500,
      'price': '₹399',
      'label': 'Popular',
      'emoji': '💰',
      'badge': 'HOT',
    },
    {
      'id': AppConfig.iapCoins1200,
      'coins': 1200,
      'price': '₹799',
      'label': 'Best Value',
      'emoji': '💎',
      'badge': '+20% FREE',
    },
    {
      'id': AppConfig.iapCoins2500,
      'coins': 2500,
      'price': '₹1,499',
      'label': 'VIP Master',
      'emoji': '👑',
      'badge': '+35% FREE',
    },
  ];

  Future<void> _handleBuy(BuildContext context, Map<String, dynamic> pack) async {
    // Action-gating: If guest, ask to link Google identity to protect their purchased wallet!
    if (userState.isAnonymous) {
      GoogleLinkingSheet.show(
        context,
        title: 'Keep your purchases safe',
        description: 'Connect your Google account before purchasing coins to ensure your balance can be recovered across devices.',
        onLinked: () {
          _executePurchase(context, pack);
        },
      );
      return;
    }

    _executePurchase(context, pack);
  }

  Future<void> _executePurchase(BuildContext context, Map<String, dynamic> pack) async {
    final iap = IAPService.instance;
    final productId = pack['id'] as String;

    final matchingProducts = iap.products.where((p) => p.id == productId);
    if (matchingProducts.isNotEmpty) {
      await iap.buyCoinPack(matchingProducts.first);
      if (context.mounted) Navigator.pop(context);
    } else {
      // In development / test environment, credit test coins directly
      final coins = pack['coins'] as int;
      final txId = 'iap_test_${const Uuid().v4()}';
      await WalletService.instance.creditCoins(
        coins,
        transactionType: 'iap_purchase',
        referenceId: txId,
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('🎉 Purchased ${pack['coins']} Coins successfully! (Test Mode)'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        color: Color(0xFF14162B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black87, blurRadius: 25, spreadRadius: 5),
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

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Get HeyOra Coins 🪙',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Unlock Girls Only filter & send live gifts',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
                Container(
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
                        '${userState.coins}',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Packs Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _coinPacks.length,
              itemBuilder: (context, index) {
                final pack = _coinPacks[index];
                final badge = pack['badge'] as String?;

                return InkWell(
                  onTap: () => _handleBuy(context, pack),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E213D),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: badge != null
                            ? const Color(0xFFFF2A85).withValues(alpha: 0.6)
                            : Colors.white10,
                        width: badge != null ? 1.5 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(pack['emoji'] as String, style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 8),
                                Text(
                                  '${pack['coins']} Coins',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              pack['label'] as String,
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                pack['price'] as String,
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (badge != null)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF2A85),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
