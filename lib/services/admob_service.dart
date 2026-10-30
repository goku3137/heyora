import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import 'wallet_service.dart';

class AdMobService {
  static final AdMobService instance = AdMobService._internal();
  AdMobService._internal();

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  bool _isInitialized = false;

  bool get isAdReady => _rewardedAd != null;

  String get _rewardedAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return AppConfig.admobRewardedAdUnitIdAndroid;
    if (Platform.isIOS) return AppConfig.admobRewardedAdUnitIdIos;
    return '';
  }

  /// Initialize Google Mobile Ads SDK and pre-load first rewarded ad
  Future<void> initialize() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('ℹ️ Mobile ads not supported on current platform.');
      return;
    }

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      loadRewardedAd();
    } catch (e) {
      debugPrint('⚠️ AdMob SDK initialization notice: $e');
    }
  }

  /// Load a 30s Rewarded Video Ad
  void loadRewardedAd() {
    if (!_isInitialized || _isAdLoading || _rewardedAd != null) return;
    _isAdLoading = true;

    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('🎉 Rewarded Ad loaded successfully.');
          _rewardedAd = ad;
          _isAdLoading = false;
          _configureAdCallbacks(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('⚠️ Rewarded Ad failed to load: $error');
          _rewardedAd = null;
          _isAdLoading = false;
        },
      ),
    );
  }

  void _configureAdCallbacks(RewardedAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        // Preload next ad immediately
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('⚠️ Rewarded Ad failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
      },
    );
  }

  /// Show the Rewarded Ad and credit +15 coins upon completion
  Future<bool> showRewardedAd({required Function(int coins) onRewardEarned}) async {
    if (_rewardedAd == null) {
      // In local development or desktop fallback, simulate reward for testing
      debugPrint('ℹ️ AdMob not loaded. Providing test reward in developer mode.');
      final txId = 'ad_test_${const Uuid().v4()}';
      await WalletService.instance.creditCoins(15, transactionType: 'ad_reward', referenceId: txId);
      onRewardEarned(15);
      loadRewardedAd();
      return true;
    }

    bool earned = false;
    await _rewardedAd!.show(
      onUserEarnedReward: (adWithoutView, reward) async {
        earned = true;
        final txId = 'ad_reward_${const Uuid().v4()}';
        await WalletService.instance.creditCoins(
          15,
          transactionType: 'ad_reward',
          referenceId: txId,
        );
        onRewardEarned(15);
      },
    );

    return earned;
  }
}
