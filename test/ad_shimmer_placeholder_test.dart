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

    testWidgets('renders nativeMedium variant without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdShimmerPlaceholder(
              variant: AdShimmerVariant.nativeMedium,
              height: 320,
            ),
          ),
        ),
      );

      expect(find.byType(AdShimmerPlaceholder), findsOneWidget);
    });

    testWidgets('renders nativeSmall variant without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdShimmerPlaceholder(
              variant: AdShimmerVariant.nativeSmall,
              height: 90,
            ),
          ),
        ),
      );

      expect(find.byType(AdShimmerPlaceholder), findsOneWidget);
    });

    testWidgets('renders mediumRectangle variant without errors',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdShimmerPlaceholder(
              variant: AdShimmerVariant.mediumRectangle,
            ),
          ),
        ),
      );

      expect(find.byType(AdShimmerPlaceholder), findsOneWidget);
    });
  });
}
