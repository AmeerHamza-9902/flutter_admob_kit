import 'package:flutter/material.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AdMobKit.initialize(
    config: const AdMobConfig(
      autoResumeAppOpen: true,
      enableUmpConsent: true,
      testMode: true,
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
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
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
                const PrivacyConsentButton(),
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
                            color: _isEntitled
                                ? Colors.green
                                : Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                ElevatedButton.icon(
                  icon: const Icon(Icons.fullscreen),
                  label: const Text('Show Interstitial (show: true)'),
                  onPressed: () async {
                    const bool shouldShow = true;
                    final shown = await AdMobKit.interstitial.show(shouldShow);
                    debugPrint('Interstitial was shown: $shown');
                  },
                ),
                const SizedBox(height: 8),

                OutlinedButton.icon(
                  icon: const Icon(Icons.block),
                  label: const Text('Show Interstitial (show: false)'),
                  onPressed: () async {
                    final shown = await AdMobKit.interstitial.show(false);
                    debugPrint('Interstitial was shown: $shown');
                  },
                ),
                const SizedBox(height: 12),

                ElevatedButton.icon(
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('Show Rewarded Ad (+10 Coins)'),
                  onPressed: () async {
                    await AdMobKit.rewarded.show(
                      true,
                      onReward: (reward) {
                        if (!mounted) return;
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

                ElevatedButton.icon(
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Open Paywall (Close Guard)'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PaywallCloseGuard(
                          onDismiss: () => Navigator.of(context).pop(),
                          child: Builder(
                            builder: (paywallContext) => Scaffold(
                              appBar: AppBar(
                                title: const Text('Upgrade to Pro'),
                              ),
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
                                          PaywallCloseGuard.dismiss(
                                            paywallContext,
                                          ),
                                      child: const Text('Close Paywall'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                const Text(
                  'Native Ad (Medium Native, 130dp):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const NativeAdWidget.mediumNative(height: 130),
                const SizedBox(height: 24),
                const Text(
                  'Native Ad (Big Native):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const NativeAdWidget.bigNative(),
              ],
            ),
          ),

          const BannerAdWidget(),
        ],
      ),
    );
  }
}
