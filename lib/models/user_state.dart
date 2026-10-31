import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/moderation_service.dart';
import '../services/supabase_service.dart';
import '../services/wallet_service.dart';
import 'gift.dart';

// 🔒 CASHOUT FEATURE FLAG: STRICTLY LOCKED (DISABLED)
// Keep disabled until specifically instructed by project owner to turn on.
// Keeps all revenue in your pocket (85% pure profit margin, zero payout liability).
const bool kEnableCashout = false;

class UserState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  UserState() {
    WalletService.instance.onWalletUpdated = () {
      notifyListeners();
    };
    _loadThemeMode();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString('heyora_theme_mode') ?? 'system';
      switch (modeStr) {
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        default:
          _themeMode = ThemeMode.system;
          break;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.light
              ? 'light'
              : 'system';
      await prefs.setString('heyora_theme_mode', modeStr);
    } catch (_) {}
  }

  int get coins => WalletService.instance.coins;
  int get diamonds => WalletService.instance.diamonds;
  bool get hasAccepted18Plus => ModerationService.instance.hasAccepted18Plus;
  bool get isAnonymous => SupabaseService.instance.isAnonymous;
  String get currentUserId => SupabaseService.instance.currentUserId;
  String get userEmail => SupabaseService.instance.userEmail;
  String get userDisplayName => SupabaseService.instance.userDisplayName;

  Future<void> accept18Plus() async {
    await ModerationService.instance.accept18Plus();
    notifyListeners();
  }

  Future<void> addCoins(int amount, {String? referenceId}) async {
    await WalletService.instance.creditCoins(
      amount,
      transactionType: 'manual_credit',
      referenceId: referenceId ?? 'tx_${DateTime.now().millisecondsSinceEpoch}',
    );
    notifyListeners();
  }

  Future<bool> spendCoins(int amount, {String? transactionType, String? referenceId}) async {
    final success = await WalletService.instance.deductCoins(
      amount,
      transactionType: transactionType ?? 'coin_spent',
      referenceId: referenceId,
    );
    if (success) {
      notifyListeners();
    }
    return success;
  }

  void receiveGift(Gift gift) {
    WalletService.instance.receiveGiftLocally(gift.diamondValue);
    notifyListeners();
  }

  Future<void> blockUser(String userId, {String? callId, String category = 'harassment'}) async {
    await ModerationService.instance.reportAndBlockUser(
      reportedUserId: userId,
      callId: callId,
      category: category,
    );
    notifyListeners();
  }

  bool isBlocked(String userId) => ModerationService.instance.isBlocked(userId);
  int get blockedCount => ModerationService.instance.blockedUserIds.length;

  Future<void> unblockAll() async {
    await ModerationService.instance.unblockAll();
    notifyListeners();
  }

  Future<bool> linkWithGoogle() async {
    final result = await SupabaseService.instance.linkWithGoogle();
    notifyListeners();
    return result;
  }

  Future<void> unlinkGoogle() async {
    await SupabaseService.instance.unlinkGoogle();
    notifyListeners();
  }

  /// Sign out from linked Google account and return to anonymous guest session
  Future<void> logout() async {
    await SupabaseService.instance.logout();
    notifyListeners();
  }

  /// Permanently delete account and all associated local and cloud data
  Future<void> deleteAccount() async {
    await SupabaseService.instance.deleteAccountData();
    await WalletService.instance.resetWallet();
    await ModerationService.instance.resetData();
    notifyListeners();
  }
}
