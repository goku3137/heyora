import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/user_state.dart';
import 'screens/home_screen.dart';
import 'services/admob_service.dart';
import 'services/iap_service.dart';
import 'services/moderation_service.dart';
import 'services/supabase_service.dart';
import 'services/wallet_service.dart';
import 'theme/app_theme.dart';

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
      systemNavigationBarColor: Colors.transparent,
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
    return ListenableBuilder(
      listenable: _userState,
      builder: (context, _) {
        return MaterialApp(
          title: 'HeyOra',
          debugShowCheckedModeBanner: false,
          themeMode: _userState.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: HomeScreen(userState: _userState),
        );
      },
    );
  }
}
