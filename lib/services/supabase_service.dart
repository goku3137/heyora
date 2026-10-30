import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  SupabaseClient? _client;
  String? _cachedGuestId;
  bool _isInitialized = false;

  SupabaseClient? get client => _client;
  bool get isInitialized => _isInitialized;

  /// Returns current user ID (either authenticated Supabase user or persistent guest UUID)
  String get currentUserId {
    if (_client?.auth.currentUser != null) {
      return _client!.auth.currentUser!.id;
    }
    return _cachedGuestId ?? 'guest_local';
  }

  /// Whether current user is an anonymous guest
  bool get isAnonymous {
    if (_client?.auth.currentUser == null) return true;
    final user = _client!.auth.currentUser!;
    return user.isAnonymous || user.email == null || user.email!.isEmpty;
  }

  /// Initialize Supabase and restore or create anonymous guest session
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedGuestId = prefs.getString('heyora_persistent_guest_id');

    if (_cachedGuestId == null) {
      _cachedGuestId = const Uuid().v4();
      await prefs.setString('heyora_persistent_guest_id', _cachedGuestId!);
    }

    if (AppConfig.isSupabaseConfigured) {
      try {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          // ignore: deprecated_member_use
          anonKey: AppConfig.supabaseAnonKey,
        );
        _client = Supabase.instance.client;
        _isInitialized = true;

        // Restore or sign in anonymously
        if (_client!.auth.currentUser == null) {
          await _client!.auth.signInAnonymously();
          debugPrint('⚡ Supabase Anonymous Guest signed in: ${_client!.auth.currentUser?.id}');
        } else {
          debugPrint('⚡ Supabase Session restored: ${_client!.auth.currentUser?.id}');
        }
      } catch (e) {
        debugPrint('⚠️ Supabase initialization notice: $e (Falling back to local guest mode)');
      }
    } else {
      debugPrint('ℹ️ Supabase not yet configured in AppConfig. Running in local guest mode.');
    }
  }

  /// Action-Gated Google Identity Linking
  /// Links Google OAuth identity to the EXISTING anonymous user, preserving wallet & UUID!
  Future<bool> linkWithGoogle() async {
    if (!AppConfig.isSupabaseConfigured || _client == null) {
      debugPrint('ℹ️ Google linking simulated in local test mode.');
      return true;
    }

    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled
        return false;
      }

      // Link identity to existing Supabase anonymous user
      final linked = await _client!.auth.linkIdentity(OAuthProvider.google);
      debugPrint('🎉 Google identity linked: ${_client!.auth.currentUser?.email ?? googleUser.email}');
      return linked;
    } catch (e) {
      debugPrint('❌ Google linking error: $e');
      return false;
    }
  }
}
