import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/core/widgets/brawl_gold_shimmer.dart';

void main() {
  group('BrawlGoldShimmer Tests', () {
    tearDown(() {
      BrawlGoldShimmer.enableAnimationsInTests = false;
    });

    testWidgets('mounts and renders child widget correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BrawlGoldShimmer(
              child: Text('ToroCorp Music'),
            ),
          ),
        ),
      );

      expect(find.text('ToroCorp Music'), findsOneWidget);
      expect(find.byType(BrawlGoldShimmer), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('pumpAndSettle completes without timeout in test environment', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BrawlGoldShimmer(
              child: Text('ToroCorp Music PRO'),
            ),
          ),
        ),
      );

      // Crucial test safety: pumpAndSettle must resolve immediately without hanging
      await tester.pumpAndSettle();
      expect(find.text('ToroCorp Music PRO'), findsOneWidget);
    });

    testWidgets('renders child directly without ShaderMask when isShimmering is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BrawlGoldShimmer(
              isShimmering: false,
              child: Text('Static Non-Shimmer Text'),
            ),
          ),
        ),
      );

      expect(find.text('Static Non-Shimmer Text'), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('supports enabled parameter as alias for isShimmering', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BrawlGoldShimmer(
              enabled: false,
              child: Text('Disabled Shimmer'),
            ),
          ),
        ),
      );

      expect(find.text('Disabled Shimmer'), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('toggles between shimmering and non-shimmering state dynamically', (tester) async {
      bool shimmerActive = true;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    BrawlGoldShimmer(
                      isShimmering: shimmerActive,
                      child: const Text('Dynamic Title'),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => shimmerActive = !shimmerActive),
                      child: const Text('Toggle'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      expect(find.byType(ShaderMask), findsOneWidget);

      await tester.tap(find.text('Toggle'));
      await tester.pump();

      expect(find.byType(ShaderMask), findsNothing);

      await tester.tap(find.text('Toggle'));
      await tester.pump();

      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('animates over time when enableAnimationsInTests is explicitly enabled', (tester) async {
      BrawlGoldShimmer.enableAnimationsInTests = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BrawlGoldShimmer(
              duration: Duration(milliseconds: 1000),
              child: Text('Animated Shimmer'),
            ),
          ),
        ),
      );

      expect(find.byType(ShaderMask), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Animated Shimmer'), findsOneWidget);
    });
  });
}
