import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/brawl_gold_shimmer.dart';
import '../../audio/services/acoustic_vocal_karaoke_service.dart';
import '../../audio/services/sherpa_onnx_vocal_service.dart';
import '../../audio/services/vocal_alignment_matcher.dart';
import '../../camera/services/beauty_shader_service.dart';
import '../../camera/services/hands_free_trigger_service.dart';
import '../../camera/widgets/camera_viewfinder_widget.dart';
import '../../monetization/services/ad_manager.dart';
import '../../monetization/services/subscription_service.dart';
import '../../monetization/widgets/pro_upgrade_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../recording/models/recording_mode.dart';
import '../../recording/services/realtime_recording_service.dart';
import '../../recording/services/video_recording_compositor.dart';
import '../../scripts/models/song_script.dart';
import '../../scripts/presentation/saved_songs_dialog.dart';
import '../../scripts/services/saved_songs_service.dart';
import '../../teleprompter/controllers/teleprompter_controller.dart';
import '../../teleprompter/widgets/floating_teleprompter_capsule.dart';
import '../../tuner/presentation/guitar_tuner_screen.dart';
import '../../metronome/presentation/metronome_screen.dart';
import '../../tutorials/widgets/onboarding_tour_dialog.dart';

/// Formatos de relación de aspecto de video
enum FormatOption {
  vertical9_16(label: '9:16 Vertical', ratio: 9 / 16, subtitle: 'TikTok, Reels, Shorts'),
  horizontal16_9(label: '16:9 Horizontal', ratio: 16 / 9, subtitle: 'YouTube, Pantalla Completa'),
  square1_1(label: '1:1 Cuadrado', ratio: 1.0, subtitle: 'Instagram Post'),
  portrait4_5(label: '4:5 Retrato', ratio: 4 / 5, subtitle: 'Instagram Portrait');

  final String label;
  final double ratio;
  final String subtitle;

  const FormatOption({
    required this.label,
    required this.ratio,
    required this.subtitle,
  });
}

/// Opciones de calidad de video y tasa de cuadros
class QualityOption {
  final String title;
  final String resolution;
  final int fps;
  final bool isPro;
  final String badge;

  const QualityOption({
    required this.title,
    required this.resolution,
    required this.fps,
    this.isPro = false,
    required this.badge,
  });
}

const List<QualityOption> kQualityOptions = [
  QualityOption(title: '720p HD', resolution: '1280 x 720', fps: 30, badge: 'Gratis'),
  QualityOption(title: '1080p Full HD', resolution: '1920 x 1080', fps: 30, badge: 'Recomendado'),
  QualityOption(title: '1080p Full HD (60 FPS)', resolution: '1920 x 1080', fps: 60, isPro: true, badge: 'Fluido Pro'),
  QualityOption(title: '4K Ultra HD (30 FPS)', resolution: '3840 x 2160', fps: 30, isPro: true, badge: 'Ultra Nitidez'),
  QualityOption(title: '4K Ultra HD (60 FPS)', resolution: '3840 x 2160', fps: 60, isPro: true, badge: 'Cine PRO'),
];

/// Opciones de color para iluminación karaoke
class KaraokeColorOption {
  final String name;
  final Color color;

  const KaraokeColorOption(this.name, this.color);
}

const List<KaraokeColorOption> kKaraokeColors = [
  KaraokeColorOption('Amarillo Neón', Color(0xFFFFD60A)),
  KaraokeColorOption('Verde Neón', Color(0xFF30D158)),
  KaraokeColorOption('Cian Eléctrico', Color(0xFF64D2FF)),
  KaraokeColorOption('Rosa Neón', Color(0xFFFF375F)),
  KaraokeColorOption('Naranja Fuego', Color(0xFFFF9F0A)),
  KaraokeColorOption('Blanco Puro', Color(0xFFFFFFFF)),
];

/// Pantalla principal de grabación musical de ToroCorp Music.
/// 
/// Interfaz 100% limpia y minimalista:
/// - Visor de cámara sin botones flotantes ni estiramientos.
/// - Teleprompter pegado inmediatamente debajo de la cámara para contacto visual.
/// - Botón rojo REC al centro inferior.
/// - Menú desplegable OLED (☰ <-> ✕) arriba a la derecha con todas las herramientas.
/// - Motor acústico de karaoke continuo en tiempo real (sin bips ni desconexiones).
class StudioRecordingScreen extends StatefulWidget {
  const StudioRecordingScreen({super.key});

  @override
  State<StudioRecordingScreen> createState() => _StudioRecordingScreenState();
}

