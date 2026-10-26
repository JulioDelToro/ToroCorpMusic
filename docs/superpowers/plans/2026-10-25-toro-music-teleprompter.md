# Toro Music Teleprompter & Video Studio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir una aplicación multiplataforma (Android, iOS, PC) para guitarristas y cantantes que graba video en alta resolución (hasta 4K) con filtro de belleza GLSL, teleprompter inteligente pegado a la cámara que sigue la voz cantada mediante IA local, notas musicales alineadas debajo de la letra, afinador, diccionario de acordes, inicio por gestos/voz, y monetización freemium segura.

**Architecture:** Aplicación Flutter modular dividida en servicios desacoplados: pipeline de cámara con shaders GLSL de belleza, motor de alineación vocal con aislamiento acústico de guitarra, teleprompter con posicionamiento ocular óptimo, procesador de ChordPro/PDF, módulo de herramientas para guitarristas (afinador + acordes), compositor de grabación limpia vs subtítulos quemados, y sistema de anuncios/suscripción.

**Tech Stack:** Flutter 3.x / Dart 3.x, Flutter Camera (MediaCodec/AVFoundation), Custom GLSL Fragment Shaders, Google MediaPipe/ML Kit (Palma), Vosk/Whisper On-Device STT, PDF parsing (pdfx), In-App Purchase & Google AdMob, Google Fonts / SF Pro & SF Mono.

