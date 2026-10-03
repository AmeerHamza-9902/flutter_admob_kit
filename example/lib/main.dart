import 'package:flutter/material.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize AdMobKit once with centralized configuration.
  await AdMobKit.initialize(
    config: const AdMobConfig(
      android: AdPlatformConfig(
        interstitial: 'ca-app-pub-3940256099942544/1033173712',
        rewarded: 'ca-app-pub-3940256099942544/5224354917',
        appOpen: 'ca-app-pub-3940256099942544/9257390910',
        banner: 'ca-app-pub-3940256099942544/9214589741',
        native: 'ca-app-pub-3940256099942544/2247696110',
      ),
      ios: AdPlatformConfig(
        interstitial: 'ca-app-pub-3940256099942544/4411468910',
        rewarded: 'ca-app-pub-3940256099942544/1712485313',
        appOpen: 'ca-app-pub-3940256099942544/5575463023',
        banner: 'ca-app-pub-3940256099942544/2435281174',
        native: 'ca-app-pub-3940256099942544/3986624511',
      ),
      autoResumeAppOpen: true,
      enableUmpConsent: false,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_admob_kit Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _coins = 0;
  bool _isEntitled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_admob_kit'),
        actions: [
          IconButton(
            tooltip: _isEntitled ? 'Entitled (Ad-Free)' : 'Free Tier',
            icon: Icon(_isEntitled ? Icons.star : Icons.star_border),
            onPressed: () {
              setState(() {
                _isEntitled = !_isEntitled;
                AdMobKit.setEntitled(_isEntitled);
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rewarded Coins: $_coins',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isEntitled
                              ? 'Premium Member: Ads are suppressed'
                              : 'Free User: Ads enabled',
                          style: TextStyle(
                            color:
                                _isEntitled ? Colors.green : Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 1. Interstitial Ad Trigger
                ElevatedButton.icon(
                  icon: const Icon(Icons.fullscreen),
                  label: const Text('Show Interstitial (Remote Config: true)'),
                  onPressed: () async {
                    // In real apps, pass your remote config boolean flag:
                    const bool shouldShow = true;
                    final shown = await AdMobKit.interstitial.show(shouldShow);
                    debugPrint('Interstitial was shown: $shown');
                  },
                ),
                const SizedBox(height: 8),

                // 2. Interstitial Ad with false (No ad shown, zero spam)
                OutlinedButton.icon(
                  icon: const Icon(Icons.block),
                  label: const Text('Show Interstitial (Remote Config: false)'),
                  onPressed: () async {
                    final shown = await AdMobKit.interstitial.show(false);
                    debugPrint('Interstitial was shown: $shown');
                  },
                ),
                const SizedBox(height: 12),

                // 3. Rewarded Ad Trigger
                ElevatedButton.icon(
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('Show Rewarded Ad (+10 Coins)'),
                  onPressed: () async {
                    await AdMobKit.rewarded.show(
                      true,
                      onReward: (reward) {
                        setState(() {
                          _coins += reward.amount.toInt();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Earned ${reward.amount} ${reward.type}!',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 4. Paywall Screen with Safe Interstitial Close Guard
                ElevatedButton.icon(
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Open Paywall (Close Guard)'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PaywallCloseGuard(
                          onDismiss: () => Navigator.of(context).pop(),
                          child: Scaffold(
                            appBar: AppBar(title: const Text('Upgrade to Pro')),
                            body: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.workspace_premium,
                                    size: 80,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Unlock All Features',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: () =>
                                        PaywallCloseGuard.dismiss(context),
                                    child: const Text('Close Paywall'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 5. Native Ad
                const Text(
                  'Native Ad (Medium Template):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const NativeAdWidget.medium(),
              ],
            ),
          ),

          // 6. Adaptive Banner Ad at Bottom
          const BannerAdWidget(),
        ],
      ),
    );
  }
}
