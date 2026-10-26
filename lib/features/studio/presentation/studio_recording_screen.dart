import 'package:flutter/material.dart';
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

/// Pantalla principal de grabación musical (Studio Recording Screen)
/// Integra el visor de cámara con filtro de belleza, teleprompter con acordes inferiores,
/// afinador, disparadores de palma/voz, y compositor de video.
class StudioRecordingScreen extends StatefulWidget {
  const StudioRecordingScreen({super.key});

  @override
  State<StudioRecordingScreen> createState() => _StudioRecordingScreenState();
}

class _StudioRecordingScreenState extends State<StudioRecordingScreen> {
  // Servicios del sistema
  late final BeautyShaderService _beautyService;
  late final HandsFreeTriggerService _triggerService;
  late final SubscriptionService _subscriptionService;
  late final AdManager _adManager;
  late final VideoRecordingCompositor _compositor;
  late final PitchDetector _pitchDetector;

  // Estado del Teleprompter y Canción
  late SongScript _currentSong;
  late VocalAlignmentMatcher _vocalMatcher;
  late TeleprompterController _teleprompterController;

  // Estado de grabación y herramientas
  bool _isRecording = false;
  bool _showTuner = false;
  bool _hasSinglePass4K = false;
  RecordingMode _recordingMode = RecordingMode.clean;
  VideoResolution _selectedResolution = VideoResolution.fhd1080p;

  // Estado del afinador
  late TuningResult _currentTuning;

