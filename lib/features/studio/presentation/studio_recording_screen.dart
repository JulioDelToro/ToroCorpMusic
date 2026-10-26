import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../audio/services/acoustic_vocal_karaoke_service.dart';
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
import '../../teleprompter/widgets/floating_teleprompter_capsule.dart';
import '../../tuner/models/tuning_note.dart';
import '../../tuner/services/pitch_detector.dart';
import '../../tuner/widgets/guitar_tuner_widget.dart';
import '../../tutorials/widgets/onboarding_tour_dialog.dart';

/// Formatos de relaciÃ³n de aspecto de video
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

/// Opciones de color para iluminaciÃ³n karaoke
class KaraokeColorOption {
  final String name;
  final Color color;

  const KaraokeColorOption(this.name, this.color);
}

const List<KaraokeColorOption> kKaraokeColors = [
  KaraokeColorOption('Amarillo NeÃ³n', Color(0xFFFFD60A)),
  KaraokeColorOption('Verde NeÃ³n', Color(0xFF30D158)),
  KaraokeColorOption('Cian ElÃ©ctrico', Color(0xFF64D2FF)),
  KaraokeColorOption('Rosa NeÃ³n', Color(0xFFFF375F)),
  KaraokeColorOption('Naranja Fuego', Color(0xFFFF9F0A)),
  KaraokeColorOption('Blanco Puro', Color(0xFFFFFFFF)),
];

