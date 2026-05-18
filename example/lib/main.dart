import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FlutterAdmobKit.instance.init(
    remoteKey: 'ads_config',
    localAsset: 'assets/ads_config.json',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_admob_kit Example',
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      home: const SplashScreen(),
    );
  }
}

// ─── Splash Screen ────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _showAdsAndNavigate();
  }

  Future<void> _showAdsAndNavigate() async {
    await FlutterAdmobKit.instance.showSplashAppOpen();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: FlutterLogo(size: 100)),
    );
  }
}

// ─── Home Screen ──────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kit = FlutterAdmobKit.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_admob_kit Demo')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ElevatedButton(
                  onPressed: () => kit.onBottomNavClick(context),
                  child: const Text('Simulate bottom nav click'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => kit.onGeneralClick(context),
                  child: const Text('Simulate general click'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => kit.showProCloseInterstitial(context),
                  child: const Text('Show Pro Close Interstitial'),
                ),
                const SizedBox(height: 24),
                // Native ad
                NativeAdWidget(screenKey: 'home_screen'),
              ],
            ),
          ),
          // Banner at bottom
          BannerAdWidget(screenKey: 'home_screen'),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: (_) => kit.onBottomNavClick(context),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
