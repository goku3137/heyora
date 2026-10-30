import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/user_state.dart';
import 'screens/home_screen.dart';
import 'services/admob_service.dart';
import 'services/iap_service.dart';
import 'services/moderation_service.dart';
import 'services/supabase_service.dart';
import 'services/wallet_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set portrait orientation and transparent dark system bars
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF090A14),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Core Services (Guest auth, persistent wallet, moderation, ads, and IAP)
  await SupabaseService.instance.initialize();
  await WalletService.instance.initialize();
  await ModerationService.instance.initialize();
  await AdMobService.instance.initialize();
  await IAPService.instance.initialize();

  runApp(const HeyOraApp());
}

class HeyOraApp extends StatefulWidget {
  const HeyOraApp({super.key});

  @override
  State<HeyOraApp> createState() => _HeyOraAppState();
}

class _HeyOraAppState extends State<HeyOraApp> {
  final UserState _userState = UserState();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HeyOra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090A14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F0FF),
          secondary: Color(0xFFFF2A85),
          surface: Color(0xFF14162B),
        ),
      ),
      home: HomeScreen(userState: _userState),
    );
  }
}
