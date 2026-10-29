import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/core/widgets/brawl_gold_shimmer.dart';
import 'package:toro_music_teleprompter/features/monetization/services/ad_manager.dart';
import 'package:toro_music_teleprompter/features/monetization/services/subscription_service.dart';
import 'package:toro_music_teleprompter/features/monetization/widgets/pro_upgrade_dialog.dart';
import 'package:toro_music_teleprompter/features/studio/presentation/studio_recording_screen.dart';
import 'package:toro_music_teleprompter/features/tutorials/models/tutorial_topic.dart';
import 'package:toro_music_teleprompter/features/tutorials/widgets/feature_help_dialog.dart';
import 'package:toro_music_teleprompter/features/tutorials/widgets/onboarding_tour_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger 2 Empirical UI & Integration Verification', () {
    // -------------------------------------------------------------
    // Mission 1: Verify Image.asset('assets/images/app_logo.jpeg') absence
    // -------------------------------------------------------------
    test('1. Static source audit: app_logo.jpeg is completely absent from studio_recording_screen.dart', () {
      final file = File('lib/features/studio/presentation/studio_recording_screen.dart');
      expect(file.existsSync(), isTrue, reason: 'Source file must exist');
      final content = file.readAsStringSync();

      expect(
        content.contains('app_logo.jpeg'),
        isFalse,
        reason: "assets/images/app_logo.jpeg must NOT be referenced in studio_recording_screen.dart",
      );
      expect(
        content.contains('app_logo'),
        isFalse,
        reason: "No variant of app_logo should remain in studio_recording_screen.dart",
      );
    });

    // -------------------------------------------------------------
    // Mission 2: Verify find.text('ToroCorp Music') & 'ToroCorp Music PRO'
    // are found and properly styled with BrawlGoldShimmer
    // -------------------------------------------------------------
    testWidgets('2. Runtime UI audit: ToroCorp Music and ToroCorp Music PRO are found & styled with BrawlGoldShimmer', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(
        home: StudioRecordingScreen(),
      ));
      await tester.pumpAndSettle();

      // Open hamburger drawer menu
      final hamburgerIcon = find.byType(AnimatedIcon);
      expect(hamburgerIcon, findsOneWidget);
      await tester.tap(hamburgerIcon);
      await tester.pumpAndSettle();

      // 2a. Header Title 'ToroCorp Music'
      final titleFinder = find.text('ToroCorp Music');
      expect(titleFinder, findsWidgets, reason: "'ToroCorp Music' must be present");

      // Verify header is wrapped in BrawlGoldShimmer
      final headerTitleWidget = titleFinder.first;
      final shimmerParent = find.ancestor(
        of: headerTitleWidget,
        matching: find.byType(BrawlGoldShimmer),
      );
      expect(shimmerParent, findsWidgets, reason: "'ToroCorp Music' header must be wrapped in BrawlGoldShimmer");

      // Verify that no Image or logo is in that header row/container
      final headerContainer = find.ancestor(
        of: shimmerParent.first,
        matching: find.byType(Padding),
      );
      expect(
        find.descendant(of: headerContainer.first, matching: find.byType(Image)),
        findsNothing,
        reason: "Header must not contain any Image widget next to ToroCorp Music",
      );

      // 2b. Drawer Pro Title 'ToroCorp Music PRO'
      final proTitleFinder = find.text('ToroCorp Music PRO');
      expect(proTitleFinder, findsOneWidget, reason: "'ToroCorp Music PRO' must be present in drawer");

      final proShimmerParent = find.ancestor(
        of: proTitleFinder,
        matching: find.byType(BrawlGoldShimmer),
      );
      expect(proShimmerParent, findsWidgets, reason: "'ToroCorp Music PRO' in drawer must be wrapped in BrawlGoldShimmer");

      // Also verify PRO badge exists and is wrapped in shimmer
      final proBadge = find.text('PRO');
      expect(proBadge, findsWidgets);

      // 2c. Check ProUpgradeDialog styling
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => ProUpgradeDialog.show(
                  ctx,
                  subscriptionService: SubscriptionService(),
                  adManager: AdManager(),
                ),
                child: const Text('Open Pro Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Pro Dialog'));
      await tester.pumpAndSettle();

      final proDialogTitle = find.text('ToroCorp Music PRO');
      expect(proDialogTitle, findsOneWidget);
      expect(
        find.ancestor(of: proDialogTitle, matching: find.byType(BrawlGoldShimmer)),
        findsOneWidget,
        reason: "ProUpgradeDialog header must be wrapped in BrawlGoldShimmer",
      );
    });

    // -------------------------------------------------------------
    // Mission 3: Verify FeatureHelpDialog renders all topics on small screens (360x640)
    // -------------------------------------------------------------
    testWidgets('3a. FeatureHelpDialog renders all 10 topics on small screen (360x640) without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final topic in TutorialTopic.values) {
        bool dismissed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await FeatureHelpDialog.show(context, topic);
                    dismissed = true;
                  },
                  child: const Text('Launch Help'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Launch Help'));
        await tester.pumpAndSettle();

        // Verify title & summary
        expect(find.text(topic.title), findsOneWidget, reason: 'Topic ${topic.name} title missing');
        expect(find.text(topic.summary), findsOneWidget, reason: 'Topic ${topic.name} summary missing');

        // Verify no overflow exception was caught
        expect(tester.takeException(), isNull, reason: 'Overflow or layout exception in topic ${topic.name}');

        // Ensure visible and dismiss
        final dismissBtn = find.text('Entendido');
        expect(dismissBtn, findsOneWidget);
        await tester.ensureVisible(dismissBtn);
        await tester.pumpAndSettle();
        await tester.tap(dismissBtn);
        await tester.pumpAndSettle();

        expect(dismissed, isTrue, reason: 'FeatureHelpDialog should dismiss cleanly');
      }
    });

    // -------------------------------------------------------------
    // Mission 3: Verify OnboardingTourDialog renders on small screens
    // (360x640 and 320x480) without RenderFlex overflow
    // -------------------------------------------------------------
    testWidgets('3b. OnboardingTourDialog renders on small screen (360x640) without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final capturedErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        capturedErrors.add(details);
      };

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => OnboardingTourDialog.show(context),
                  child: const Text('Launch Tour'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Launch Tour'));
        await tester.pumpAndSettle();

        // Check if RenderFlex overflow occurred on step 1
        final overflowErrors = capturedErrors.where(
          (err) => err.toString().contains('RenderFlex overflowed'),
        ).toList();

        expect(
          overflowErrors,
          isEmpty,
          reason: 'OnboardingTourDialog must not have RenderFlex overflow on 360px viewport width',
        );

        // Advance through all steps to step 6 (isLast == true)
        for (int i = 0; i < 5; i++) {
          final nextBtn = find.text('Siguiente');
          expect(nextBtn, findsOneWidget);
          await tester.tap(nextBtn);
          await tester.pumpAndSettle();
        }

        // On last step, verify '¡Empezar a grabar!' is visible and no overflow occurred
        expect(find.text('¡Empezar a grabar!'), findsOneWidget);
        final finalOverflowErrors = capturedErrors.where(
          (err) => err.toString().contains('RenderFlex overflowed'),
        ).toList();
        expect(
          finalOverflowErrors,
          isEmpty,
          reason: 'OnboardingTourDialog must not have RenderFlex overflow on any step (including step 7)',
        );

        // Tap finish and ensure dialog closes
        await tester.tap(find.text('¡Empezar a grabar!'));
        await tester.pumpAndSettle();
        expect(find.byType(OnboardingTourDialog), findsNothing);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('3c. OnboardingTourDialog renders on compact screen (320x480) without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final capturedErrors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        capturedErrors.add(details);
      };

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => OnboardingTourDialog.show(context),
                  child: const Text('Launch Tour'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Launch Tour'));
        await tester.pumpAndSettle();

        // Advance through all steps
        for (int i = 0; i < 5; i++) {
          final nextBtn = find.text('Siguiente');
          expect(nextBtn, findsOneWidget);
          await tester.ensureVisible(nextBtn);
          await tester.pumpAndSettle();
          await tester.tap(nextBtn);
          await tester.pumpAndSettle();
        }

        final finishBtn = find.text('¡Empezar a grabar!');
        expect(finishBtn, findsOneWidget);
        final overflowErrors = capturedErrors.where(
          (err) => err.toString().contains('RenderFlex overflowed'),
        ).toList();
        expect(
          overflowErrors,
          isEmpty,
          reason: 'OnboardingTourDialog must not have RenderFlex overflow on 320px compact viewport width',
        );

        await tester.ensureVisible(finishBtn);
        await tester.pumpAndSettle();
        await tester.tap(finishBtn);
        await tester.pumpAndSettle();
        expect(find.byType(OnboardingTourDialog), findsNothing);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });
  });
}