  void _toggleTuner() {
    setState(() {
      _showTuner = !_showTuner;
      if (_showTuner) {
        _currentTuning = _pitchDetector.analyzeFrequency(82.41);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _beautyService = BeautyShaderService();
    _subscriptionService = SubscriptionService();
    _adManager = AdManager();
    _compositor = VideoRecordingCompositor();
    _pitchDetector = PitchDetector();
    _currentTuning = _pitchDetector.analyzeFrequency(82.41);

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
  }

  @override
  void dispose() {
    _beautyService.dispose();
    _triggerService.dispose();
    _subscriptionService.dispose();
    _vocalMatcher.dispose();
    _teleprompterController.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    if (_isRecording) {
      // Detener grabación y procesar guardado
      setState(() {
        _isRecording = false;
      });

      final config = _compositor.buildConfig(
        mode: _recordingMode,
        resolution: _selectedResolution,
        isProUser: _subscriptionService.isPro,
        hasUnlockedSinglePass: _hasSinglePass4K,
      );

      // Mostrar anuncio intersticial al guardar (no interrumpe la toma)
      _adManager.showSaveInterstitial(
        isProUser: _subscriptionService.isPro,
        onDismissed: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.surfaceDark,
                content: Text(
                  'Video guardado con éxito (${config.resolution.label} - ${config.mode == RecordingMode.clean ? "Limpio" : "Con Guion"})',
                  style: const TextStyle(color: AppColors.textWhite),
                ),
              ),
            );
          }
        },
      );
    } else {
      // Iniciar grabación directa o tras cuenta regresiva
      setState(() {
        _isRecording = true;
        _showTuner = false; // El afinador se oculta durante la grabación
      });
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
              Text('Cargar Guion o PDF', style: AppTypography.sfProHeadline()),
              const SizedBox(height: 8),
              Text(
                'Escribe tu letra con acordes [G] o pega texto de partituras.',
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
                        // Simulación de lectura de PDF con notas arriba
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
          // 1. Visor de Cámara con Shaders GLSL de Belleza
          CameraViewfinderWidget(
            beautyService: _beautyService,
            triggerService: _triggerService,
            isRecording: _isRecording,
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
                    isMirrorMode: _teleprompterController.isMirrorMode,
                    fontSize: _teleprompterController.fontSize,
                  );
                },
              ),
            ),
          ),

          // 3. Barra Superior de Herramientas Musicales y Tutoriales
          Positioned(
            top: 170,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Afinador
                IconButton(
                  onPressed: _toggleTuner,
                  icon: Icon(
                    Icons.tune,
                    color: _showTuner ? AppColors.tunerInTuneGreen : AppColors.textWhite,
                  ),
                  tooltip: 'Afinador de Guitarra',
                ),

                // Editor de Canciones / PDF
                IconButton(
                  onPressed: _openSongEditor,
                  icon: const Icon(Icons.library_music, color: AppColors.textWhite),
                  tooltip: 'Cargar Canción o PDF',
                ),

                // Modo Espejo
                IconButton(
                  onPressed: _teleprompterController.toggleMirrorMode,
                  icon: Icon(
                    Icons.flip,
                    color: _teleprompterController.isMirrorMode ? AppColors.chordAmber : AppColors.textWhite,
                  ),
                  tooltip: 'Modo Espejo',
                ),

                // Tutorial de Bienvenida
                IconButton(
                  onPressed: () => OnboardingTourDialog.show(context),
                  icon: const Icon(Icons.help_outline, color: AppColors.textWhite),
                  tooltip: 'Tutoriales y Ayuda',
                ),

                // Botón Toro Music Pro
                IconButton(
                  onPressed: () {
                    ProUpgradeDialog.show(
                      context,
                      subscriptionService: _subscriptionService,
                      adManager: _adManager,
                      onSinglePassUnlocked: () {
                        setState(() => _hasSinglePass4K = true);
                      },
                    );
                  },
                  icon: const Icon(Icons.star, color: AppColors.chordAmber),
                  tooltip: 'Toro Music PRO',
                ),
              ],
            ),
          ),

          // 4. Panel Desplegable del Afinador de Guitarra
          if (_showTuner)
            Positioned(
              top: 225,
              left: 20,
              right: 20,
              child: GuitarTunerWidget(currentTuning: _currentTuning),
            ),

          // 5. Marca de Agua (si aplica para usuarios de la versión gratuita)
          if (!_subscriptionService.isPro && !_hasSinglePass4K)
            const Positioned(
              bottom: 110,
              left: 16,
              child: WatermarkOverlayWidget(),
            ),

          // 6. Controles Inferiores de Grabación y Modos
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selectores de Modo y Resolución
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Selector: Limpio vs Con Guion
                    _buildPillButton(
                      label: _recordingMode == RecordingMode.clean ? 'Video Limpio' : 'Con Guion',
                      icon: _recordingMode == RecordingMode.clean ? Icons.videocam : Icons.subtitles,
                      onTap: () {
                        setState(() {
                          _recordingMode = _recordingMode == RecordingMode.clean
                              ? RecordingMode.withScript
                              : RecordingMode.clean;
                        });
                      },
                    ),
                    const SizedBox(width: 12),

                    // Selector de Resolución
                    _buildPillButton(
                      label: _selectedResolution.label,
                      icon: _selectedResolution.isProOnly ? Icons.lock_open : Icons.hd,
                      onTap: () {
                        setState(() {
                          _selectedResolution = _selectedResolution == VideoResolution.fhd1080p
                              ? VideoResolution.fourK30
                              : VideoResolution.fhd1080p;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Botón Gigante Central de Grabación y Salto de Estrofas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Retroceder palabra
                    IconButton(
                      onPressed: _vocalMatcher.previousWord,
                      icon: const Icon(Icons.fast_rewind, color: AppColors.textWhite, size: 28),
                    ),

                    // Botón Central REC
                    GestureDetector(
                      onTap: _toggleRecording,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _isRecording ? 28 : 56,
                            height: _isRecording ? 28 : 56,
                            decoration: BoxDecoration(
                              color: AppColors.recordRed,
                              borderRadius: BorderRadius.circular(_isRecording ? 6 : 28),
                            ),
                            child: _isRecording
                                ? null
                                : const Icon(Icons.fiber_manual_record, color: Colors.transparent),
                          ),
                        ),
                      ),
                    ),

                    // Avanzar palabra
                    IconButton(
                      onPressed: _vocalMatcher.nextWord,
                      icon: const Icon(Icons.fast_forward, color: AppColors.textWhite, size: 28),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(180),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.chordAmber),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.sfProCaption(fontSize: 12, color: AppColors.textWhite)),
          ],
        ),
      ),
    );
  }
}
