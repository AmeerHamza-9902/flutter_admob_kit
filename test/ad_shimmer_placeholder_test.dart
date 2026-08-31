import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() {
  group('AdShimmerPlaceholder', () {
    testWidgets('renders banner variant without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdShimmerPlaceholder(
              variant: AdShimmerVariant.banner,
              height: 50,
            ),
          ),
        ),
      );

      expect(find.byType(AdShimmerPlaceholder), findsOneWidget);
    });

    testWidgets('renders native variant without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdShimmerPlaceholder(
              variant: AdShimmerVariant.nativeMedium,
              height: 300,
            ),
          ),
        ),
      );

      expect(find.byType(AdShimmerPlaceholder), findsOneWidget);
    });
  });
}
