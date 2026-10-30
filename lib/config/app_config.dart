/// Application Global Configuration & Constants
class AppConfig {
  // 1. Supabase Cloud Credentials
  // Replace these with your project's URL and Anon Key from the Supabase Dashboard.
  static const String supabaseUrl = 'https://demo-heyora-project.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.demo-placeholder-key-replace-with-real-key';

  static bool get isSupabaseConfigured =>
      supabaseUrl != 'https://demo-heyora-project.supabase.co' &&
      !supabaseAnonKey.contains('demo-placeholder');

  // 2. WebRTC STUN & TURN Infrastructure Configuration
  // 80% of calls connect for $0 through Google STUN servers.
  // 20% connect via your Coturn server when behind symmetric NAT.
  static const List<Map<String, dynamic>> iceServers = [
    {
      'urls': [
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
        'stun:stun2.l.google.com:19302',
      ],
    },
    // Coturn TURN Server Fallback (Credentials dynamically refreshed via Supabase RPC or configured here)
    {
      'urls': [
        'turn:turn.heyora.app:3478?transport=udp',
        'turn:turn.heyora.app:3478?transport=tcp',
      ],
      'username': 'heyora_guest',
      'credential': 'heyora_guest_password',
    },
  ];

  // 3. Adaptive Video Call Quality Constraints
  // Start calls at 360p / 15 FPS (~250 kbps) for instant connect and low bandwidth.
  // After 20 seconds, upgrade to 480p / 720p if network packet loss < 2%.
  static const int initialVideoWidth = 640;
  static const int initialVideoHeight = 360;
  static const int initialFrameRate = 15;
  static const int initialTargetBitrateKbps = 250;

  static const int highVideoWidth = 1280;
  static const int highVideoHeight = 720;
  static const int highFrameRate = 24;
  static const int highTargetBitrateKbps = 800;

  // 4. Google AdMob Configuration (Official Google Test Ad Unit IDs)
  static const String admobRewardedAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String admobRewardedAdUnitIdIos =
      'ca-app-pub-3940256099942544/1712485313';

  // 5. In-App Purchase Coin Packages
  static const String iapCoins100 = 'coins_100';
  static const String iapCoins500 = 'coins_500';
  static const String iapCoins1200 = 'coins_1200';
  static const String iapCoins2500 = 'coins_2500';

  static const Set<String> iapProductIds = {
    iapCoins100,
    iapCoins500,
    iapCoins1200,
    iapCoins2500,
  };
}
