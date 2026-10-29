import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/core/widgets/brawl_gold_shimmer.dart';

void main() {
  group('BrawlGoldShimmer Adversarial & Stress Suite', () {
    tearDown(() {
      BrawlGoldShimmer.enableAnimationsInTests = false;
    });

    group('Diverse Child Widgets', () {
      testWidgets('handles empty Text widget gracefully', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BrawlGoldShimmer(
                child: Text(''),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BrawlGoldShimmer), findsOneWidget);
        expect(find.byType(ShaderMask), findsOneWidget);
      });

      testWidgets('handles Unicode, emojis, and multi-line strings', (tester) async {
        const textWithEmojis = '🎸⚡ ToroCorp Music Pro — ¡El sonido definitivo! 🔥✨\nLínea 2: 𝄞 𝄢 Acordes de Requinto 𝅘𝅥';
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BrawlGoldShimmer(
                child: Text(
                  textWithEmojis,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(textWithEmojis), findsOneWidget);
        expect(find.byType(ShaderMask), findsOneWidget);
      });

      testWidgets('handles Icon widgets with size variations (zero, standard, large)', (tester) async {
        for (final size in [0.0, 16.0, 48.0, 128.0]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: BrawlGoldShimmer(
                  child: Icon(Icons.star, size: size, color: Colors.white),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(Icon), findsOneWidget);
          expect(find.byType(ShaderMask), findsOneWidget);
        }
      });

      testWidgets('handles Container widgets with decoration, borders, and colors', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BrawlGoldShimmer(
                child: Container(
                  width: 140,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Center(child: Text('Pill Badge')),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Pill Badge'), findsOneWidget);
        expect(find.byType(ShaderMask), findsOneWidget);
      });

      testWidgets('handles zero-sized child widgets (Rect.zero boundary condition)', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BrawlGoldShimmer(
                child: SizedBox.shrink(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(ShaderMask), findsOneWidget);
      });

      testWidgets('handles complex RichText with multiple nested TextSpans', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BrawlGoldShimmer(
                child: RichText(
                  text: const TextSpan(
                    text: 'ToroCorp ',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                    children: [
                      TextSpan(
                        text: 'Music ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'PRO',
                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.amber),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RichText), findsWidgets);
        expect(find.byType(ShaderMask), findsOneWidget);
      });

      testWidgets('handles nested BrawlGoldShimmer widgets without crash', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BrawlGoldShimmer(
                child: BrawlGoldShimmer(
                  child: Text('Double Shimmer'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Double Shimmer'), findsOneWidget);
        expect(find.byType(ShaderMask), findsNWidgets(2));
      });
    });

    group('Rapid State Re-renders & Mutation Stress', () {
      testWidgets('survives 100 rapid shimmer toggle re-renders without ticker leaks', (tester) async {
        bool isShimmer = true;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      BrawlGoldShimmer(
                        isShimmering: isShimmer,
                        child: const Text('Rapid Toggle'),
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() => isShimmer = !isShimmer),
                        child: const Text('Toggle'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );

        // Rapidly tap and toggle 100 times
        for (int i = 0; i < 100; i++) {
          await tester.tap(find.text('Toggle'));
          await tester.pump();
        }

        // Must settle cleanly without unhandled ticker exceptions
        await tester.pumpAndSettle();
        expect(find.text('Rapid Toggle'), findsOneWidget);
      });

      testWidgets('survives rapid child widget swapping (Text -> Icon -> Container -> RichText)', (tester) async {
        int childIndex = 0;
        final children = [
          const Text('Text Child', key: ValueKey('text')),
          const Icon(Icons.star, key: ValueKey('icon')),
          Container(key: const ValueKey('container'), width: 50, height: 50, color: Colors.white),
          RichText(
            key: const ValueKey('richtext'),
            text: const TextSpan(text: 'Rich', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox.shrink(key: ValueKey('shrink')),
        ];

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      BrawlGoldShimmer(
                        child: children[childIndex],
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() {
                          childIndex = (childIndex + 1) % children.length;
                        }),
                        child: const Text('NextChild'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );

        for (int i = 0; i < 25; i++) {
          await tester.tap(find.text('NextChild'));
          await tester.pump();
        }

        await tester.pumpAndSettle();
        expect(find.byType(BrawlGoldShimmer), findsOneWidget);
      });

      testWidgets('survives rapid mount and unmount cycles (20 times)', (tester) async {
        bool isMounted = true;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      if (isMounted)
                        const BrawlGoldShimmer(
                          child: Text('Mount Cycle'),
                        )
                      else
                        const SizedBox.shrink(),
                      ElevatedButton(
                        onPressed: () => setState(() => isMounted = !isMounted),
                        child: const Text('ToggleMount'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );

        for (int i = 0; i < 20; i++) {
          await tester.tap(find.text('ToggleMount'));
          await tester.pump();
        }

        await tester.pumpAndSettle();
      });

      testWidgets('survives dynamic duration changes during lifecycle', (tester) async {
        Duration currentDuration = const Duration(milliseconds: 1000);

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      BrawlGoldShimmer(
                        duration: currentDuration,
                        child: const Text('Duration Test'),
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() {
                          currentDuration = Duration(
                            milliseconds: currentDuration.inMilliseconds + 500,
                          );
                        }),
                        child: const Text('ChangeDuration'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );

        for (int i = 0; i < 10; i++) {
          await tester.tap(find.text('ChangeDuration'));
          await tester.pump();
        }

        await tester.pumpAndSettle();
        expect(find.text('Duration Test'), findsOneWidget);
      });
    });

    group('pumpAndSettle Never Hangs or Times Out', () {
      testWidgets('pumpAndSettle resolves immediately with 50 simultaneous shimmers', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                itemCount: 50,
                itemBuilder: (context, index) {
                  return BrawlGoldShimmer(
                    child: Text('Shimmer Item $index'),
                  );
                },
              ),
            ),
          ),
        );

        // Crucial test guarantee: pumpAndSettle must not time out despite 50 active shimmer widgets
        await tester.pumpAndSettle();
        expect(find.text('Shimmer Item 0'), findsOneWidget);
      });

      testWidgets('enabling and disabling enableAnimationsInTests leaves clean settle state', (tester) async {
        BrawlGoldShimmer.enableAnimationsInTests = true;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BrawlGoldShimmer(
                duration: Duration(milliseconds: 500),
                child: Text('Animating in Test'),
              ),
            ),
          ),
        );

        // Advance frames with manual pump
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // Now disable animations in test
        BrawlGoldShimmer.enableAnimationsInTests = false;

        // Trigger didUpdateWidget to reflect change
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BrawlGoldShimmer(
                duration: Duration(milliseconds: 500),
                child: Text('Animating in Test'),
              ),
            ),
          ),
        );

        // pumpAndSettle must now resolve cleanly
        await tester.pumpAndSettle();
        expect(find.text('Animating in Test'), findsOneWidget);
      });
    });

    group('API Property Conformance', () {
      testWidgets('enabled parameter takes precedence over isShimmering when provided', (tester) async {
        // enabled: false overrides isShimmering: true
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BrawlGoldShimmer(
                isShimmering: true,
                enabled: false,
                child: Text('Override False'),
              ),
            ),
          ),
        );
        expect(find.byType(ShaderMask), findsNothing);

        // enabled: true overrides isShimmering: false
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BrawlGoldShimmer(
                isShimmering: false,
                enabled: true,
                child: Text('Override True'),
              ),
            ),
          ),
        );
        expect(find.byType(ShaderMask), findsOneWidget);
      });
    });
  });
}