/// Pantalla principal de grabaciÃ³n musical de ToroCorp Music.
/// 
/// Interfaz 100% limpia y minimalista:
/// - Visor de cÃ¡mara sin botones flotantes ni estiramientos.
/// - Teleprompter pegado inmediatamente debajo de la cÃ¡mara para contacto visual.
/// - BotÃ³n rojo REC al centro inferior.
/// - MenÃº desplegable OLED (â˜° <-> âœ•) arriba a la derecha con todas las herramientas.
/// - Motor acÃºstico de karaoke continuo en tiempo real (sin bips ni desconexiones).
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

  // Controlador de CÃ¡mara
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraActive = true; // Permite activar o desactivar la cÃ¡mara (Modo solo Karaoke)

  // Motor AcÃºstico de Karaoke en Tiempo Real (Continuo, sin bips ni desconexiones)
  late AcousticVocalKaraokeService _acousticService;

  // AnimaciÃ³n del MenÃº Hamburguesa (â˜° <-> âœ•)
  late final AnimationController _menuAnimationController;
  bool _isMenuOpen = false;

  // Estado del Teleprompter y CanciÃ³n
  late SongScript _currentSong;
  late VocalAlignmentMatcher _vocalMatcher;
  late TeleprompterController _teleprompterController;

  // Preferencias de grabaciÃ³n seleccionables por el usuario
  FormatOption _selectedFormat = FormatOption.vertical9_16;
  QualityOption _selectedQuality = kQualityOptions[1]; // 1080p 30fps default
  Color _karaokeHighlightColor = const Color(0xFFFFD60A); // Amarillo NeÃ³n default

  // Sensibilidad del micrÃ³fono para el karaoke (-60 dB = muy sensible, -20 dB = poco sensible)
  // El usuario puede ajustar este valor desde el menÃº.
  double _micSensitivityDb = -40.0;

  // Estado de grabaciÃ³n y herramientas
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  bool _showTuner = false;
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

    // Canción inicial con acordes inferiores
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
        LyricLine(tokens: [
          LyricToken(word: 'No', chordUnderneath: 'Em'),
          LyricToken(word: 'le', chordUnderneath: null),
          LyricToken(word: 'enviaré', chordUnderneath: 'C'),
          LyricToken(word: 'cenizas', chordUnderneath: 'G'),
          LyricToken(word: 'de', chordUnderneath: null),
          LyricToken(word: 'rosas,', chordUnderneath: 'D'),
        ]),
        LyricLine(tokens: [
          LyricToken(word: 'ni', chordUnderneath: null),
          LyricToken(word: 'pienso', chordUnderneath: 'Em'),
          LyricToken(word: 'evitar', chordUnderneath: 'C'),
          LyricToken(word: 'un', chordUnderneath: null),
          LyricToken(word: 'roce', chordUnderneath: 'G'),
          LyricToken(word: 'secreto...', chordUnderneath: 'D'),
        ]),
      ],
    );

    _vocalMatcher = VocalAlignmentMatcher(_currentSong);
    _acousticService = AcousticVocalKaraokeService(song: _currentSong);

    _teleprompterController = TeleprompterController(
      initialSong: _currentSong,
      matcher: _vocalMatcher,
      acousticService: _acousticService,
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
        await _startAcousticKaraoke();
      }

      if (!cameraGranted || !micGranted) {
        if (mounted) {
          _showPermissionsDialog();
        }
      }
    } catch (_) {
      // Entorno de pruebas o fallback
      await _initializeCamera();
      await _startAcousticKaraoke();
    }
  }

  Future<void> _initializeCamera() async {
    if (!_isCameraActive) return;
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
      debugPrint('ToroCorp Music: Info cÃ¡mara: $e');
    }
  }

  /// Inicia el motor acÃºstico de karaoke continuo sin bips del sistema
  Future<void> _startAcousticKaraoke() async {
    try {
      // Aplicar sensibilidad actual antes de arrancar
      _acousticService.silenceThresholdDb = _micSensitivityDb;
      final success = await _acousticService.startTracking();
      debugPrint('ToroCorp Music: Seguimiento acÃºstico de voz iniciado: $success');
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('ToroCorp Music: Error iniciando karaoke acÃºstico: $e');
    }
  }

  /// Activa o desactiva la cÃ¡mara manteniendo el micrÃ³fono encendido
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

  /// Dispara la cuenta regresiva manos libres 3-2-1 desde el menÃº
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
            'ToroCorp Music necesita acceso a la CÃ¡mara y al MicrÃ³fono para grabar tus interpretaciones y sincronizar la letra automÃ¡ticamente con tu voz.',
            style: AppTypography.sfProBody(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('MÃ¡s Tarde', style: TextStyle(color: AppColors.textSecondary)),
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
      _recordingSeconds = 0;
      _showTuner = false;
      if (_isMenuOpen) _toggleMenu();
    });

    // Iniciar temporizador de grabaciÃ³n
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isRecording) {
        setState(() {
          _recordingSeconds++;
        });
      }
    });

    // Iniciar grabaciÃ³n de video en la cÃ¡mara si estÃ¡ activa
    if (_isCameraActive && _isCameraInitialized && _cameraController != null) {
      try {
        if (!_cameraController!.value.isRecordingVideo) {
          await _cameraController!.startVideoRecording();
        }
      } catch (e) {
        debugPrint('ToroCorp Music: Info iniciar grabaciÃ³n video: $e');
      }
    }

    // Asegurar que el motor de karaoke acÃºstico estÃ© activo y sincronizado
    if (!_acousticService.isRunning) {
      await _acousticService.startTracking();
    }
  }

  Future<void> _stopRecordingProcess() async {
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
    });

    // Detener cÃ¡mara y obtener archivo de video
    XFile? videoFile;
    if (_isCameraActive && _isCameraInitialized && (_cameraController?.value.isRecordingVideo ?? false)) {
      try {
        videoFile = await _cameraController?.stopVideoRecording();
      } catch (e) {
        debugPrint('Error al detener grabaciÃ³n: $e');
      }
    }

    // Configurar composiciÃ³n
    final config = _compositor.buildConfig(
      mode: _recordingMode,
      resolution: _selectedQuality.isPro ? VideoResolution.fourK30 : VideoResolution.fhd1080p,
      isProUser: _subscriptionService.isPro,
      hasUnlockedSinglePass: _hasSinglePass4K,
    );

    // Guardar en GalerÃ­a local en Ã¡lbum ToroCorpMusic
    if (videoFile != null) {
      await _saveVideoToGallery(videoFile.path);
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
                videoFile != null
                    ? 'Â¡Video guardado en la GalerÃ­a en el Ã¡lbum "ToroCorpMusic" (${config.resolution.label})!'
                    : 'Â¡SesiÃ³n de karaoke finalizada!',
                style: const TextStyle(color: AppColors.textWhite),
              ),
            ),
          );
        }
      },
    );
  }

  /// Guarda el video en la GalerÃ­a del telÃ©fono dentro del Ã¡lbum "ToroCorpMusic"
  Future<void> _saveVideoToGallery(String videoPath) async {
    try {
      await Gal.putVideo(videoPath, album: 'ToroCorpMusic');
      debugPrint('ToroCorp Music: Video guardado en GalerÃ­a / ToroCorpMusic');
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

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Cuadro de diÃ¡logo para seleccionar formato de relaciÃ³n de aspecto
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
              Text('Formato de GrabaciÃ³n', style: AppTypography.sfProHeadline()),
              const SizedBox(height: 6),
              Text(
                'Elige la proporciÃ³n nativa para tu video sin estiramientos.',
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

  // Cuadro de diÃ¡logo para seleccionar calidad y FPS
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
                'Selecciona la resoluciÃ³n y fluidez deseada.',
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

  // Cuadro de diÃ¡logo para seleccionar el color de la letra karaoke
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
              Text('Color de IluminaciÃ³n Karaoke', style: AppTypography.sfProHeadline()),
              const SizedBox(height: 6),
              Text(
                'Elige el color con el que brillarÃ¡ la letra conforme cantas.',
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


  void _openMicSensitivityModal() {
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
                      const Icon(Icons.mic, color: AppColors.chordAmber, size: 24),
                      const SizedBox(width: 10),
                      Text('Sensibilidad del Micrófono', style: AppTypography.sfProHeadline()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ajusta que tan fuerte tienes que cantar para que el karaoke te siga. Si el karaoke avanza solo sin que cantes, baja la sensibilidad.',
                    style: AppTypography.sfProCaption(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Muy Sensible', style: AppTypography.sfProCaption(fontSize: 11, color: AppColors.textSecondary)),
                      Text(_micSensitivityLabel(), style: AppTypography.sfProHeadline(fontSize: 15, color: AppColors.chordAmber)),
                      Text('Poco Sensible', style: AppTypography.sfProCaption(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                  Slider(
                    value: _micSensitivityDb,
                    min: -60.0,
                    max: -15.0,
                    divisions: 18,
                    activeColor: AppColors.chordAmber,
                    inactiveColor: AppColors.borderDark,
                    onChanged: (val) {
                      setModalState(() {});
                      setState(() => _micSensitivityDb = val);
                      _acousticService.silenceThresholdDb = val;
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSensPreset('Estudio\nSilencioso', -55.0, setModalState),
                      _buildSensPreset('Normal\n(Recomendado)', -40.0, setModalState),
                      _buildSensPreset('Cuarto\nRuidoso', -25.0, setModalState),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.chordAmber,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('Listo'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSensPreset(String label, double value, StateSetter setModalState) {
    final isSelected = (_micSensitivityDb - value).abs() < 1.0;
    return GestureDetector(
      onTap: () {
        setState(() => _micSensitivityDb = value);
        _acousticService.silenceThresholdDb = value;
        setModalState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.chordAmber.withAlpha(40) : AppColors.cardDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.chordAmber : AppColors.borderDark,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? AppColors.chordAmber : AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  String _micSensitivityLabel() {
    final int val = _micSensitivityDb.toInt();
    if (_micSensitivityDb <= -50) return 'Muy sensible ($val dB)';
    if (_micSensitivityDb <= -35) return 'Normal ($val dB)';
    return 'Poco sensible ($val dB)';
  }
  void _openSongEditor() {
    final textController = TextEditingController(
      text: 'De [G]mÃºsica [D]ligera...\nNada nos [Em]libra, nada mÃ¡s [C]queda...',
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
                        const samplePdf = '   G        D\nDe mÃºsica ligera\n';
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
          // 1. Visor de CÃ¡mara Frontal 100% Limpio (con relaciÃ³n de aspecto 9:16 nativa)
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
                    tokens: _teleprompterController.song.allTokens,
                    currentWordIndex: _teleprompterController.globalActiveWordIndex,
                    isSinging: _teleprompterController.isSinging,
                    isWaitingForVoice: _teleprompterController.isWaitingForVoice,
                    isRecording: _isRecording,
                    recordingSeconds: _recordingSeconds,
                    highlightColor: _karaokeHighlightColor,
                    onSettingsTap: _toggleMenu,
                    onWordTap: (globalIndex) {
                      _teleprompterController.jumpToGlobalWord(globalIndex);
                    },
                    onResetTap: _teleprompterController.reset,
                  );
                },
              ),
            ),
          ),

          // 3. Botón de Menú Superior Derecho (☰ <-> ✕)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(200),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderDark, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(120),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedIcon(
                    icon: AnimatedIcons.menu_close,
                    progress: _menuAnimationController,
                    color: AppColors.textWhite,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),

          // 4. Panel Desplegable del Afinador de Guitarra (cuando estÃ¡ activo)
          if (_showTuner)
            Positioned(
              top: 130,
              left: 20,
              right: 20,
              child: GuitarTunerWidget(currentTuning: _currentTuning),
            ),

          // 5. BotÃ³n Ãšnico Central REC y Temporizador de GrabaciÃ³n (Pantalla Limpia)
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isRecording)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(200),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.recordRed, width: 1.5),
                      ),
                      child: Text(
                        _formatTimer(_recordingSeconds),
                        style: const TextStyle(
                          color: AppColors.recordRed,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),

                // BotÃ³n Circular Central REC
                GestureDetector(
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
              ],
            ),
          ),

          // 6. MenÃº Desplegable OLED Completo (â˜° <-> âœ•)
          if (_isMenuOpen)
            Positioned(
              top: 75,
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
                          subtitle: 'Iniciar grabaciÃ³n manos libres',
                          onTap: _triggerHandsFreeCountdown,
                        ),

                        // 2. Activar / Desactivar CÃ¡mara (Modo solo Karaoke)
                        _buildMenuItem(
                          icon: _isCameraActive ? Icons.videocam : Icons.videocam_off,
                          iconColor: _isCameraActive ? AppColors.tunerInTuneGreen : AppColors.textSecondary,
                          title: 'CÃ¡mara (Video)',
                          subtitle: _isCameraActive ? 'Activada' : 'Desactivada (Solo Karaoke)',
                          isActive: _isCameraActive,
                          onTap: () {
                            _toggleCameraActive();
                            _toggleMenu();
                          },
                        ),

                        // 3. Afinador de Guitarra
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

                        // 4. Formato de GrabaciÃ³n (9:16, 16:9, etc.)
                        _buildMenuItem(
                          icon: Icons.aspect_ratio,
                          title: 'Formato de GrabaciÃ³n',
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
                          subtitle: 'Personalizar iluminaciÃ³n',
                          onTap: () {
                            _toggleMenu();
                            _openKaraokeColorPickerModal();
                          },
                        ),

                        // 6b. Sensibilidad del MicrÃ³fono para Karaoke
                        _buildMenuItem(
                          icon: Icons.mic,
                          title: 'Sensibilidad MicrÃ³fono',
                          subtitle: _micSensitivityLabel(),
                          onTap: () {
                            _toggleMenu();
                            _openMicSensitivityModal();
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

                        // 8. Modo Espejo
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

                        // 9. Cargar PDF / Repertorio
                        _buildMenuItem(
                          icon: Icons.picture_as_pdf,
                          title: 'Cargar PDF / Letra',
                          subtitle: 'Importar acordes y letra',
                          onTap: () {
                            _toggleMenu();
                            _openSongEditor();
                          },
                        ),

                        // 10. Tipo de GrabaciÃ³n (Limpio vs Con Guion)
                        _buildMenuItem(
                          icon: _recordingMode == RecordingMode.clean ? Icons.videocam : Icons.subtitles,
                          title: 'Tipo de GrabaciÃ³n',
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

                        // 11. Tutoriales y GuÃ­a
                        _buildMenuItem(
                          icon: Icons.help_outline,
                          title: 'Tutoriales y GuÃ­a',
                          subtitle: 'CÃ³mo usar cada funciÃ³n',
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
                          subtitle: 'Sin anuncios â€¢ 4K 60FPS',
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