**Spec:** [docs/superpowers/specs/2026-10-25-toro-music-teleprompter-design.md](file:///c:/Users/juli_/Videos/ToroCorpMusic/docs/superpowers/specs/2026-10-25-toro-music-teleprompter-design.md)

## Global Constraints

- Licenciamiento: Exclusivamente librerías con licencia MIT, BSD o Apache 2.0. Prohibido el uso de FFmpeg GPL o librerías AGPL.
- Tema Visual: Fondo Negro Puro OLED (`#000000`), superficies `#1E1E1E`/`#2A2A2A`, texto Blanco (`#FFFFFF`).
- Tipografía: San Francisco (`SF Pro Display / Text`) para letra cantada e interfaz; `SF Mono` para notas y acordes inferiores.
- Splash Screen: `App_splash_screen_intro_1080p_20261025201354.mp4` debe reproducirse al inicio en pantalla completa con skip-on-tap.
- Seguimiento de Voz: La IA sigue estrictamente las palabras cantadas, no las notas ni la guitarra.
- Posición de Notas: Siempre en la fila inferior inmediatamente debajo de cada palabra o sílaba.

## Review Focus

1. Ruido de rasgueo acústico disparando falsos avances en la letra: el filtro pasa-banda vocal (100Hz - 3.4kHz) y la compuerta de ruido deben bloquear transientes de guitarra.
2. Latencia de video al grabar en 1080p con shader de belleza activo: el shader bilateral debe ejecutarse en GPU a 60 fps estables sin sobrecargar la CPU.
3. Precisión en alineación de acordes bajo texto con palabras largas o compases vacíos: `SF Mono` y el parser deben preservar la posición exacta sin desfasar la métrica visual.
4. Desconexión de permisos de cámara o micrófono al abrir la app: la UI debe mostrar estados degradados claros con botón de reintentar sin crashear.
5. Restauración de compras Pro y modo offline: si el usuario no tiene internet, las funciones Pro compradas deben permanecer activas en caché local.

---

### Task 1: Scaffolding del Proyecto Flutter, Tema OLED y Tipografía SF Pro

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/core/theme/app_theme.dart`
- Create: `lib/core/constants/app_colors.dart`
- Create: `lib/core/constants/app_typography.dart`
- Create: `lib/main.dart`
- Test: `test/core/theme_test.dart`

**Interfaces:**
- Consumes: Flutter SDK
- Produces: `AppTheme.darkOledTheme`, `AppColors.pureBlackOled`, `AppTypography.sfProLyricStyle`, `AppTypography.sfMonoChordStyle`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/core/constants/app_colors.dart';
import 'package:toro_music_teleprompter/core/theme/app_theme.dart';

void main() {
  test('Theme enforces Pure Black OLED background and SF typography', () {
    final theme = AppTheme.darkOledTheme;
    expect(theme.scaffoldBackgroundColor, equals(AppColors.pureBlackOled));
    expect(theme.scaffoldBackgroundColor, equals(const Color(0xFF000000)));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme_test.dart`
Expected: FAIL with compilation error (missing files or package).

- [ ] **Step 3: Implement project scaffolding and theme in `lib/core/`**

Create `pubspec.yaml` with dependencies (`video_player`, `camera`, `flutter_bloc` or `provider`, `google_fonts`, `shared_preferences`) and implement `AppColors`, `AppTypography` with SF Pro / SF Mono font definitions, and `AppTheme`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml lib/ test/
git commit -m "feat: initialize Flutter scaffolding with OLED black theme and SF Pro typography"
```

---

### Task 2: Reproductor de Splash Screen con Video MP4

**Files:**
- Create: `lib/features/splash/presentation/splash_video_screen.dart`
- Create: `lib/features/splash/controllers/splash_video_controller.dart`
- Modify: `lib/main.dart`
- Test: `test/features/splash/splash_video_screen_test.dart`

**Interfaces:**
- Consumes: `App_splash_screen_intro_1080p_20261025201354.mp4` asset
- Produces: `SplashVideoScreen`, `SplashVideoController.onVideoFinished` callback

- [ ] **Step 1: Write the failing test**

```dart
// test/features/splash/splash_video_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/splash/presentation/splash_video_screen.dart';

void main() {
  testWidgets('Splash screen contains skip gesture detector and black background', (tester) async {
    bool skipped = false;
    await tester.pumpWidget(MaterialApp(
      home: SplashVideoScreen(onFinished: () => skipped = true),
    ));
    expect(find.byType(GestureDetector), findsWidgets);
    await tester.tap(find.byType(GestureDetector).first);
    expect(skipped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/splash/splash_video_screen_test.dart`
Expected: FAIL with "SplashVideoScreen not found".

- [ ] **Step 3: Implement `SplashVideoScreen` and `SplashVideoController`**

Implement video player initialization loading the local 1080p asset with hardware acceleration, fade-out transition, and instant skip on user tap.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/splash/splash_video_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/splash/ test/features/splash/
git commit -m "feat: implement intro splash video player with skip-on-tap gesture"
```

---

### Task 3: Parser de Canciones ChordPro y Extractor de PDFs con Notas Inferiores

**Files:**
- Create: `lib/features/scripts/models/lyric_token.dart`
- Create: `lib/features/scripts/models/song_script.dart`
- Create: `lib/features/scripts/services/chordpro_parser.dart`
- Create: `lib/features/scripts/services/pdf_script_extractor.dart`
- Test: `test/features/scripts/chordpro_parser_test.dart`
- Test: `test/features/scripts/pdf_extractor_test.dart`

**Interfaces:**
- Consumes: Texto crudo con acordes o archivo PDF
- Produces: `SongScript`, `List<LyricLine>`, `LyricToken(word: String, chordUnderneath: String?)`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/scripts/chordpro_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/scripts/services/chordpro_parser.dart';

void main() {
  test('ChordproParser binds chords directly beneath their corresponding word', () {
    const rawChordPro = "De [G]música [D]ligera...";
    final parser = ChordProParser();
    final song = parser.parse(rawChordPro);
    
    expect(song.lines.first.tokens.length, equals(3));
    expect(song.lines.first.tokens[0].word, equals("De"));
    expect(song.lines.first.tokens[0].chordUnderneath, isNull);
    expect(song.lines.first.tokens[1].word, equals("música"));
    expect(song.lines.first.tokens[1].chordUnderneath, equals("G"));
    expect(song.lines.first.tokens[2].word, equals("ligera..."));
    expect(song.lines.first.tokens[2].chordUnderneath, equals("D"));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/scripts/chordpro_parser_test.dart`
Expected: FAIL with "ChordProParser not defined".

- [ ] **Step 3: Implement `ChordProParser`, `PdfScriptExtractor` and models**

Implement tokenization that associates musical notes below words and handles PDF text extraction with regex chord detection (`^[A-G][b#]?(m|maj|min|dim|aug|7|sus|add)?[0-9]?$`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/scripts/chordpro_parser_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/scripts/ test/features/scripts/
git commit -m "feat: implement ChordPro parser and PDF extractor with bottom chord alignment"
```

---

### Task 4: Diccionario de Acordes Visual e Interactivo

**Files:**
- Create: `lib/features/chords/models/chord_definition.dart`
- Create: `lib/features/chords/data/guitar_chords_database.dart`
- Create: `lib/features/chords/widgets/fretboard_diagram_dialog.dart`
- Test: `test/features/chords/guitar_chords_database_test.dart`

**Interfaces:**
- Consumes: Nombre de acorde (ej. "G", "Em7", "C#m")
- Produces: `ChordDefinition(name, frets, fingers, baseFret)`, `FretboardDiagramDialog`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/chords/guitar_chords_database_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/chords/data/guitar_chords_database.dart';

void main() {
  test('GuitarChordsDatabase returns correct fingerings for standard chords', () {
    final db = GuitarChordsDatabase();
    final gChord = db.getChord("G");
    expect(gChord, isNotNull);
    expect(gChord!.frets, equals([3, 2, 0, 0, 0, 3]));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/chords/guitar_chords_database_test.dart`
Expected: FAIL with "GuitarChordsDatabase not found".

- [ ] **Step 3: Implement `GuitarChordsDatabase` and `FretboardDiagramDialog`**

Implement chord lookup and a custom painter rendering 6 guitar strings, frets, finger positions, and open/muted string indicators in pure OLED styling.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/chords/guitar_chords_database_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/chords/ test/features/chords/
git commit -m "feat: add guitar chord database and interactive fretboard visualizer"
```

---

### Task 5: Afinador de Guitarra Integrado con Detección de Frecuencias

**Files:**
- Create: `lib/features/tuner/models/tuning_note.dart`
- Create: `lib/features/tuner/services/pitch_detector.dart`
- Create: `lib/features/tuner/widgets/guitar_tuner_widget.dart`
- Test: `test/features/tuner/pitch_detector_test.dart`

**Interfaces:**
- Consumes: Muestras de audio PCM en tiempo real
- Produces: `TuningResult(detectedFrequency, closestNote, centsOffset, isInTune)`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/tuner/pitch_detector_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/tuner/services/pitch_detector.dart';

void main() {
  test('PitchDetector identifies A2 (110 Hz) within tolerance', () {
    final detector = PitchDetector();
    final result = detector.analyzeFrequency(110.2);
    expect(result.closestNote, equals("A2"));
    expect(result.isInTune, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tuner/pitch_detector_test.dart`
Expected: FAIL with "PitchDetector not found".

- [ ] **Step 3: Implement `PitchDetector` and `GuitarTunerWidget`**

Implement frequency-to-pitch math for guitar strings (`E2=82.4Hz`, `A2=110Hz`, `D3=146.8Hz`, `G3=196Hz`, `B3=246.9Hz`, `E4=329.6Hz`), calculation of cents offset, and needle visual widget.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/tuner/pitch_detector_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tuner/ test/features/tuner/
git commit -m "feat: implement integrated guitar tuner with pitch detection"
```

---

### Task 6: Motor de Seguimiento de Voz (Karaoke Tracking) con Rechazo de Guitarra

**Files:**
- Create: `lib/features/audio/services/audio_bandpass_filter.dart`
- Create: `lib/features/audio/services/vocal_alignment_matcher.dart`
- Create: `lib/features/audio/models/alignment_state.dart`
- Test: `test/features/audio/vocal_alignment_matcher_test.dart`

**Interfaces:**
- Consumes: Palabras habladas/cantadas en vivo + `SongScript`
- Produces: `Stream<AlignmentState(currentLineIndex, currentWordIndex, confidence)>`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/audio/vocal_alignment_matcher_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/audio/services/vocal_alignment_matcher.dart';
import 'package:toro_music_teleprompter/features/scripts/models/lyric_token.dart';
import 'package:toro_music_teleprompter/features/scripts/models/song_script.dart';

void main() {
  test('VocalAlignmentMatcher advances index on sung word and pauses when silent', () {
    final song = SongScript(lines: [
      LyricLine(tokens: [
        LyricToken(word: "De"),
        LyricToken(word: "música"),
        LyricToken(word: "ligera")
      ])
    ]);
    final matcher = VocalAlignmentMatcher(song);
    
    // User sings "De"
    matcher.processSpokenWord("de");
    expect(matcher.currentState.currentWordIndex, equals(0));
    
    // User sings "música"
    matcher.processSpokenWord("musica");
    expect(matcher.currentState.currentWordIndex, equals(1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/audio/vocal_alignment_matcher_test.dart`
Expected: FAIL with "VocalAlignmentMatcher not found".

- [ ] **Step 3: Implement `AudioBandpassFilter` and `VocalAlignmentMatcher`**

Implement fuzzy phonetic matching (Levenshtein distance / phonetic normalizer), acoustic bandpass filtering, and stream emission of karaoke highlight index.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/audio/vocal_alignment_matcher_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/audio/ test/features/audio/
git commit -m "feat: implement vocal alignment matcher and karaoke tracking engine"
```

---

### Task 7: Pipeline de Cámara, Shader GLSL de Belleza y Disparadores Manos Libres

**Files:**
- Create: `shaders/beauty_filter.frag`
- Create: `lib/features/camera/services/beauty_shader_service.dart`
- Create: `lib/features/camera/services/hands_free_trigger_service.dart`
- Create: `lib/features/camera/widgets/camera_viewfinder_widget.dart`
- Test: `test/features/camera/hands_free_trigger_test.dart`

**Interfaces:**
- Consumes: Camera stream
- Produces: `BeautyShaderService.applyFilter(intensity: 0.0 - 1.0)`, `HandsFreeTriggerService(onTrigger: () => startCountdown())`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/camera/hands_free_trigger_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/camera/services/hands_free_trigger_service.dart';

void main() {
  test('HandsFreeTrigger triggers 3-2-1 countdown on voice command "grabar"', () {
    bool triggered = false;
    final service = HandsFreeTriggerService(onCountdownStart: () => triggered = true);
    
    service.handleVoiceKeyword("grabar");
    expect(triggered, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/camera/hands_free_trigger_test.dart`
Expected: FAIL with "HandsFreeTriggerService not found".

- [ ] **Step 3: Implement `beauty_filter.frag`, `BeautyShaderService` and `HandsFreeTriggerService`**

Write GLSL bilateral filter shader for real-time skin smoothing and voice/palm gesture detection listeners with 3-second animated countdown.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/camera/hands_free_trigger_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add shaders/ lib/features/camera/ test/features/camera/
git commit -m "feat: add GLSL beauty filter shader and hands-free palm/voice recording triggers"
```

---

### Task 8: Widget de Teleprompter Bajo la Cámara con Formato SF Pro y SF Mono

**Files:**
- Create: `lib/features/teleprompter/widgets/teleprompter_bar_widget.dart`
- Create: `lib/features/teleprompter/widgets/lyric_token_widget.dart`
- Create: `lib/features/teleprompter/controllers/teleprompter_controller.dart`
- Test: `test/features/teleprompter/teleprompter_bar_widget_test.dart`

**Interfaces:**
- Consumes: `SongScript`, `Stream<AlignmentState>`
- Produces: `TeleprompterBarWidget` (Top-anchored under lens, lyrics above, chords below)

- [ ] **Step 1: Write the failing test**

```dart
// test/features/teleprompter/teleprompter_bar_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/scripts/models/lyric_token.dart';
import 'package:toro_music_teleprompter/features/scripts/models/song_script.dart';
import 'package:toro_music_teleprompter/features/teleprompter/widgets/teleprompter_bar_widget.dart';

void main() {
  testWidgets('TeleprompterBar displays lyrics on top and chords on bottom row', (tester) async {
    final song = SongScript(lines: [
      LyricLine(tokens: [LyricToken(word: "Hola", chordUnderneath: "Sol")])
    ]);
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TeleprompterBarWidget(song: song, activeWordIndex: 0)),
    ));
    
    expect(find.text("Hola"), findsOneWidget);
    expect(find.text("Sol"), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/teleprompter/teleprompter_bar_widget_test.dart`
Expected: FAIL with "TeleprompterBarWidget not found".

- [ ] **Step 3: Implement `TeleprompterBarWidget` and `LyricTokenWidget`**

Implement top-docked teleprompter layout with dual-tier tokens (SF Pro for words, SF Mono for chords underneath) and active karaoke glow highlight.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/teleprompter/teleprompter_bar_widget_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/teleprompter/ test/features/teleprompter/
git commit -m "feat: implement camera-proximate teleprompter with dual-row lyric and chord rendering"
```

---

### Task 9: Compositor de Grabación (Modo Limpio vs Modo con Guion) y Marca de Agua

**Files:**
- Create: `lib/features/recording/models/recording_mode.dart`
- Create: `lib/features/recording/services/video_recording_compositor.dart`
- Create: `lib/features/recording/widgets/watermark_overlay_widget.dart`
- Test: `test/features/recording/video_recording_compositor_test.dart`

**Interfaces:**
- Consumes: Camera & audio streams, Teleprompter overlay canvas, User subscription tier
- Produces: `VideoRecordingCompositor.record(RecordingMode mode, VideoResolution resolution)`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/recording/video_recording_compositor_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/recording/models/recording_mode.dart';
import 'package:toro_music_teleprompter/features/recording/services/video_recording_compositor.dart';

void main() {
  test('RecordingCompositor configures clean mode without overlay', () {
    final compositor = VideoRecordingCompositor();
    final config = compositor.buildConfig(mode: RecordingMode.clean, isProUser: false);
    
    expect(config.burnInSubtitles, isFalse);
    expect(config.applyWatermark, isTrue); // Free user gets watermark
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/recording/video_recording_compositor_test.dart`
Expected: FAIL with "VideoRecordingCompositor not found".

- [ ] **Step 3: Implement `VideoRecordingCompositor` and `WatermarkOverlayWidget`**

Implement recording controller wrapping native camera recording, resolution selector (720p, 1080p, 4K@30/60fps), and conditional watermark stamping.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/recording/video_recording_compositor_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/recording/ test/features/recording/
git commit -m "feat: implement video recording compositor for clean vs burned-in modes and watermark"
```

---

### Task 10: Subsistema de Monetización (Anuncios Inteligentes y Suscripción Pro)

**Files:**
- Create: `lib/features/monetization/services/ad_manager.dart`
- Create: `lib/features/monetization/services/subscription_service.dart`
- Create: `lib/features/monetization/widgets/pro_upgrade_dialog.dart`
- Test: `test/features/monetization/subscription_service_test.dart`

**Interfaces:**
- Consumes: In-App Purchase events & Google AdMob SDK
- Produces: `SubscriptionService.isProUser`, `AdManager.showSaveInterstitial()`, `AdManager.showRewardedAdFor4K()`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/monetization/subscription_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/monetization/services/subscription_service.dart';

void main() {
  test('Pro subscription removes ads and enables 4K', () async {
    final service = SubscriptionService();
    expect(service.canExport4K(isPro: false, hasWatchedReward: false), isFalse);
    expect(service.canExport4K(isPro: false, hasWatchedReward: true), isTrue);
    expect(service.canExport4K(isPro: true, hasWatchedReward: false), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/monetization/subscription_service_test.dart`
Expected: FAIL with "SubscriptionService not found".

- [ ] **Step 3: Implement `AdManager` and `SubscriptionService`**

Implement AdMob interstitial triggers upon saving video, rewarded video callbacks for 4K/watermark unlock, and In-App Purchase verification with local entitlement persistence.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/monetization/subscription_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/monetization/ test/features/monetization/
git commit -m "feat: implement smart monetization with interstitial, rewarded ads and Pro subscription"
```

---

### Task 11: Sistema de Tutoriales Interactivos y Guías en Pantalla

**Files:**
- Create: `lib/features/tutorials/models/tutorial_topic.dart`
- Create: `lib/features/tutorials/widgets/feature_help_dialog.dart`
- Create: `lib/features/tutorials/widgets/onboarding_tour_dialog.dart`
- Test: `test/features/tutorials/feature_help_dialog_test.dart`

**Interfaces:**
- Consumes: Solicitud de ayuda del usuario en cualquier control `(?)`
- Produces: `FeatureHelpDialog(topic)`, `OnboardingTourDialog`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/tutorials/feature_help_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/tutorials/models/tutorial_topic.dart';
import 'package:toro_music_teleprompter/features/tutorials/widgets/feature_help_dialog.dart';

void main() {
  testWidgets('FeatureHelpDialog displays explanation for palm gesture', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FeatureHelpDialog(topic: TutorialTopic.palmGesture)),
    ));
    expect(find.textContaining("Palma"), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tutorials/feature_help_dialog_test.dart`
Expected: FAIL with "FeatureHelpDialog not found".

- [ ] **Step 3: Implement `FeatureHelpDialog` and `OnboardingTourDialog`**

Implement contextual help dialogs for Palm Gesture, Vocal Tracking, Tuner, Chord Dictionary, Beauty Filter, and PDF import with step-by-step illustrations.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/tutorials/feature_help_dialog_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tutorials/ test/features/tutorials/
git commit -m "feat: implement interactive tutorials and contextual help dialogs"
```

---

### Task 12: Integración Principal (Studio Recording View) y End-to-End Smoke Test

**Files:**
- Create: `lib/features/studio/presentation/studio_recording_screen.dart`
- Modify: `lib/main.dart`
- Test: `test/features/studio/studio_recording_screen_test.dart`

**Interfaces:**
- Consumes: Módulos de cámara, teleprompter, afinador, acordes, gestos y compositor
- Produces: Pantalla principal de grabación (`StudioRecordingScreen`)

- [ ] **Step 1: Write the failing test**

```dart
// test/features/studio/studio_recording_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toro_music_teleprompter/features/studio/presentation/studio_recording_screen.dart';

void main() {
  testWidgets('Studio screen mounts teleprompter, tuner toggle, beauty slider and record button', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: StudioRecordingScreen(),
    ));
    expect(find.byType(StudioRecordingScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/studio/studio_recording_screen_test.dart`
Expected: FAIL with "StudioRecordingScreen not found".

- [ ] **Step 3: Implement `StudioRecordingScreen` assembling all subsystems**

Tie together the viewfinder, top-anchored teleprompter with notes below, floating beauty slider, tuner drawer, chord popup, and record buttons in pure OLED black styling.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/studio/studio_recording_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/studio/ lib/main.dart test/features/studio/
git commit -m "feat: integrate studio recording screen combining camera, teleprompter and tools"
```
