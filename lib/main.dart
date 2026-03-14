import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'onboarding/splash_screen.dart';
import 'services/guardian_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeGuardianService();

  // Force portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Full-screen immersive mode
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0F1E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ShieldXApp());
}

class ShieldXApp extends StatelessWidget {
  const ShieldXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShieldX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B8BFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0F1E),
      ),
      home: const SplashScreen(),
    );
  }
}
