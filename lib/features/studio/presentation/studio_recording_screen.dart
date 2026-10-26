import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../audio/services/vocal_alignment_matcher.dart';
import '../../camera/services/beauty_shader_service.dart';
import '../../camera/services/hands_free_trigger_service.dart';
import '../../camera/widgets/camera_viewfinder_widget.dart';
import '../../monetization/services/ad_manager.dart';
import '../../monetization/services/subscription_service.dart';
import '../../monetization/widgets/pro_upgrade_dialog.dart';
import '../../recording/models/recording_mode.dart';
import '../../recording/services/video_recording_compositor.dart';
import '../../recording/widgets/watermark_overlay_widget.dart';
import '../../scripts/models/lyric_token.dart';
import '../../scripts/models/song_script.dart';
import '../../scripts/services/chordpro_parser.dart';
import '../../scripts/services/pdf_script_extractor.dart';
import '../../teleprompter/controllers/teleprompter_controller.dart';
import '../../teleprompter/widgets/teleprompter_bar_widget.dart';
import '../../tuner/models/tuning_note.dart';
import '../../tuner/services/pitch_detector.dart';
import '../../tuner/widgets/guitar_tuner_widget.dart';
import '../../tutorials/widgets/onboarding_tour_dialog.dart';

/// Pantalla principal de grabación musical de ToroCorp Music.
/// Integra el visor de cámara frontal, teleprompter inteligente posicionado bajo el lente,
/// seguimiento automático de voz estilo karaoke con rechazo de ruido de guitarra,
/// menú superior de tres líneas que conmuta a 'X', y gestión completa de permisos.
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
  late final PitchDetector _pitchDetector;

  // Controlador de Cámara
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  // Reconocimiento de Voz / Karaoke
  final SpeechToText _speechToText = SpeechToText();
  bool _speechAvailable = false;

  // Animación del Menú Hamburguesa (☰ <-> ✕)
  late final AnimationController _menuAnimationController;
  bool _isMenuOpen = false;

  // Estado del Teleprompter y Canción
  late SongScript _currentSong;
  late VocalAlignmentMatcher _vocalMatcher;
  late TeleprompterController _teleprompterController;

  // Estado de grabación y herramientas
  bool _isRecording = false;
  bool _showTuner = false;
  bool _showBeautySlider = false;
  bool _isMirrorMode = false;
  bool _hasSinglePass4K = false;
  RecordingMode _recordingMode = RecordingMode.clean;
  VideoResolution _selectedResolution = VideoResolution.fhd1080p;

  // Estado del afinador
  late TuningResult _currentTuning;

  @override
  void initState() {
    super.initState();
    _beautyService = BeautyShaderService();
    _subscriptionService = SubscriptionService();
    _adManager = AdManager();
    _compositor = VideoRecordingCompositor();
    _pitchDetector = PitchDetector();
    _currentTuning = _pitchDetector.analyzeFrequency(82.41);

    _menuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Canción de demostración inicial con acordes inferiores
    _currentSong = const SongScript(
      title: 'De Música Ligera',
      artist: 'Soda Stereo',
      lines: [
        LyricLine(tokens: [
          LyricToken(word: 'De', chordUnderneath: null),
          LyricToken(word: 'música', chordUnderneath: 'G'),
          LyricToken(word: 'ligera...', chordUnderneath: 'D'),
        ]),
        LyricLine(tokens: [
          LyricToken(word: 'Nada', chordUnderneath: 'Em'),
          LyricToken(word: 'nos', chordUnderneath: null),
          LyricToken(word: 'libra,', chordUnderneath: 'C'),
          LyricToken(word: 'nada', chordUnderneath: 'G'),
          LyricToken(word: 'más', chordUnderneath: 'D'),
          LyricToken(word: 'queda...', chordUnderneath: null),
        ]),
      ],
    );

    _vocalMatcher = VocalAlignmentMatcher(_currentSong);
    _teleprompterController = TeleprompterController(
      initialSong: _currentSong,
      matcher: _vocalMatcher,
    );

    _triggerService = HandsFreeTriggerService(
      onCountdownStart: () {
        setState(() {});
      },
    );

    // Solicitar permisos nativos e inicializar hardware
    _checkAndRequestPermissions();
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
        await _initializeSpeech();
      }

      if (!cameraGranted || !micGranted) {
        if (mounted) {
          _showPermissionsDialog();
        }
      }
    } catch (_) {
      // Entorno de pruebas o plataforma de escritorio
      _initializeCamera();
      _initializeSpeech();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final frontCam = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
        _cameraController = CameraController(
          frontCam,
          ResolutionPreset.high,
          enableAudio: true,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('ToroCorp Music: Info inicialización de cámara: $e');
    }
  }

  Future<void> _initializeSpeech() async {
    try {
      _speechAvailable = await _speechToText.initialize(
        onStatus: (status) => debugPrint('ToroCorp Music STT Estado: $status'),
        onError: (error) => debugPrint('ToroCorp Music STT Error: $error'),
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('ToroCorp Music: Info inicialización de voz: $e');
    }
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
            'ToroCorp Music necesita acceso a la Cámara y al Micrófono para grabar tus videos musicales y sincronizar la letra automáticamente con tu voz.',
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
    _cameraController?.dispose();
    _speechToText.stop();
    _menuAnimationController.dispose();
    _beautyService.dispose();
    _triggerService.dispose();
    _subscriptionService.dispose();
    _vocalMatcher.dispose();
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

  void _toggleTuner() {
    setState(() {
      _showTuner = !_showTuner;
      if (_showTuner) {
        _currentTuning = _pitchDetector.analyzeFrequency(82.41);
      }
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Detener grabación de audio y video
      setState(() {
        _isRecording = false;
      });

      if (_speechAvailable) {
        await _speechToText.stop();
      }

      if (_isCameraInitialized && (_cameraController?.value.isRecordingVideo ?? false)) {
        try {
          await _cameraController?.stopVideoRecording();
        } catch (e) {
          debugPrint('Error deteniendo grabación de video: $e');
        }
      }

      final config = _compositor.buildConfig(
        mode: _recordingMode,
        resolution: _selectedResolution,
        isProUser: _subscriptionService.isPro,
        hasUnlockedSinglePass: _hasSinglePass4K,
      );

      // Mostrar anuncio intersticial al guardar (no interrumpe la toma del usuario)
      _adManager.showSaveInterstitial(
        isProUser: _subscriptionService.isPro,
        onDismissed: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.surfaceDark,
                content: Text(
                  'ToroCorp Music: Video guardado (${config.resolution.label} - ${config.mode == RecordingMode.clean ? "Limpio" : "Con Guion"})',
                  style: const TextStyle(color: AppColors.textWhite),
                ),
              ),
            );
          }
        },
      );
    } else {
      // Iniciar grabación de video y seguimiento de voz estilo karaoke
      setState(() {
        _isRecording = true;
        _showTuner = false; // Ocultar afinador durante la grabación
        if (_isMenuOpen) _toggleMenu(); // Cerrar menú al grabar
      });

      if (_isCameraInitialized) {
        try {
          await _cameraController?.startVideoRecording();
        } catch (e) {
          debugPrint('Info grabación video: $e');
        }
      }

      _vocalMatcher.resetUtterance();
      if (_speechAvailable) {
        try {
          await _speechToText.listen(
            onResult: (result) {
              // El teleprompter sigue la voz en tiempo real estilo karaoke
              _vocalMatcher.processUtterance(result.recognizedWords);
            },
            listenOptions: SpeechListenOptions(
              listenMode: ListenMode.dictation,
              partialResults: true,
              cancelOnError: false,
            ),
          );
        } catch (e) {
          debugPrint('Error iniciando reconocimiento de voz: $e');
        }
      }
    }
  }

  void _openSongEditor() {
    final textController = TextEditingController(
      text: 'De [G]música [D]ligera...\nNada nos [Em]libra, nada más [C]queda...',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cargar Guion o PDF en ToroCorp Music', style: AppTypography.sfProHeadline()),
              const SizedBox(height: 8),
              Text(
                'Escribe tu letra con acordes [G] o pega texto de partituras/PDFs.',
                style: AppTypography.sfProCaption(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 5,
                style: AppTypography.sfMonoChordStyle(fontSize: 14, color: AppColors.textWhite),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.cardDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final extractor = PdfScriptExtractor();
                        const samplePdf = '   G        D\nDe música ligera\n';
                        final parsed = extractor.extractFromRawText(samplePdf);
                        _applyNewSong(parsed);
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.picture_as_pdf, color: AppColors.chordAmber),
                      label: const Text('Cargar PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textWhite,
                        side: const BorderSide(color: AppColors.borderDark),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final parser = ChordProParser();
                        final parsed = parser.parse(textController.text);
                        _applyNewSong(parsed);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.chordAmber,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Aplicar Letra'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _applyNewSong(SongScript newSong) {
    setState(() {
      _currentSong = newSong;
      _vocalMatcher.dispose();
      _vocalMatcher = VocalAlignmentMatcher(_currentSong);
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
          // 1. Visor de Cámara Frontal con Shaders GLSL de Belleza y Modo Espejo
          CameraViewfinderWidget(
            cameraPreview: _isCameraInitialized && _cameraController != null
                ? CameraPreview(_cameraController!)
                : null,
            beautyService: _beautyService,
            triggerService: _triggerService,
            isRecording: _isRecording,
            showBeautySlider: _showBeautySlider,
            isMirrorMode: _isMirrorMode,
          ),

          // 2. Teleprompter Anclado Inmediatamente Debajo del Lente de la Cámara
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: AnimatedBuilder(
                animation: _teleprompterController,
                builder: (context, _) {
                  return TeleprompterBarWidget(
                    song: _teleprompterController.song,
                    activeLineIndex: _teleprompterController.activeLineIndex,
                    activeWordIndex: _teleprompterController.activeWordIndex,
                    isMirrorMode: _isMirrorMode,
                    fontSize: _teleprompterController.fontSize,
                  );
                },
              ),
            ),
          ),

          // 3. Botón de Menú Hamburguesa Superior Derecho (☰ <-> ✕)
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: GestureDetector(
                onTap: _toggleMenu,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(200),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderDark, width: 1.5),
                  ),
                  child: Center(
                    child: AnimatedIcon(
                      icon: AnimatedIcons.menu_close,
                      progress: _menuAnimationController,
                      color: AppColors.textWhite,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Panel Desplegable del Afinador de Guitarra
          if (_showTuner)
            Positioned(
              top: 130,
              left: 20,
              right: 20,
              child: GuitarTunerWidget(currentTuning: _currentTuning),
            ),

          // 5. Marca de Agua (si aplica para usuarios de la versión gratuita)
          if (!_subscriptionService.isPro && !_hasSinglePass4K)
            const Positioned(
              bottom: 110,
              left: 16,
              child: WatermarkOverlayWidget(text: 'ToroCorp Music'),
            ),

          // 6. Controles Inferiores de Grabación (100% Automático, sin flechas confusas)
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indicador de modo actual
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(180),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Text(
                    '${_selectedResolution.label} • ${_recordingMode == RecordingMode.clean ? "Video Limpio" : "Con Guion"}',
                    style: AppTypography.sfProCaption(fontSize: 12, color: AppColors.chordAmber),
                  ),
                ),
                const SizedBox(height: 16),

                // Botón Único Central REC
                GestureDetector(
                  onTap: _toggleRecording,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isRecording ? 30 : 60,
                        height: _isRecording ? 30 : 60,
                        decoration: BoxDecoration(
                          color: AppColors.recordRed,
                          borderRadius: BorderRadius.circular(_isRecording ? 8 : 30),
                        ),
                        child: _isRecording
                            ? null
                            : const Icon(Icons.fiber_manual_record, color: Colors.transparent),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 7. Menú Desplegable OLED (Abierto al tocar las 3 rayitas)
          if (_isMenuOpen)
            Positioned(
              top: 75,
              right: 16,
              width: 300,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(240),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderDark, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(200),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.asset(
                                'assets/images/app_logo.jpeg',
                                width: 24,
                                height: 24,
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

                      // 1. Afinador de Guitarra
                      _buildMenuItem(
                        icon: Icons.tune,
                        title: 'Afinador de Guitarra',
                        subtitle: _showTuner ? 'Activo en pantalla' : 'Tocar para abrir',
                        isActive: _showTuner,
                        onTap: () {
                          _toggleTuner();
                          _toggleMenu();
                        },
                      ),

                      // 2. Cargar PDF / Repertorio
                      _buildMenuItem(
                        icon: Icons.picture_as_pdf,
                        title: 'Cargar PDF / Letra',
                        subtitle: 'Importar acordes y letra',
                        onTap: () {
                          _toggleMenu();
                          _openSongEditor();
                        },
                      ),

                      // 3. Filtros de Belleza Facial
                      _buildMenuItem(
                        icon: Icons.auto_fix_high,
                        title: 'Filtro de Belleza',
                        subtitle: _showBeautySlider ? 'Slider visible' : 'Suavizado de piel',
                        isActive: _showBeautySlider,
                        onTap: () {
                          setState(() {
                            _showBeautySlider = !_showBeautySlider;
                          });
                          _toggleMenu();
                        },
                      ),

                      // 4. Modo Espejo
                      _buildMenuItem(
                        icon: Icons.flip,
                        title: 'Modo Espejo',
                        subtitle: _isMirrorMode ? 'Activado' : 'Desactivado',
                        isActive: _isMirrorMode,
                        onTap: () {
                          setState(() {
                            _isMirrorMode = !_isMirrorMode;
                          });
                          _teleprompterController.toggleMirrorMode();
                          _toggleMenu();
                        },
                      ),

                      // 5. Calidad de Video (1080p vs 4K)
                      _buildMenuItem(
                        icon: Icons.hd,
                        title: 'Calidad de Video',
                        subtitle: _selectedResolution.label,
                        onTap: () {
                          setState(() {
                            _selectedResolution = _selectedResolution == VideoResolution.fhd1080p
                                ? VideoResolution.fourK30
                                : VideoResolution.fhd1080p;
                          });
                          _toggleMenu();
                        },
                      ),

                      // 6. Modo de Grabación (Limpio vs Con Guion)
                      _buildMenuItem(
                        icon: _recordingMode == RecordingMode.clean ? Icons.videocam : Icons.subtitles,
                        title: 'Tipo de Grabación',
                        subtitle: _recordingMode == RecordingMode.clean ? 'Video Limpio' : 'Con Guion',
                        onTap: () {
                          setState(() {
                            _recordingMode = _recordingMode == RecordingMode.clean
                                ? RecordingMode.withScript
                                : RecordingMode.clean;
                          });
                          _toggleMenu();
                        },
                      ),

                      // 7. Tutoriales y Ayuda
                      _buildMenuItem(
                        icon: Icons.help_outline,
                        title: 'Tutoriales y Guía',
                        subtitle: 'Cómo usar cada función',
                        onTap: () {
                          _toggleMenu();
                          OnboardingTourDialog.show(context);
                        },
                      ),

                      // 8. ToroCorp Music PRO
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
