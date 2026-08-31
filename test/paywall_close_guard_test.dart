import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaywallCloseGuard', () {
    testWidgets('renders builder and bypasses ad if user is entitled',
        (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PaywallCloseGuard(
            isEntitled: true,
            adUnitId: 'test-ad-unit',
            onDismiss: () => dismissed = true,
            builder: (context, attemptDismiss, isLoading) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: attemptDismiss,
                  child: const Text('Close Paywall'),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Close Paywall'), findsOneWidget);

      await tester.tap(find.text('Close Paywall'));
      await tester.pump();

      expect(dismissed, true);
    });

    testWidgets('dismisses immediately when no adUnitId provided',
        (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PaywallCloseGuard(
            isEntitled: false,
            adUnitId: null,
            onDismiss: () => dismissed = true,
            builder: (context, attemptDismiss, isLoading) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: attemptDismiss,
                  child: const Text('Close Paywall'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Close Paywall'));
      await tester.pump();

      expect(dismissed, true);
    });
  });
}
