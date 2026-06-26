import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: ['4f8c3dd5f38a948cf532c9960e7389c5']),
  );
  await MobileAds.instance.initialize();
  runApp(const FuezoneApp());
}

class FuezoneApp extends StatelessWidget {
  const FuezoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fuezone',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

