import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toro_music_teleprompter/core/theme/app_theme.dart';
import 'package:toro_music_teleprompter/features/scripts/models/song_script.dart';
import 'package:toro_music_teleprompter/features/scripts/services/chordpro_parser.dart';
import 'package:toro_music_teleprompter/features/studio/presentation/studio_recording_screen.dart';

/// Test helpers and common fixtures for ToroCorp Music E2E testing suite.
class E2ETestHelpers {
  /// Standard mobile viewport (1080x2400 @ 2.0 dpr)
  static void setupTestViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  /// Sets up mock shared preferences with defaults
  static void setupMockStorage([Map<String, Object>? values]) {
    SharedPreferences.setMockInitialValues(values ?? {});
  }

  /// Pumps the main Studio recording screen wrapped in dark OLED theme
  static Future<void> pumpStudioScreen(WidgetTester tester) async {
    setupTestViewport(tester);
    setupMockStorage();

    await tester.pumpWidget(
      MaterialApp(
        title: 'ToroCorp Music',
        theme: AppTheme.darkOledTheme,
        darkTheme: AppTheme.darkOledTheme,
        home: const StudioRecordingScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens the studio lateral menu (drawer) by tapping the animated hamburger icon
  static Future<void> openLateralMenu(WidgetTester tester) async {
    final menuButton = find.byType(AnimatedIcon);
    expect(menuButton, findsOneWidget, reason: 'Hamburger menu icon (AnimatedIcon) must exist on studio screen');
    await tester.tap(menuButton);
    await tester.pumpAndSettle();
  }

  /// Closes the studio lateral menu by tapping the animated close icon
  static Future<void> closeLateralMenu(WidgetTester tester) async {
    final menuButton = find.byType(AnimatedIcon);
    expect(menuButton, findsOneWidget);
    await tester.tap(menuButton);
    await tester.pumpAndSettle();
  }

  /// Sample hit song in ChordPro format for E2E testing
  static const String sampleChordProSong = '''
{title: De Música Ligera}
{artist: Soda Stereo}

[Bm]Ella durmió al calor de las [G]masas
[D]Y yo desperté [A]queriendo soñarla
[Bm]Algún tiempo atrás pensé en es[G]cribirle
[D]Que nunca sorteé las [A]trampas del amor
''';

  /// Generates a SongScript fixture from ChordPro text
  static SongScript createSampleSong() {
    return ChordProParser().parse(
      sampleChordProSong,
      title: 'De Música Ligera',
      artist: 'Soda Stereo',
    );
  }

  /// Validates that a byte array conforms to a standard RIFF/WAVE PCM audio format
  static bool isValidPcmWav(Uint8List bytes) {
    if (bytes.length < 44) return false;
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    final fmt = String.fromCharCodes(bytes.sublist(12, 16));
    return riff == 'RIFF' && wave == 'WAVE' && fmt == 'fmt ';
  }
}