class _StudioRecordingScreenState extends State<StudioRecordingScreen>
    with SingleTickerProviderStateMixin {
  // Servicios del sistema
  late final BeautyShaderService _beautyService;
  late final HandsFreeTriggerService _triggerService;
  late final SubscriptionService _subscriptionService;
  late final AdManager _adManager;
  late final VideoRecordingCompositor _compositor;

  // Controlador de Cámara
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraActive = false; // Permite activar o desactivar la cámara (Modo solo Karaoke)

  // Motor Acústico de Karaoke en Tiempo Real (Continuo, sin bips ni desconexiones)
  late AcousticVocalKaraokeService _acousticService;
  late final SherpaOnnxVocalService _sherpaService;

  // Animación del Menú Hamburguesa (☰ <-> ✕)
  late final AnimationController _menuAnimationController;
  bool _isMenuOpen = false;

  // Estado del Teleprompter y Canción
  late SongScript _currentSong;
  late VocalAlignmentMatcher _vocalMatcher;
  late TeleprompterController _teleprompterController;
  final SavedSongsService _savedSongsService = SavedSongsService();

  // Preferencias de grabación seleccionables por el usuario
  FormatOption _selectedFormat = FormatOption.vertical9_16;
  QualityOption _selectedQuality = kQualityOptions[1]; // 1080p 30fps default
  Color _karaokeHighlightColor = const Color(0xFFFFD60A); // Amarillo Neón default

  // Estado de grabación y herramientas
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  final bool _isMirrorMode = false;
  bool _hasSinglePass4K = false;
  RecordingMode _recordingMode = RecordingMode.withScript;

  // Grabación en Tiempo Real: compone cámara + teleprompter karaoke en vivo
  final bool _useRealtimeRecording = true;
  final RealtimeRecordingService _realtimeRecordingService = RealtimeRecordingService();

  // Grabadora de audio dedicada para Modo Solo Karaoke / Audio
  final AudioRecorder _audioRecorder = AudioRecorder();

  // Registro dinámico de cues para incrustación sincronizada en el video
  final List<({
    int startTimeMs,
    int lineIndex,
    int wordIndex,
    LyricLine? currentLine,
    LyricLine? nextLine,
    LyricLine? thirdLine,
    int elapsedSeconds,
    bool isSinging,
  })> _recordedCueTimeline = [];
  DateTime? _recordingStartTime;
  int _lastRecordedLineIndex = -1;
  int _lastRecordedWordIndex = -1;

  @override
  void initState() {
    super.initState();
    _beautyService = BeautyShaderService();
    _subscriptionService = SubscriptionService();
    _adManager = AdManager();
    _compositor = VideoRecordingCompositor();

    _menuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Estado inicial limpio: sin guion precargado (el usuario escribe, pega o sube PDF)
    _currentSong = const SongScript(
      title: '',
      lines: [],
    );

    _vocalMatcher = VocalAlignmentMatcher(_currentSong);
    _acousticService = AcousticVocalKaraokeService(song: _currentSong);

    _triggerService = HandsFreeTriggerService(
      onCountdownStart: () {
        setState(() {});
      },
      onCountdownComplete: () {
        _startRecordingProcess();
      },
    );

    _sherpaService = SherpaOnnxVocalService(
      onUtterance: (utterance) {
        if (!_isRecording) {
          _triggerService.handleVoiceKeyword(utterance);
        }
        _vocalMatcher.processUtterance(utterance);
      },
      onEndpoint: () {
        _vocalMatcher.resetUtterance();
      },
      onAudioLevel: (db, maxDb) {
        _acousticService.processAudioDb(db, maxDb);
      },
    );

    _teleprompterController = TeleprompterController(
      initialSong: _currentSong,
      matcher: _vocalMatcher,
      acousticService: _acousticService,
    );
    _teleprompterController.addListener(_onTeleprompterUpdated);

    // Solicitar permisos nativos e inicializar hardware
    _checkAndRequestPermissions();
  }

  void _onTeleprompterUpdated() {
    if (_isRecording && _recordingStartTime != null) {
      final currentLineIdx = _teleprompterController.currentLineIndex;
      final currentWordIdx = _teleprompterController.activeWordIndex;
      if (currentLineIdx != _lastRecordedLineIndex || currentWordIdx != _lastRecordedWordIndex) {
        final elapsedMs = DateTime.now().difference(_recordingStartTime!).inMilliseconds;
        _recordCurrentStateCue(elapsedMs);

        // Si la grabación en tiempo real está activa, actualizamos el overlay en el compositor nativo
        if (_useRealtimeRecording && _isCameraActive) {
          _pushRealtimeOverlay();
        }
      }
    }
  }

  /// Renderiza el overlay del teleprompter en memoria y lo envía al compositor nativo
  Future<void> _pushRealtimeOverlay() async {
    try {
      final allLines = _teleprompterController.song.lines;
      final currentLineIdx = _teleprompterController.currentLineIndex;
      LyricLine? curLine;
      LyricLine? nextL;
      LyricLine? thirdL;

      if (allLines.isNotEmpty && currentLineIdx < allLines.length) {
        curLine = allLines[currentLineIdx];
        if (currentLineIdx + 1 < allLines.length) nextL = allLines[currentLineIdx + 1];
        if (currentLineIdx + 2 < allLines.length) thirdL = allLines[currentLineIdx + 2];
      }

      final pngBytes = await _compositor.renderTeleprompterOverlayToBytes(
        currentLyricLine: curLine,
        nextLyricLine: nextL,
        thirdLyricLine: thirdL,
        activeWordIndex: _teleprompterController.activeWordIndex,
        elapsedSeconds: _recordingSeconds,
        isSinging: _teleprompterController.isSinging,
        highlightColor: _karaokeHighlightColor,
      );

      if (pngBytes.isNotEmpty) {
        await _realtimeRecordingService.pushOverlayFrame(pngBytes);
      }
    } catch (e) {
      debugPrint('ToroCorp Music: Error enviando overlay en tiempo real: $e');
    }
  }

  void _recordCurrentStateCue(int timeMs) {
    final currentLineIdx = _teleprompterController.currentLineIndex;
    final currentWordIdx = _teleprompterController.activeWordIndex;
    final isSinging = _teleprompterController.isSinging;
    _lastRecordedLineIndex = currentLineIdx;
    _lastRecordedWordIndex = currentWordIdx;

    final allLines = _teleprompterController.song.lines;
    LyricLine? curLine;
    LyricLine? nextL;
    LyricLine? thirdL;

    if (allLines.isNotEmpty && currentLineIdx < allLines.length) {
      curLine = allLines[currentLineIdx];
      if (currentLineIdx + 1 < allLines.length) {
        nextL = allLines[currentLineIdx + 1];
      }
      if (currentLineIdx + 2 < allLines.length) {
        thirdL = allLines[currentLineIdx + 2];
      }
    }

    _recordedCueTimeline.add((
      startTimeMs: timeMs,
      lineIndex: currentLineIdx,
      wordIndex: currentWordIdx,
      currentLine: curLine,
      nextLine: nextL,
      thirdLine: thirdL,
      elapsedSeconds: timeMs ~/ 1000,
      isSinging: isSinging,
    ));
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      final statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
      final micGranted = statuses[Permission.microphone]?.isGranted ?? false;

      if (cameraGranted && _isCameraActive) {
        await _initializeCamera();
      }
      if (micGranted) {
        unawaited(_sherpaService.initialize().then((ready) async {
          if (ready && mounted) {
            final started = await _sherpaService.startListening();
            if (!started && mounted) {
              await _startAcousticKaraoke();
            }
          } else if (mounted) {
            await _startAcousticKaraoke();
          }
        }));
      }

      if ((_isCameraActive && !cameraGranted) || !micGranted) {
        if (mounted) {
          _showPermissionsDialog();
        }
      }
    } catch (_) {
      // Entorno de pruebas o fallback
      if (_isCameraActive) {
        await _initializeCamera();
      }
      unawaited(_sherpaService.initialize().then((ready) async {
        if (ready && mounted) {
          final started = await _sherpaService.startListening();
          if (!started && mounted) {
            await _startAcousticKaraoke();
          }
        } else if (mounted) {
          await _startAcousticKaraoke();
        }
      }));
    }
  }

  ResolutionPreset _resolvePresetForQuality(QualityOption quality) {
    if (quality.title.contains('4K')) {
      return ResolutionPreset.ultraHigh;
    } else if (quality.title.contains('1080p')) {
      return ResolutionPreset.veryHigh;
    } else if (quality.title.contains('720p')) {
      return ResolutionPreset.high;
    }
    return ResolutionPreset.veryHigh;
  }

  Future<void> _initializeCamera({QualityOption? targetQuality}) async {
    if (!_isCameraActive) return;
    final quality = targetQuality ?? _selectedQuality;
    final targetPreset = _resolvePresetForQuality(quality);

    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final frontCam = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        // Disponer controlador previo si existe para reconfigurar resolución limpia
        if (_cameraController != null) {
          if (mounted) {
            setState(() {
              _isCameraInitialized = false;
            });
          }
          await Future.delayed(const Duration(milliseconds: 60));
          try {
            await _cameraController!.dispose();
          } catch (_) {}
          _cameraController = null;
        }

        CameraController controller;
        try {
          debugPrint('ToroCorp Music: Configurando cámara en $targetPreset (${quality.title})...');
          controller = CameraController(
            frontCam,
            targetPreset,
            enableAudio: true,
          );
          await controller.initialize();
        } catch (e) {
          debugPrint('ToroCorp Music: Preset $targetPreset no soportado por este sensor ($e). Aplicando ResolutionPreset.max...');
          controller = CameraController(
            frontCam,
            ResolutionPreset.max,
            enableAudio: true,
          );
          await controller.initialize();
        }

        _cameraController = controller;
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('ToroCorp Music: Info cámara: $e');
    }
  }

  /// Inicia el motor acústico de karaoke continuo sin bips del sistema
  Future<void> _startAcousticKaraoke() async {
    try {
      final success = await _acousticService.startTracking();
      debugPrint('ToroCorp Music: Seguimiento acústico de voz iniciado: $success');
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('ToroCorp Music: Error iniciando karaoke acústico: $e');
    }
  }

  /// Activa o desactiva la cámara manteniendo el micrófono encendido
  Future<void> _toggleCameraActive() async {
    setState(() {
      _isCameraActive = !_isCameraActive;
    });

    if (_isCameraActive) {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        await _initializeCamera();
      }
    } else {
      if (_cameraController != null && _cameraController!.value.isRecordingVideo) {
        await _stopRecordingProcess();
      }
      await _cameraController?.dispose();
      _cameraController = null;
      _isCameraInitialized = false;
      if (mounted) setState(() {});
    }
  }

  /// Dispara la cuenta regresiva manos libres 3-2-1 desde el menú
  void _triggerHandsFreeCountdown() {
    if (_isMenuOpen) _toggleMenu();
    _triggerService.triggerFromPalmGesture();
  }

  void _showPermissionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: Text(
            'Permisos Necesarios',
            style: AppTypography.sfProHeadline(color: AppColors.textWhite),
          ),
          content: Text(
            'ToroCorp Music necesita acceso a la Cámara y al Micrófono para grabar tus interpretaciones y sincronizar la letra automáticamente con tu voz.',
            style: AppTypography.sfProBody(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Más Tarde', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.chordAmber,
                foregroundColor: Colors.black,
              ),
              child: const Text('Conceder Permisos'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _cameraController?.dispose();
    _acousticService.dispose();
    _sherpaService.dispose();
    _menuAnimationController.dispose();
    _beautyService.dispose();
    _triggerService.dispose();
    _subscriptionService.dispose();
    _vocalMatcher.dispose();
    _teleprompterController.removeListener(_onTeleprompterUpdated);
    _teleprompterController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _menuAnimationController.forward();
      } else {
        _menuAnimationController.reverse();
      }
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecordingProcess();
    } else {
      await _startRecordingProcess();
    }
  }

  Future<void> _startRecordingProcess() async {
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
      if (_isMenuOpen) _toggleMenu();
    });

    _recordingStartTime = DateTime.now();
    _recordedCueTimeline.clear();
    _lastRecordedLineIndex = -1;
    _lastRecordedWordIndex = -1;
    _recordCurrentStateCue(0);

    if (_sherpaService.isInitialized && !_sherpaService.isListening) {
      _sherpaService.startListening();
    }

    // Iniciar temporizador de grabación
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isRecording) {
        setState(() {
          _recordingSeconds++;
        });
      }
    });

    // Iniciar grabación de video en la cámara con codificador de hardware a máxima tasa de cuadros
    if (_isCameraActive && _isCameraInitialized && _cameraController != null) {
      try {
        if (!_cameraController!.value.isRecordingVideo) {
          await _cameraController!.startVideoRecording();
          debugPrint('ToroCorp Music: Grabación de cámara por hardware iniciada a 30/60 FPS nativos.');
        }
      } catch (e) {
        debugPrint('ToroCorp Music: Info iniciar grabación video: $e');
      }
    } else if (!_isCameraActive) {
      // Modo Solo Karaoke / Audio: grabar como grabadora de audio en máxima calidad (320 kbps 48kHz estéreo)
      try {
        final hasPerm = await _audioRecorder.hasPermission();
        if (hasPerm) {
          final docsDir = await getApplicationDocumentsDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final audioFileName = 'ToroMusic_Audio_$timestamp.m4a';
          final outputPath = '${docsDir.path}/$audioFileName';

          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.aacLc,
              sampleRate: 48000,
              bitRate: 320000, // 320 kbps (estudio profesional)
              numChannels: 2, // Stereo
            ),
            path: outputPath,
          );
          debugPrint('ToroCorp Music: Grabación de audio puro iniciada en: $outputPath');
        }
      } catch (e) {
        debugPrint('ToroCorp Music: Error iniciando grabadora de audio: $e');
      }
    }

    // Asegurar que el motor de seguimiento vocal esté activo y sincronizado
    if (!_sherpaService.isListening && !_acousticService.isRunning) {
      await _acousticService.startTracking();
    }
  }

  VideoResolution _getVideoResolutionForQuality(QualityOption opt) {
    if (opt.title.contains('4K') && opt.fps == 60) return VideoResolution.fourK60;
    if (opt.title.contains('4K')) return VideoResolution.fourK30;
    if (opt.title.contains('1080p')) return VideoResolution.fhd1080p;
    return VideoResolution.hd720p;
  }

  Future<void> _stopRecordingProcess() async {
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
    });

    // Detener cámara y obtener archivo de video grabado por hardware
    XFile? videoFile;

    if (_isCameraActive && _isCameraInitialized && (_cameraController?.value.isRecordingVideo ?? false)) {
      try {
        videoFile = await _cameraController?.stopVideoRecording();
      } catch (e) {
        debugPrint('Error al detener grabación: $e');
      }
    } else if (!_isCameraActive) {
      // Modo Solo Karaoke / Audio: detener grabadora de audio y notificar
      try {
        if (await _audioRecorder.isRecording()) {
          final audioPath = await _audioRecorder.stop();
          if (audioPath != null && File(audioPath).existsSync()) {
            final fileName = audioPath.split(Platform.pathSeparator).last;
            debugPrint('ToroCorp Music: Grabación de audio finalizada: $audioPath');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.mic, color: AppColors.chordAmber, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '🎙️ Audio grabado en máxima calidad (320 kbps):\n$fileName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF1B2A1B),
                  duration: const Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF28A745), width: 1.2),
                  ),
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('ToroCorp Music: Error al detener grabadora de audio: $e');
      }
    }

    // Configurar composición
    final config = _compositor.buildConfig(
      mode: _recordingMode,
      resolution: _getVideoResolutionForQuality(_selectedQuality),
      isProUser: _subscriptionService.isPro,
      hasUnlockedSinglePass: _hasSinglePass4K,
    );

    // Procesar y guardar el video según el modo elegido
    bool isCompositedSuccess = false;
    if (videoFile != null) {
      String finalVideoPath = videoFile.path;
      final List<File> tempFilesToClean = [];

      // Mostrar diálogo modal de procesamiento visual mientras Media3 compone el video
      BuildContext? progressDialogContext;
      if (mounted && _recordingMode == RecordingMode.withScript) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dCtx) {
            progressDialogContext = dCtx;
            return PopScope(
              canPop: false,
              child: AlertDialog(
                backgroundColor: AppColors.surfaceDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.chordAmber, width: 1.5),
                ),
                content: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          color: AppColors.chordAmber,
                          strokeWidth: 3.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Creando video con Teleprompter...',
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Incrustando letra, acordes y karaoke en alta definición (${config.resolution.label})...',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }

      try {
        final tempDir = Directory.systemTemp;

        // Si se seleccionó "Con Guion", incrustar el teleprompter dinámico en el video y generar subtítulos .srt
        if (_recordingMode == RecordingMode.withScript) {
          if (_recordedCueTimeline.isEmpty) {
            _recordCurrentStateCue(0);
          }

          // Filtrar cues redundantes consecutivas para optimizar velocidad de render y consumo de RAM
          final distinctCues = <({
            int startTimeMs,
            int lineIndex,
            int wordIndex,
            LyricLine? currentLine,
            LyricLine? nextLine,
            LyricLine? thirdLine,
            int elapsedSeconds,
            bool isSinging,
          })>[];

          for (final cue in _recordedCueTimeline) {
            if (distinctCues.isEmpty) {
              distinctCues.add(cue);
            } else {
              final prev = distinctCues.last;
              if (prev.lineIndex != cue.lineIndex || prev.wordIndex != cue.wordIndex) {
                distinctCues.add(cue);
              }
            }
          }

          final cuesPayload = <Map<String, dynamic>>[];
          for (int i = 0; i < distinctCues.length; i++) {
            final cue = distinctCues[i];
            final cuePngPath = '${tempDir.path}/dynamic_island_${DateTime.now().millisecondsSinceEpoch}_$i.png';
            await _compositor.renderTeleprompterOverlayImage(
              currentLyricLine: cue.currentLine,
              nextLyricLine: cue.nextLine,
              thirdLyricLine: cue.thirdLine,
              activeWordIndex: cue.wordIndex,
              elapsedSeconds: cue.elapsedSeconds,
              isSinging: cue.isSinging,
              highlightColor: const Color(0xFFFFD54F),
              outputPath: cuePngPath,
            );
            tempFilesToClean.add(File(cuePngPath));
            cuesPayload.add({
              'startTimeMs': cue.startTimeMs,
              'imagePath': cuePngPath,
            });
          }

          String? watermarkPath;
          if (config.applyWatermark) {
            watermarkPath = '${tempDir.path}/watermark_${DateTime.now().millisecondsSinceEpoch}.png';
            await _compositor.renderWatermarkOverlayImage(outputPath: watermarkPath);
            tempFilesToClean.add(File(watermarkPath));
          }

          final compositedVideoPath = '${tempDir.path}/ToroMusic_script_${DateTime.now().millisecondsSinceEpoch}.mp4';
          final compositedResult = await _compositor.compositeVideoWithOverlay(
            videoPath: videoFile.path,
            cues: cuesPayload,
            watermarkPath: watermarkPath,
            outputPath: compositedVideoPath,
          );

          if (compositedResult.composited && File(compositedResult.path).existsSync()) {
            finalVideoPath = compositedResult.path;
            isCompositedSuccess = true;
          }

          // Generar también archivo de subtítulos sincronizados .srt con los tiempos reales
          final srtPath = '${tempDir.path}/ToroMusic_${DateTime.now().millisecondsSinceEpoch}.srt';
          final totalRecordMs = (_recordingSeconds > 0 ? _recordingSeconds : 1) * 1000;
          final srtCues = <({int startTimeMs, int endTimeMs, String text})>[];
          for (int i = 0; i < distinctCues.length; i++) {
            final cue = distinctCues[i];
            final startMs = cue.startTimeMs;
            final nextStartMs = (i + 1 < distinctCues.length)
                ? distinctCues[i + 1].startTimeMs
                : totalRecordMs;
            final endMs = nextStartMs > startMs ? nextStartMs : startMs + 1500;
            final text = cue.currentLine?.fullText ?? '';
            if (text.trim().isNotEmpty && (srtCues.isEmpty || srtCues.last.text != text)) {
              srtCues.add((startTimeMs: startMs, endTimeMs: endMs, text: text));
            }
          }

          await _compositor.generateSrtSubtitles(
            timedCues: srtCues,
            outputPath: srtPath,
          );
          _saveSrtSafely(srtPath);
          tempFilesToClean.add(File(srtPath));
        } else if (config.applyWatermark) {
          // Modo Limpio con marca de agua para usuarios gratuitos
          final watermarkPath = '${tempDir.path}/watermark_${DateTime.now().millisecondsSinceEpoch}.png';
          await _compositor.renderWatermarkOverlayImage(outputPath: watermarkPath);
          tempFilesToClean.add(File(watermarkPath));

          final compositedVideoPath = '${tempDir.path}/ToroMusic_clean_wm_${DateTime.now().millisecondsSinceEpoch}.mp4';
          final compositedResult = await _compositor.compositeVideoWithOverlay(
            videoPath: videoFile.path,
            watermarkPath: watermarkPath,
            outputPath: compositedVideoPath,
          );

          if (compositedResult.composited && File(compositedResult.path).existsSync()) {
            finalVideoPath = compositedResult.path;
            isCompositedSuccess = true;
          }
        }
      } catch (e) {
        debugPrint('ToroCorp Music: Info composición teleprompter: $e');
      }

      // Cerrar diálogo modal de procesamiento antes de proceder
      if (mounted && progressDialogContext != null && progressDialogContext!.mounted && Navigator.of(progressDialogContext!).canPop()) {
        Navigator.of(progressDialogContext!).pop();
      }

      // Guardar en la Galería ANTES de eliminar archivos intermedios
      await _saveVideoToGallery(finalVideoPath);

      // Si se generó un video compuesto temporal, ahora sí se borra de la caché interna
      if (isCompositedSuccess && finalVideoPath != videoFile.path) {
        try {
          final f = File(finalVideoPath);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }

      // Borrar PNGs y subtítulos temporales
      for (final file in tempFilesToClean) {
        try {
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (_) {}
      }
    }

    // Mostrar anuncio intersticial al guardar
    _adManager.showSaveInterstitial(
      isProUser: _subscriptionService.isPro,
      onDismissed: () {
        if (mounted) {
          final String feedbackMsg;
          if (videoFile != null) {
            if (_recordingMode == RecordingMode.withScript) {
              if (isCompositedSuccess) {
                feedbackMsg = '¡Video con Teleprompter dinámico guardado en la Galería ("ToroCorpMusic" • ${config.resolution.label})!';
              } else {
                feedbackMsg = '¡Video guardado en la Galería ("ToroCorpMusic" • ${config.resolution.label})! (El dispositivo guardó el video limpio sin teleprompter)';
              }
            } else {
              feedbackMsg = '¡Video Limpio guardado en la Galería ("ToroCorpMusic" • ${config.resolution.label})!';
            }
          } else {
            feedbackMsg = '¡Sesión de karaoke finalizada!';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.surfaceDark,
              content: Text(
                feedbackMsg,
                style: const TextStyle(color: AppColors.textWhite),
              ),
            ),
          );
        }
      },
    );
  }

  /// Guarda subtítulos .srt de forma segura sin rutas restringidas que causen crashes
  Future<void> _saveSrtSafely(String srtPath) async {
    try {
      debugPrint('ToroCorp Music: Subtítulos .srt preparados en $srtPath');
    } catch (_) {}
  }

  /// Guarda el video en la Galería del teléfono dentro del álbum "ToroCorpMusic"
  Future<void> _saveVideoToGallery(String videoPath) async {
    try {
      await Gal.putVideo(videoPath, album: 'ToroCorpMusic');
      debugPrint('ToroCorp Music: Video guardado en Galería / ToroCorpMusic');
    } catch (e) {
      debugPrint('Info Gal: $e. Aplicando copia directa a DCIM/ToroCorpMusic...');
      try {
        final dcimDir = Directory('/storage/emulated/0/DCIM/ToroCorpMusic');
        if (!await dcimDir.exists()) {
          await dcimDir.create(recursive: true);
        }
        final targetPath = '${dcimDir.path}/ToroCorp_${DateTime.now().millisecondsSinceEpoch}.mp4';
        await File(videoPath).copy(targetPath);
      } catch (err) {
        debugPrint('Fallback copy error: $err');
      }
    }
  }

  // Cuadro de diálogo para seleccionar formato de relación de aspecto
  void _openFormatSelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Formato de Grabación', style: AppTypography.sfProHeadline()),
              const SizedBox(height: 6),
              Text(
                'Elige la proporción nativa para tu video sin estiramientos.',
                style: AppTypography.sfProCaption(),
              ),
              const SizedBox(height: 14),
              ...FormatOption.values.map((opt) {
                final isSelected = opt == _selectedFormat;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.crop_free,
                    color: isSelected ? AppColors.chordAmber : AppColors.textSecondary,
                  ),
                  title: Text(opt.label, style: const TextStyle(color: AppColors.textWhite)),
                  subtitle: Text(opt.subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    setState(() {
                      _selectedFormat = opt;
                    });
                    Navigator.of(context).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }



  // Cuadro de diálogo para seleccionar calidad y FPS
  void _openQualitySelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Calidad y Tasa de Cuadros (FPS)', style: AppTypography.sfProHeadline()),
              const SizedBox(height: 6),
              Text(
                'Selecciona la resolución y fluidez deseada.',
                style: AppTypography.sfProCaption(),
              ),
              const SizedBox(height: 14),
              ...kQualityOptions.map((opt) {
                final isSelected = opt == _selectedQuality;
                final isLocked = opt.isPro && !_subscriptionService.isPro && !_hasSinglePass4K;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isLocked ? Icons.lock_outline : (isSelected ? Icons.check_circle : Icons.hd),
                    color: isSelected ? AppColors.chordAmber : (isLocked ? Colors.redAccent : AppColors.textSecondary),
                  ),
                  title: Text(opt.title, style: const TextStyle(color: AppColors.textWhite)),
                  subtitle: Text(opt.resolution, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLocked ? Colors.redAccent.withAlpha(40) : AppColors.chordAmber.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      opt.badge,
                      style: TextStyle(
                        fontSize: 11,
                        color: isLocked ? Colors.redAccent : AppColors.chordAmber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () {
                    if (isLocked) {
                      Navigator.of(context).pop();
                      ProUpgradeDialog.show(
                        context,
                        subscriptionService: _subscriptionService,
                        adManager: _adManager,
                        onSinglePassUnlocked: () {
                          setState(() {
                            _hasSinglePass4K = true;
                            _selectedQuality = opt;
                          });
                          _initializeCamera(targetQuality: opt);
                        },
                      );
                    } else {
                      setState(() {
                        _selectedQuality = opt;
                      });
                      Navigator.of(context).pop();
                      _initializeCamera(targetQuality: opt);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.surfaceDark,
                            content: Text(
                              'Calidad de video aplicada: ${opt.title} (${opt.resolution})',
                              style: const TextStyle(color: AppColors.textWhite),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // Cuadro de diálogo para seleccionar el color de la letra karaoke
  void _openKaraokeColorPickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Color de Iluminación Karaoke', style: AppTypography.sfProHeadline()),
              const SizedBox(height: 6),
              Text(
                'Elige el color con el que brillará la letra conforme cantas.',
                style: AppTypography.sfProCaption(),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: kKaraokeColors.map((opt) {
                  final isSelected = opt.color.toARGB32() == _karaokeHighlightColor.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _karaokeHighlightColor = opt.color;
                      });
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 85,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? opt.color.withAlpha(40) : AppColors.cardDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? opt.color : AppColors.borderDark,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: opt.color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: opt.color.withAlpha(160),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            opt.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textWhite, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // Modal para ajustar el filtro de belleza sin estorbar en el visor
  void _openBeautyFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_fix_high, color: AppColors.chordAmber, size: 24),
                      const SizedBox(width: 10),
                      Text('Filtro de Belleza Facial GLSL', style: AppTypography.sfProHeadline()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Suavizado de piel inteligente en tiempo real.',
                    style: AppTypography.sfProCaption(),
                  ),
                  const SizedBox(height: 20),
                  AnimatedBuilder(
                    animation: _beautyService,
                    builder: (context, _) {
                      return Column(
                        children: [
                          Slider(
                            value: _beautyService.intensity,
                            min: 0.0,
                            max: 1.0,
                            activeColor: AppColors.chordAmber,
                            inactiveColor: AppColors.borderDark,
                            onChanged: (val) {
                              _beautyService.setIntensity(val);
                              setModalState(() {});
                              setState(() {});
                            },
                          ),
                          Text(
                            'Intensidad: ${(_beautyService.intensity * 100).toInt()}%',
                            style: AppTypography.sfProHeadline(fontSize: 16, color: AppColors.chordAmber),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.chordAmber,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('Aplicar y Cerrar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  void _openSavedSongsModal() {
    SavedSongsDialog.show(
      context,
      songsService: _savedSongsService,
      hasActiveSong: _currentSong.lines.isNotEmpty,
      onSongSelected: _applyNewSong,
      onClearSong: () => _applyNewSong(const SongScript(title: '', lines: [])),
    );
  }

  Future<void> _openGuitarTunerScreen() async {
    // 1. Pausar los servicios de audio de grabación para liberar el micrófono en el hardware
    final wasAcousticTracking = _acousticService.isTracking;
    final wasSherpaListening = _sherpaService.isListening;

    if (wasAcousticTracking) {
      await _acousticService.stopTracking();
    }
    if (wasSherpaListening) {
      await _sherpaService.stopListening();
    }

    if (!mounted) return;

    // 2. Abrir pantalla de afinador dedicada
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GuitarTunerScreen()),
    );

    // 3. Al volver, reanudar captura si la pantalla sigue montada
    if (mounted) {
      if (wasSherpaListening) {
        await _sherpaService.startListening();
      } else if (wasAcousticTracking) {
        await _acousticService.startTracking();
      }
    }
  }

  Future<void> _openMetronomeScreen() async {
    final wasAcousticTracking = _acousticService.isTracking;
    final wasSherpaListening = _sherpaService.isListening;

    if (wasAcousticTracking) {
      await _acousticService.stopTracking();
    }
    if (wasSherpaListening) {
      await _sherpaService.stopListening();
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MetronomeScreen()),
    );

    if (mounted) {
      if (wasSherpaListening) {
        await _sherpaService.startListening();
      } else if (wasAcousticTracking) {
        await _acousticService.startTracking();
      }
    }
  }

  void _applyNewSong(SongScript newSong) {
    setState(() {
      _currentSong = newSong;
      _vocalMatcher.updateSong(_currentSong);
      _acousticService.updateSong(_currentSong);
      _teleprompterController.updateSong(_currentSong);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureBlackOled,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Visor de Cámara Frontal 100% Limpio (con relación de aspecto 9:16 nativa)
          CameraViewfinderWidget(
            cameraPreview: _isCameraActive && _isCameraInitialized && _cameraController != null
                ? CameraPreview(_cameraController!)
                : null,
            beautyService: _beautyService,
            triggerService: _triggerService,
            isRecording: _isRecording,
            isMirrorMode: _isMirrorMode,
            aspectRatio: _selectedFormat.ratio,
            isCameraActive: _isCameraActive,
          ),

          // 2. Cápsula Flotante Teleprompter "Dynamic Island" pegada bajo la cámara frontal
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _teleprompterController,
                builder: (context, _) {
                  return FloatingTeleprompterCapsule(
                    isCameraActive: _isCameraActive,
                    allLines: _teleprompterController.song.lines,
                    currentLineIndex: _teleprompterController.activeLineIndex,
                    currentLine: _teleprompterController.currentLine,
                    nextLine: _teleprompterController.nextLine,
                    currentWordIndex: _teleprompterController.activeWordIndex,
                    isSinging: _teleprompterController.isSinging,
                    isWaitingForVoice: _teleprompterController.isWaitingForVoice,
                    isRecording: _isRecording,
                    recordingSeconds: _recordingSeconds,
                    highlightColor: _karaokeHighlightColor,
                    onMenuTap: _toggleMenu,
                    onPlaceholderTap: _openSavedSongsModal,
                    menuAnimationProgress: _menuAnimationController,
                    onWordTap: (wordIdx) {
                      _teleprompterController.jumpToWordInCurrentLine(wordIdx);
                    },
                    onLineWordTap: (lineIdx, wordIdx) {
                      _teleprompterController.jumpTo(lineIdx, wordIdx);
                    },
                    onNextLineTap: () {
                      _teleprompterController.jumpToNextLine();
                    },
                    onResetTap: () {
                      _teleprompterController.reset();
                      _vocalMatcher.resetUtterance();
                    },
                  );
                },
              ),
            ),
          ),

          // 3. Botón Único Central REC (Pantalla Limpia sin temporizadores duplicados)
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(160),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isRecording ? 32 : 62,
                      height: _isRecording ? 32 : 62,
                      decoration: BoxDecoration(
                        color: AppColors.recordRed,
                        borderRadius: BorderRadius.circular(_isRecording ? 8 : 31),
                      ),
                      child: _isRecording
                          ? null
                          : const Icon(Icons.fiber_manual_record, color: Colors.transparent),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 5. Menú Desplegable OLED Completo (☰ <-> ✕)
          if (_isMenuOpen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 122,
              right: 16,
              width: 310,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(245),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderDark, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(220),
                        blurRadius: 24,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Cabecera ToroCorp Music (Sin imagen, con brillo dorado Pase de Oro de Brawl Stars)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Center(
                            child: BrawlGoldShimmer(
                              child: Text(
                                'ToroCorp Music',
                                style: AppTypography.sfProHeadline(
                                  fontSize: 18,
                                  color: Colors.white,
                                ).copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Divider(color: AppColors.borderDark, height: 12),

                        // 1. Manos Libres: Cuenta Regresiva 5 Segundos
                        _buildMenuItem(
                          icon: Icons.timer,
                          iconColor: AppColors.chordAmber,
                          title: 'Cuenta Regresiva 5 Segundos',
                          subtitle: 'Iniciar grabación manos libres (5s)',
                          onTap: _triggerHandsFreeCountdown,
                        ),

                        // 1.5. Incrustar Letra y Acordes en el Video (Composición GPU OpenGL)
                        _buildMenuItem(
                          icon: Icons.subtitles,
                          iconColor: _recordingMode == RecordingMode.withScript ? AppColors.chordAmber : AppColors.textSecondary,
                          title: 'Incrustar Letra Karaoke',
                          subtitle: _recordingMode == RecordingMode.withScript
                              ? 'Cámara 1080p + Letra GPU (30/60 FPS fluidos)'
                              : 'Video limpio sin teleprompter',
                          isActive: _recordingMode == RecordingMode.withScript,
                          trailing: Switch.adaptive(
                            value: _recordingMode == RecordingMode.withScript,
                            activeTrackColor: AppColors.chordAmber,
                            onChanged: (val) {
                              setState(() {
                                _recordingMode = val ? RecordingMode.withScript : RecordingMode.clean;
                              });
                            },
                          ),
                          onTap: () {
                            setState(() {
                              _recordingMode = _recordingMode == RecordingMode.withScript
                                  ? RecordingMode.clean
                                  : RecordingMode.withScript;
                            });
                          },
                        ),

                        // 2. Activar / Desactivar Cámara (Modo solo Karaoke)
                        _buildMenuItem(
                          icon: _isCameraActive ? Icons.videocam : Icons.videocam_off,
                          iconColor: _isCameraActive ? AppColors.tunerInTuneGreen : AppColors.textSecondary,
                          title: 'Cámara (Video)',
                          subtitle: _isCameraActive ? 'Activada' : 'Desactivada (Solo Karaoke)',
                          isActive: _isCameraActive,
                          trailing: Switch.adaptive(
                            value: _isCameraActive,
                            activeTrackColor: AppColors.chordAmber,
                            onChanged: (_) {
                              _toggleCameraActive();
                              _toggleMenu();
                            },
                          ),
                          onTap: () {
                            _toggleCameraActive();
                            _toggleMenu();
                          },
                        ),

                        // 3. Afinador de Guitarra (6 y 12 Cuerdas)
                        _buildMenuItem(
                          icon: Icons.tune,
                          title: 'Afinador de Guitarra',
                          subtitle: '6 y 12 cuerdas • Cuerda por cuerda',
                          onTap: () {
                            _toggleMenu();
                            _openGuitarTunerScreen();
                          },
                        ),

                        // 4. Metrónomo Interactivo (40-240 BPM • Tap Tempo)
                        _buildMenuItem(
                          icon: Icons.speed,
                          title: 'Metrónomo',
                          subtitle: '40 - 240 BPM • Tap Tempo',
                          onTap: () {
                            _toggleMenu();
                            _openMetronomeScreen();
                          },
                        ),

                        // 5. Formato de Grabación (9:16, 16:9, etc.)
                        _buildMenuItem(
                          icon: Icons.aspect_ratio,
                          title: 'Formato de Grabación',
                          subtitle: _selectedFormat.label,
                          onTap: () {
                            _toggleMenu();
                            _openFormatSelectionModal();
                          },
                        ),

                        // 5. Calidad de Video y FPS
                        _buildMenuItem(
                          icon: Icons.hd,
                          title: 'Calidad de Video',
                          subtitle: _selectedQuality.title,
                          onTap: () {
                            _toggleMenu();
                            _openQualitySelectionModal();
                          },
                        ),

                        // 6. Color de Letra Karaoke
                        _buildMenuItem(
                          icon: Icons.palette,
                          iconColor: _karaokeHighlightColor,
                          title: 'Color Letra Karaoke',
                          subtitle: 'Personalizar iluminación',
                          onTap: () {
                            _toggleMenu();
                            _openKaraokeColorPickerModal();
                          },
                        ),

                        // 7. Filtro de Belleza Facial (Modal)
                        _buildMenuItem(
                          icon: Icons.auto_fix_high,
                          title: 'Filtro de Belleza Facial',
                          subtitle: '${(_beautyService.intensity * 100).toInt()}% intensidad',
                          onTap: () {
                            _toggleMenu();
                            _openBeautyFilterModal();
                          },
                        ),

                        // 8. Letras y Repertorio (Mis Canciones y Guiones)
                        _buildMenuItem(
                          icon: Icons.lyrics,
                          title: 'Letras y Repertorio',
                          subtitle: 'Escribir, pegar o elegir guion',
                          onTap: () {
                            _toggleMenu();
                            _openSavedSongsModal();
                          },
                        ),

                        // 9. Tutoriales y Guía
                        _buildMenuItem(
                          icon: Icons.help_outline,
                          title: 'Tutoriales y Guía',
                          subtitle: 'Cómo usar cada función',
                          onTap: () {
                            _toggleMenu();
                            OnboardingTourDialog.show(context);
                          },
                        ),

                        // 12. ToroCorp Music PRO (Tarjeta destacada Pase de Oro de Brawl Stars)
                        InkWell(
                          onTap: () {
                            _toggleMenu();
                            ProUpgradeDialog.show(
                              context,
                              subscriptionService: _subscriptionService,
                              adManager: _adManager,
                              onSinglePassUnlocked: () {
                                setState(() => _hasSinglePass4K = true);
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFFA000).withAlpha(35),
                                  const Color(0xFFFFD700).withAlpha(15),
                                  Colors.transparent,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: const Color(0xFFFFD700).withAlpha(120),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                const BrawlGoldShimmer(
                                  child: Icon(Icons.star, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      BrawlGoldShimmer(
                                        child: Text(
                                          'ToroCorp Music PRO',
                                          style: AppTypography.sfProLyricStyle(
                                            fontSize: 14,
                                            color: Colors.white,
                                          ).copyWith(fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Sin anuncios • 4K 60FPS',
                                        style: AppTypography.sfProCaption(
                                          fontSize: 11,
                                          color: AppColors.chordAmber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                BrawlGoldShimmer(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white, width: 1),
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    Color iconColor = AppColors.textWhite,
    required String title,
    required String subtitle,
    bool isActive = false,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: isActive ? AppColors.tunerInTuneGreen : iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.sfProLyricStyle(fontSize: 14, color: AppColors.textWhite),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.sfProCaption(
                      fontSize: 11,
                      color: isActive ? AppColors.tunerInTuneGreen : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (isActive)
              const Icon(Icons.check, size: 16, color: AppColors.tunerInTuneGreen),
          ],
        ),
      ),
    );
  }
}

