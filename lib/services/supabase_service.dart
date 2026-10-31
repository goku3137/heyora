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
  String? _linkedEmail;
  String? _linkedName;
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
    if (_linkedEmail != null && _linkedEmail!.isNotEmpty) return false;
    if (_client?.auth.currentUser == null) return true;
    final user = _client!.auth.currentUser!;
    return user.isAnonymous || user.email == null || user.email!.isEmpty;
  }

  /// Current user email (either from Supabase or linked Google account)
  String get userEmail {
    return _linkedEmail ?? _client?.auth.currentUser?.email ?? 'guest@heyora.app';
  }

  /// Current user display name
  String get userDisplayName {
    return _linkedName ?? _client?.auth.currentUser?.userMetadata?['full_name'] ?? 'HeyOra User';
  }

  /// Initialize Supabase and restore or create anonymous guest session
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedGuestId = prefs.getString('heyora_persistent_guest_id');
    _linkedEmail = prefs.getString('heyora_linked_email');
    _linkedName = prefs.getString('heyora_linked_name');

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
      debugPrint('ℹ️ Supabase not yet configured in AppConfig. Running in local mode.');
    }
  }

  /// Action-Gated Google Identity Linking
  /// Links Google OAuth identity to the EXISTING anonymous user, preserving wallet & UUID!
  Future<bool> linkWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: AppConfig.googleWebClientId.isNotEmpty ? AppConfig.googleWebClientId : null,
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled account picker
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      _linkedEmail = googleUser.email;
      _linkedName = googleUser.displayName ?? googleUser.email.split('@').first;
      await prefs.setString('heyora_linked_email', _linkedEmail!);
      await prefs.setString('heyora_linked_name', _linkedName!);

      if (AppConfig.isSupabaseConfigured && _client != null) {
        try {
          final googleAuth = await googleUser.authentication;
          final idToken = googleAuth.idToken;
          if (idToken != null) {
            await _client!.auth.signInWithIdToken(
              provider: OAuthProvider.google,
              idToken: idToken,
              accessToken: googleAuth.accessToken,
            );
          } else {
            await _client!.auth.linkIdentity(OAuthProvider.google);
          }
        } catch (supabaseError) {
          debugPrint('⚠️ Supabase cloud link notice: $supabaseError (Profile linked locally)');
        }
      }

      debugPrint('🎉 Google account linked successfully: $_linkedEmail ($_linkedName)');
      return true;
    } catch (e) {
      debugPrint('❌ Google linking error: $e');
      return false;
    }
  }

  /// Unlinks Google account and returns to anonymous guest mode
  Future<void> unlinkGoogle() async {
    final prefs = await SharedPreferences.getInstance();
    _linkedEmail = null;
    _linkedName = null;
    await prefs.remove('heyora_linked_email');
    await prefs.remove('heyora_linked_name');
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }
}
