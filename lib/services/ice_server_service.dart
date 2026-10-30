import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'supabase_service.dart';

class IceServerService {
  static final IceServerService instance = IceServerService._internal();
  IceServerService._internal();

  List<Map<String, dynamic>>? _cachedServers;
  DateTime? _cacheExpiry;

  /// Returns multi-provider ICE servers combining Google STUN, Cloudflare STUN,
  /// and dynamic free TURN relays (Metered.ca / Supabase / OpenRelay).
  Future<List<Map<String, dynamic>>> getIceServers() async {
    // Return cached list if valid (credentials typically valid for 12 hours)
    if (_cachedServers != null && _cacheExpiry != null && DateTime.now().isBefore(_cacheExpiry!)) {
      return _cachedServers!;
    }

    final servers = <Map<String, dynamic>>[];

    // 1. Primary Free STUN Providers (Handles 80-85% of all calls P2P for $0)
    servers.add({
      'urls': [
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
        'stun:stun2.l.google.com:19302',
        'stun:stun.cloudflare.com:3478',
      ],
    });

    // 2. Try fetching dynamic TURN credentials from Metered.ca Free REST API (if configured)
    final meteredServers = await _fetchMeteredCredentials();
    if (meteredServers.isNotEmpty) {
      servers.addAll(meteredServers);
    }

    // 3. Try fetching dynamic TURN credentials from Supabase RPC (if configured)
    final supabaseServers = await _fetchSupabaseTurnCredentials();
    if (supabaseServers.isNotEmpty) {
      servers.addAll(supabaseServers);
    }

    // 4. Fallback: Add OpenRelay Public Community Free TURN
    // Ensures calls never fail even if all other TURN sources are unconfigured
    servers.addAll(AppConfig.fallbackTurnServers);

    _cachedServers = servers;
    _cacheExpiry = DateTime.now().add(const Duration(hours: 6));

    debugPrint('⚡ WebRTC ICE Pool ready with ${servers.length} server groups (STUN + Multi-TURN).');
    return servers;
  }

  /// Fetches free temporary TURN credentials from Metered.ca REST API
  Future<List<Map<String, dynamic>>> _fetchMeteredCredentials() async {
    final domain = AppConfig.meteredAppDomain;
    final apiKey = AppConfig.meteredApiKey;

    if (domain.isEmpty || apiKey.isEmpty || apiKey.contains('placeholder')) {
      return [];
    }

    try {
      final uri = Uri.parse('https://$domain.metered.live/api/v1/turn/credentials?apiKey=$apiKey');
      final request = await HttpClient().getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final List<dynamic> jsonList = jsonDecode(body) as List<dynamic>;

        return jsonList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('ℹ️ Metered.ca fetch notice: $e (Falling back to OpenRelay community TURN)');
    }
    return [];
  }

  /// Fetches TURN credentials from Supabase Edge Function / RPC if available
  Future<List<Map<String, dynamic>>> _fetchSupabaseTurnCredentials() async {
    final client = SupabaseService.instance.client;
    if (client == null || !SupabaseService.instance.isInitialized) {
      return [];
    }

    try {
      final response = await client.rpc('get_turn_credentials');
      if (response is Map) {
        final data = Map<String, dynamic>.from(response);
        return [
          {
            'urls': [
              'turn:turn.heyora.app:3478?transport=udp',
              'turn:turn.heyora.app:3478?transport=tcp',
            ],
            'username': data['username'] as String? ?? 'guest',
            'credential': data['credential'] as String? ?? '',
          }
        ];
      }
    } catch (e) {
      debugPrint('ℹ️ Supabase get_turn_credentials notice: $e');
    }
    return [];
  }
}
