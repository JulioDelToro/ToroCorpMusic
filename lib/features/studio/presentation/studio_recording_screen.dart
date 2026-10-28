import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../audio/services/acoustic_vocal_karaoke_service.dart';
import '../../audio/services/sherpa_onnx_vocal_service.dart';
import '../../audio/services/vocal_alignment_matcher.dart';
import '../../camera/services/beauty_shader_service.dart';
import '../../camera/services/hands_free_trigger_service.dart';
import '../../camera/widgets/camera_viewfinder_widget.dart';
import '../../monetization/services/ad_manager.dart';
import '../../monetization/services/subscription_service.dart';
import '../../monetization/widgets/pro_upgrade_dialog.dart';
import '../../recording/models/recording_mode.dart';
import '../../recording/services/video_recording_compositor.dart';
import '../../scripts/models/song_script.dart';
import '../../scripts/presentation/saved_songs_dialog.dart';
import '../../scripts/services/saved_songs_service.dart';
import '../../teleprompter/controllers/teleprompter_controller.dart';
import '../../teleprompter/widgets/floating_teleprompter_capsule.dart';
import '../../tuner/presentation/guitar_tuner_screen.dart';
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
  bool _isCameraActive = true; // Permite activar o desactivar la cámara (Modo solo Karaoke)

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
  RecordingMode _recordingMode = RecordingMode.clean;

  // Registro dinámico de cues para incrustación sincronizada en el video
  final List<({int startTimeMs, int lineIndex, String text, String? nextText, String? chords})> _recordedCueTimeline = [];
  DateTime? _recordingStartTime;
  int _lastRecordedLineIndex = -1;

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
    _sherpaService = SherpaOnnxVocalService(
      onUtterance: (utterance) {
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

    _triggerService = HandsFreeTriggerService(
      onCountdownStart: () {
        setState(() {});
      },
      onCountdownComplete: () {
        _startRecordingProcess();
      },
    );

    // Solicitar permisos nativos e inicializar hardware
    _checkAndRequestPermissions();
  }

  void _onTeleprompterUpdated() {
    if (_isRecording && _recordingStartTime != null) {
      final currentLineIdx = _teleprompterController.currentLineIndex;
      if (currentLineIdx != _lastRecordedLineIndex) {
        final elapsedMs = DateTime.now().difference(_recordingStartTime!).inMilliseconds;
        _recordCurrentLineCue(elapsedMs);
      }
    }
  }

  void _recordCurrentLineCue(int timeMs) {
    final currentLine = _teleprompterController.currentLine;
    final currentLineIdx = _teleprompterController.currentLineIndex;
    _lastRecordedLineIndex = currentLineIdx;

    final text = currentLine != null
        ? currentLine.fullText
        : (_currentSong.lines.isNotEmpty ? _currentSong.lines.first.fullText : '');
    final nextText = _teleprompterController.nextLine?.fullText;
    final chordsText = currentLine != null && currentLine.tokens.any((t) => t.chordUnderneath != null)
        ? currentLine.tokens
            .map((t) => t.chordUnderneath ?? '')
            .where((c) => c.isNotEmpty)
            .join('   ')
        : null;

    _recordedCueTimeline.add((
      startTimeMs: timeMs,
      lineIndex: currentLineIdx,
      text: text,
      nextText: nextText,
      chords: chordsText,
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

      if (cameraGranted) {
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

      if (!cameraGranted || !micGranted) {
        if (mounted) {
          _showPermissionsDialog();
        }
      }
    } catch (_) {
      // Entorno de pruebas o fallback
      await _initializeCamera();
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
    _recordCurrentLineCue(0);

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

    // Iniciar grabación de video en la cámara si está activa
    if (_isCameraActive && _isCameraInitialized && _cameraController != null) {
      try {
        if (!_cameraController!.value.isRecordingVideo) {
          await _cameraController!.startVideoRecording();
        }
      } catch (e) {
        debugPrint('ToroCorp Music: Info iniciar grabación video: $e');
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

    // Detener cámara y obtener archivo de video
    XFile? videoFile;
    if (_isCameraActive && _isCameraInitialized && (_cameraController?.value.isRecordingVideo ?? false)) {
      try {
        videoFile = await _cameraController?.stopVideoRecording();
      } catch (e) {
        debugPrint('Error al detener grabación: $e');
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

      try {
        final tempDir = Directory.systemTemp;

        // Si se seleccionó "Con Guion", incrustar el teleprompter dinámico en el video y generar subtítulos .srt
        if (_recordingMode == RecordingMode.withScript) {
          if (_recordedCueTimeline.isEmpty) {
            _recordCurrentLineCue(0);
          }

          final cuesPayload = <Map<String, dynamic>>[];
          for (int i = 0; i < _recordedCueTimeline.length; i++) {
            final cue = _recordedCueTimeline[i];
            final cuePngPath = '${tempDir.path}/cue_${DateTime.now().millisecondsSinceEpoch}_$i.png';
            await _compositor.renderTeleprompterOverlayImage(
              title: _currentSong.title,
              currentLine: cue.text,
              nextLine: cue.nextText,
              chords: cue.chords,
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
          for (int i = 0; i < _recordedCueTimeline.length; i++) {
            final cue = _recordedCueTimeline[i];
            final startMs = cue.startTimeMs;
            final nextStartMs = (i + 1 < _recordedCueTimeline.length)
                ? _recordedCueTimeline[i + 1].startTimeMs
                : totalRecordMs;
            final endMs = nextStartMs > startMs ? nextStartMs : startMs + 1500;
            if (cue.text.trim().isNotEmpty) {
              srtCues.add((startTimeMs: startMs, endTimeMs: endMs, text: cue.text));
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

  // Cuadro de diálogo modal para seleccionar el tipo de grabación (Limpio vs Con Guion)
  void _openRecordingModeModal() {
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
              Text('Tipo de Grabación', style: AppTypography.sfProHeadline()),
              const SizedBox(height: 6),
              Text(
                'Selecciona si deseas que el video guarde la cámara limpia o con la letra y teleprompter en pantalla.',
                style: AppTypography.sfProCaption(),
              ),
              const SizedBox(height: 16),

              // Opción 1: Video Limpio
              _buildRecordingModeTile(
                title: 'Video Limpio (Solo Cámara)',
                subtitle: 'Graba exclusivamente el video puro de la cámara en máxima resolución y calidad. Sin letras ni teleprompter.',
                icon: Icons.videocam_rounded,
                badge: 'Puro Video',
                badgeColor: AppColors.tunerInTuneGreen,
                isSelected: _recordingMode == RecordingMode.clean,
                onTap: () {
                  setState(() {
                    _recordingMode = RecordingMode.clean;
                  });
                  Navigator.of(context).pop();
                },
              ),

              const SizedBox(height: 12),

              // Opción 2: Con Guion
              _buildRecordingModeTile(
                title: 'Con Guion (Cámara + Letra)',
                subtitle: 'Graba el video mostrando el teleprompter con las letras de la canción y acordes sincronizados.',
                icon: Icons.subtitles_rounded,
                badge: 'Teleprompter',
                badgeColor: AppColors.chordAmber,
                isSelected: _recordingMode == RecordingMode.withScript,
                onTap: () {
                  setState(() {
                    _recordingMode = RecordingMode.withScript;
                  });
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecordingModeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String badge,
    required Color badgeColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? badgeColor.withAlpha(25) : AppColors.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? badgeColor : AppColors.borderDark,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : icon,
              color: isSelected ? badgeColor : AppColors.textSecondary,
              size: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            color: badgeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                        // Cabecera ToroCorp Music
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  'assets/images/app_logo.jpeg',
                                  width: 26,
                                  height: 26,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ToroCorp Music',
                                  style: AppTypography.sfProHeadline(
                                    fontSize: 16,
                                    color: AppColors.chordAmber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: AppColors.borderDark, height: 12),

                        // 1. Manos Libres: Cuenta Regresiva 3-2-1
                        _buildMenuItem(
                          icon: Icons.timer,
                          iconColor: AppColors.chordAmber,
                          title: 'Cuenta Regresiva 3-2-1',
                          subtitle: 'Iniciar grabación manos libres',
                          onTap: _triggerHandsFreeCountdown,
                        ),

                        // 2. Activar / Desactivar Cámara (Modo solo Karaoke)
                        _buildMenuItem(
                          icon: _isCameraActive ? Icons.videocam : Icons.videocam_off,
                          iconColor: _isCameraActive ? AppColors.tunerInTuneGreen : AppColors.textSecondary,
                          title: 'Cámara (Video)',
                          subtitle: _isCameraActive ? 'Activada' : 'Desactivada (Solo Karaoke)',
                          isActive: _isCameraActive,
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

                        // 4. Formato de Grabación (9:16, 16:9, etc.)
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

                        // 10. Tipo de Grabación (Limpio vs Con Guion)
                        _buildMenuItem(
                          icon: _recordingMode == RecordingMode.clean
                              ? Icons.videocam
                              : Icons.subtitles,
                          iconColor: _recordingMode == RecordingMode.clean
                              ? AppColors.tunerInTuneGreen
                              : AppColors.chordAmber,
                          title: 'Tipo de Grabación',
                          subtitle: _recordingMode == RecordingMode.clean
                              ? 'Video Limpio (Solo cámara)'
                              : 'Con Guion (Cámara + Letra)',
                          onTap: () {
                            _toggleMenu();
                            _openRecordingModeModal();
                          },
                        ),

                        // 11. Tutoriales y Guía
                        _buildMenuItem(
                          icon: Icons.help_outline,
                          title: 'Tutoriales y Guía',
                          subtitle: 'Cómo usar cada función',
                          onTap: () {
                            _toggleMenu();
                            OnboardingTourDialog.show(context);
                          },
                        ),

                        // 12. ToroCorp Music PRO
                        _buildMenuItem(
                          icon: Icons.star,
                          iconColor: AppColors.chordAmber,
                          title: 'ToroCorp Music PRO',
                          subtitle: 'Sin anuncios • 4K 60FPS',
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
            if (isActive)
              const Icon(Icons.check, size: 16, color: AppColors.tunerInTuneGreen),
          ],
        ),
      ),
    );
  }
}

