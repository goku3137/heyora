import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

class WalletService {
  static final WalletService instance = WalletService._internal();
  WalletService._internal();

  int _coins = 120;
  int _diamonds = 350;

  int get coins => _coins;
  int get diamonds => _diamonds;

  VoidCallback? onWalletUpdated;

  /// Load wallet balance from local cache, then synchronize with Supabase
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _coins = prefs.getInt('heyora_cached_coins') ?? 120;
    _diamonds = prefs.getInt('heyora_cached_diamonds') ?? 0;

    await refreshFromCloud();
  }

  /// Synchronize balance with Supabase PostgreSQL cloud wallet
  Future<void> refreshFromCloud() async {
    final client = SupabaseService.instance.client;
    final userId = SupabaseService.instance.currentUserId;

    if (client != null && SupabaseService.instance.isInitialized) {
      try {
        final data = await client
            .from('wallets')
            .select('coins, diamonds')
            .eq('user_id', userId)
            .maybeSingle();

        if (data != null) {
          _coins = data['coins'] as int? ?? _coins;
          _diamonds = data['diamonds'] as int? ?? _diamonds;
          await _saveToLocalCache();
          onWalletUpdated?.call();
        }
      } catch (e) {
        debugPrint('Wallet cloud sync notice: $e');
      }
    }
  }

  /// Atomic deduction (e.g., 10 coins for Girls Only filter)
  Future<bool> deductCoins(int amount, {required String transactionType, String? referenceId}) async {
    if (_coins < amount) return false;

    final client = SupabaseService.instance.client;
    if (client != null && SupabaseService.instance.isInitialized) {
      try {
        final response = await client.rpc('deduct_coins', params: {
          'p_amount': amount,
          'p_transaction_type': transactionType,
          'p_reference_id': referenceId,
        });

        final data = Map<String, dynamic>.from(response as Map);
        if (data['success'] == true) {
          _coins = data['remaining_coins'] as int;
          await _saveToLocalCache();
          onWalletUpdated?.call();
          return true;
        }
        return false;
      } catch (e) {
        debugPrint('RPC deduct_coins notice: $e');
      }
    }

    // Local fallback
    _coins -= amount;
    await _saveToLocalCache();
    onWalletUpdated?.call();
    return true;
  }

  /// Atomic credit (e.g., +15 coins from AdMob rewarded ad, or IAP coin pack)
  Future<bool> creditCoins(int amount, {required String transactionType, required String referenceId}) async {
    final client = SupabaseService.instance.client;
    if (client != null && SupabaseService.instance.isInitialized) {
      try {
        final response = await client.rpc('credit_coins', params: {
          'p_amount': amount,
          'p_transaction_type': transactionType,
          'p_reference_id': referenceId,
        });

        final data = Map<String, dynamic>.from(response as Map);
        if (data['success'] == true) {
          _coins = data['new_balance'] as int;
          await _saveToLocalCache();
          onWalletUpdated?.call();
          return true;
        }
        return false;
      } catch (e) {
        debugPrint('RPC credit_coins notice: $e');
      }
    }

    // Local fallback
    _coins += amount;
    await _saveToLocalCache();
    onWalletUpdated?.call();
    return true;
  }

  /// Send virtual gift (atomic transfer)
  Future<bool> sendGift({
    required String receiverId,
    required String? callId,
    required String giftId,
    required int coinCost,
    required int diamondValue,
  }) async {
    if (_coins < coinCost) return false;

    final client = SupabaseService.instance.client;
    if (client != null && SupabaseService.instance.isInitialized) {
      try {
        final response = await client.rpc('send_gift', params: {
          'p_receiver_id': receiverId,
          'p_call_id': callId,
          'p_gift_id': giftId,
          'p_coin_cost': coinCost,
          'p_diamond_value': diamondValue,
        });

        final data = Map<String, dynamic>.from(response as Map);
        if (data['success'] == true) {
          _coins = data['remaining_coins'] as int;
          await _saveToLocalCache();
          onWalletUpdated?.call();
          return true;
        }
        return false;
      } catch (e) {
        debugPrint('RPC send_gift notice: $e');
      }
    }

    // Local fallback
    _coins -= coinCost;
    await _saveToLocalCache();
    onWalletUpdated?.call();
    return true;
  }

  void receiveGiftLocally(int diamondValue) {
    _diamonds += diamondValue;
    _saveToLocalCache();
    onWalletUpdated?.call();
  }

  Future<void> _saveToLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('heyora_cached_coins', _coins);
    await prefs.setInt('heyora_cached_diamonds', _diamonds);
  }
}
