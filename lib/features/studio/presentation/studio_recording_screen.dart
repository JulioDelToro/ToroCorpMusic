import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
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
  bool _isListeningVoiceCommand = false;

  // Animación del Menú Hamburguesa (☰ <-> ✕)
  late final AnimationController _menuAnimationController;
  bool _isMenuOpen = false;

  // Estado del Teleprompter y Canción
  late SongScript _currentSong;
  late VocalAlignmentMatcher _vocalMatcher;
  late TeleprompterController _teleprompterController;

  // Preferencias de grabación seleccionables por el usuario
  FormatOption _selectedFormat = FormatOption.vertical9_16;
  QualityOption _selectedQuality = kQualityOptions[1]; // 1080p 30fps default
  Color _karaokeHighlightColor = const Color(0xFFFFD60A); // Amarillo Neón default
  bool _isHandsFreeVoiceActive = true;

  // Estado de grabación y herramientas
  bool _isRecording = false;
  bool _showTuner = false;
  bool _showBeautySlider = false;
  bool _isMirrorMode = false;
  bool _hasSinglePass4K = false;
  RecordingMode _recordingMode = RecordingMode.clean;

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
      onCountdownComplete: () {
        _startRecordingProcess();
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
      // Entorno de escritorio o pruebas
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
      debugPrint('ToroCorp Music: Info cámara: $e');
    }
  }

  Future<void> _initializeSpeech() async {
    try {
      _speechAvailable = await _speechToText.initialize(
        onStatus: (status) {
          debugPrint('ToroCorp Music STT: $status');
          if (_isRecording && (status == 'done' || status == 'notListening')) {
            _restartKaraokeListening();
          } else if (!_isRecording && _isHandsFreeVoiceActive && (status == 'done' || status == 'notListening')) {
            _restartVoiceCommandListening();
          }
        },
        onError: (error) {
          debugPrint('ToroCorp Music STT Error: $error');
          if (_isRecording) {
            _restartKaraokeListening();
          } else if (!_isRecording && _isHandsFreeVoiceActive) {
            _restartVoiceCommandListening();
          }
        },
      );

      if (_speechAvailable && _isHandsFreeVoiceActive && !_isRecording) {
        _startVoiceCommandListening();
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('ToroCorp Music: Info STT: $e');
    }
  }

  /// Escucha el comando "grabar" en modo reposo
  Future<void> _startVoiceCommandListening() async {
    if (!_speechAvailable || _isRecording || _isListeningVoiceCommand) return;
    try {
      _isListeningVoiceCommand = true;
      await _speechToText.listen(
        onResult: (result) {
          final text = result.recognizedWords.toLowerCase();
          if (text.contains('grabar') || text.contains('graba') || text.contains('record') || text.contains('iniciar')) {
            _speechToText.stop();
            _isListeningVoiceCommand = false;
            _triggerService.triggerFromVoiceCommand('grabar');
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
      );
    } catch (e) {
      _isListeningVoiceCommand = false;
      debugPrint('Error escuchando comando de voz: $e');
    }
  }

  void _restartVoiceCommandListening() {
    if (!mounted || _isRecording || !_isHandsFreeVoiceActive) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_isRecording && _isHandsFreeVoiceActive) {
        _startVoiceCommandListening();
      }
    });
  }

  void _restartKaraokeListening() {
    if (!mounted || !_isRecording) return;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _isRecording) {
        _startKaraokeListening();
      }
    });
  }

  Future<void> _startKaraokeListening() async {
    if (!_speechAvailable) {
      await _initializeSpeech();
    }
    try {
      await _speechToText.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            _vocalMatcher.processUtterance(result.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
      );
    } catch (e) {
      debugPrint('Error en escucha de karaoke: $e');
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
      await _stopRecordingProcess();
    } else {
      await _startRecordingProcess();
    }
  }

  Future<void> _startRecordingProcess() async {
    setState(() {
      _isRecording = true;
      _showTuner = false;
      if (_isMenuOpen) _toggleMenu();
    });

    // Iniciar grabación de video en la cámara
    if (_isCameraInitialized && _cameraController != null) {
      try {
        if (!_cameraController!.value.isRecordingVideo) {
          await _cameraController!.startVideoRecording();
        }
      } catch (e) {
        debugPrint('ToroCorp Music: Info iniciar grabación: $e');
      }
    }

    // Iniciar seguimiento de voz para el karaoke
    _vocalMatcher.resetUtterance();
    await _startKaraokeListening();
  }

  Future<void> _stopRecordingProcess() async {
    setState(() {
      _isRecording = false;
    });

    if (_speechAvailable) {
      await _speechToText.stop();
    }

    // Detener cámara y obtener archivo de video
    XFile? videoFile;
    if (_isCameraInitialized && (_cameraController?.value.isRecordingVideo ?? false)) {
      try {
        videoFile = await _cameraController?.stopVideoRecording();
      } catch (e) {
        debugPrint('Error al detener grabación: $e');
      }
    }

    // Configurar composición
    final config = _compositor.buildConfig(
      mode: _recordingMode,
      resolution: _selectedQuality.isPro ? VideoResolution.fourK30 : VideoResolution.fhd1080p,
      isProUser: _subscriptionService.isPro,
      hasUnlockedSinglePass: _hasSinglePass4K,
    );

    // Guardar en Galería local en álbum ToroCorpMusic
    if (videoFile != null) {
      await _saveVideoToGallery(videoFile.path);
    }

    // Reiniciar escucha de comando "grabar" si está activo
    if (_isHandsFreeVoiceActive) {
      _restartVoiceCommandListening();
    }

    // Mostrar anuncio intersticial al guardar
    _adManager.showSaveInterstitial(
      isProUser: _subscriptionService.isPro,
      onDismissed: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.surfaceDark,
              content: Text(
                '¡Video guardado en la Galería en el álbum "ToroCorpMusic" (${config.resolution.label})!',
                style: const TextStyle(color: AppColors.textWhite),
              ),
            ),
          );
        }
      },
    );
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
                        },
                      );
                    } else {
                      setState(() {
                        _selectedQuality = opt;
                      });
                      Navigator.of(context).pop();
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
          // 1. Visor de Cámara Frontal con relación de aspecto nativa (9:16, 16:9, etc.)
          CameraViewfinderWidget(
            cameraPreview: _isCameraInitialized && _cameraController != null
                ? CameraPreview(_cameraController!)
                : null,
            beautyService: _beautyService,
            triggerService: _triggerService,
            isRecording: _isRecording,
            showBeautySlider: _showBeautySlider,
            isMirrorMode: _isMirrorMode,
            aspectRatio: _selectedFormat.ratio,
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
                    highlightColor: _karaokeHighlightColor,
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

          // 5. Controles Inferiores de Grabación (100% Automático)
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indicador de modo actual interactivo (toca para cambiar formato)
                GestureDetector(
                  onTap: _openFormatSelectionModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(190),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_selectedFormat.label} • ${_selectedQuality.title}',
                          style: AppTypography.sfProCaption(fontSize: 12, color: AppColors.chordAmber),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, color: AppColors.chordAmber, size: 16),
                      ],
                    ),
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

          // 6. Menú Desplegable OLED (Abierto al tocar las 3 rayitas)
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

                      // 2. Formato de Grabación (9:16, 16:9, etc.)
                      _buildMenuItem(
                        icon: Icons.aspect_ratio,
                        title: 'Formato de Grabación',
                        subtitle: _selectedFormat.label,
                        onTap: () {
                          _toggleMenu();
                          _openFormatSelectionModal();
                        },
                      ),

                      // 3. Calidad de Video y FPS
                      _buildMenuItem(
                        icon: Icons.hd,
                        title: 'Calidad de Video',
                        subtitle: _selectedQuality.title,
                        onTap: () {
                          _toggleMenu();
                          _openQualitySelectionModal();
                        },
                      ),

                      // 4. Color de Letra Karaoke
                      _buildMenuItem(
                        icon: Icons.palette,
                        iconColor: _karaokeHighlightColor,
                        title: 'Color Letra Karaoke',
                        subtitle: 'Personalizar brillo',
                        onTap: () {
                          _toggleMenu();
                          _openKaraokeColorPickerModal();
                        },
                      ),

                      // 5. Cargar PDF / Repertorio
                      _buildMenuItem(
                        icon: Icons.picture_as_pdf,
                        title: 'Cargar PDF / Letra',
                        subtitle: 'Importar acordes y letra',
                        onTap: () {
                          _toggleMenu();
                          _openSongEditor();
                        },
                      ),

                      // 6. Filtro de Belleza Facial
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

                      // 7. Modo Espejo
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

                      // 8. Disparador Manos Libres por Voz ("grabar")
                      _buildMenuItem(
                        icon: Icons.mic,
                        title: 'Comando de Voz ("Grabar")',
                        subtitle: _isHandsFreeVoiceActive ? 'Escucha activa' : 'Desactivado',
                        isActive: _isHandsFreeVoiceActive,
                        onTap: () {
                          setState(() {
                            _isHandsFreeVoiceActive = !_isHandsFreeVoiceActive;
                            if (_isHandsFreeVoiceActive) {
                              _startVoiceCommandListening();
                            } else {
                              _speechToText.stop();
                            }
                          });
                          _toggleMenu();
                        },
                      ),

                      // 9. Tipo de Grabación (Limpio vs Con Guion)
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

                      // 10. Tutoriales y Ayuda
                      _buildMenuItem(
                        icon: Icons.help_outline,
                        title: 'Tutoriales y Guía',
                        subtitle: 'Cómo usar cada función',
                        onTap: () {
                          _toggleMenu();
                          OnboardingTourDialog.show(context);
                        },
                      ),

                      // 11. ToroCorp Music PRO
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
