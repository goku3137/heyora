import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../config/app_config.dart';
import 'wallet_service.dart';

class IAPService {
  static final IAPService instance = IAPService._internal();
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  List<ProductDetails> products = [];
  bool isAvailable = false;

  /// Coin amount corresponding to each product ID
  static const Map<String, int> productCoins = {
    AppConfig.iapCoins100: 100,
    AppConfig.iapCoins500: 500,
    AppConfig.iapCoins1200: 1200,
    AppConfig.iapCoins2500: 2500,
  };

  /// Initialize Google Play Billing purchase stream & fetch coin products
  Future<void> initialize() async {
    isAvailable = await _iap.isAvailable();
    if (!isAvailable) {
      debugPrint('ℹ️ In-App Purchases not available on current device/environment.');
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (error) => debugPrint('⚠️ IAP stream error: $error'),
    );

    await loadProducts();
  }

  Future<void> loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(AppConfig.iapProductIds);
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('⚠️ Products not found in Play Console: ${response.notFoundIDs}');
      }
      products = response.productDetails;
    } catch (e) {
      debugPrint('⚠️ IAP query error: $e');
    }
  }

  /// Initiate purchase checkout flow for a coin package
  Future<void> buyCoinPack(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('⏳ Purchase pending: ${purchaseDetails.productID}');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint('❌ Purchase failed: ${purchaseDetails.error}');
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Verify and deliver coins
        final coins = productCoins[purchaseDetails.productID] ?? 100;
        final txId = purchaseDetails.purchaseID ?? purchaseDetails.verificationData.serverVerificationData;

        await WalletService.instance.creditCoins(
          coins,
          transactionType: 'iap_purchase',
          referenceId: txId,
        );

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
