import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/metronome_audio_synth.dart';

/// Supported standard musical time signatures.
enum MetronomeTimeSignature {
  twoFour(2, '2/4', 'Marcha / Corrido'),
  threeFour(3, '3/4', 'Vals / Ranchera'),
  fourFour(4, '4/4', 'Estándar 4/4'),
  sixEight(6, '6/8', 'Huapango / 6/8');

  final int beatsPerBar;
  final String label;
  final String description;

  const MetronomeTimeSignature(this.beatsPerBar, this.label, this.description);
}

/// Callback type invoked on each rhythmic beat click.
typedef MetronomeBeatCallback = void Function(
  int beatInBar,
  bool isDownbeat,
  Uint8List wavBytes,
);

/// Controller managing tempo, time signatures, tap tempo calculation,
/// drift-compensated Stopwatch scheduling, and audio clicks.
class MetronomeController extends ChangeNotifier {
  static const int minBpm = 40;
  static const int maxBpm = 240;
  static const int defaultBpm = 120;
  static const Duration tapResetTimeout = Duration(milliseconds: 2500);

  int _bpm = defaultBpm;
  MetronomeTimeSignature _timeSignature = MetronomeTimeSignature.fourFour;
  bool _isPlaying = false;
  int _currentBeat = 0; // 0 = idle/stopped, 1..beatsPerBar when active
  bool _isDownbeat = false;

  final MetronomeAudioSynth _synth;
  final MetronomeBeatCallback? onPlayClick;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _scheduleTimer;
  int _beatCounter = 0;
  int _baseElapsedUs = 0;

  // Tap tempo state
  final List<DateTime> _tapTimes = [];

  MetronomeController({
    int initialBpm = defaultBpm,
    MetronomeTimeSignature initialTimeSignature = MetronomeTimeSignature.fourFour,
    MetronomeAudioSynth? audioSynth,
    this.onPlayClick,
  })  : _bpm = initialBpm.clamp(minBpm, maxBpm),
        _timeSignature = initialTimeSignature,
        _synth = audioSynth ?? MetronomeAudioSynth();

  int get bpm => _bpm;
  MetronomeTimeSignature get timeSignature => _timeSignature;
  bool get isPlaying => _isPlaying;
  int get currentBeat => _currentBeat;
  bool get isDownbeat => _isDownbeat;
  MetronomeAudioSynth get synth => _synth;

  /// Classical Italian tempo term for the current BPM.
  String get tempoMarking {
    if (_bpm < 60) return 'Largo';
    if (_bpm < 66) return 'Larghetto';
    if (_bpm < 76) return 'Adagio';
    if (_bpm < 108) return 'Andante';
    if (_bpm < 120) return 'Moderato';
    if (_bpm < 156) return 'Allegro';
    if (_bpm < 176) return 'Vivace';
    if (_bpm < 200) return 'Presto';
    return 'Prestissimo';
  }

  /// Sets the BPM clamped to the range [40, 240].
  void setBpm(int newBpm) {
    final clamped = newBpm.clamp(minBpm, maxBpm);
    if (_bpm == clamped) return;
    _bpm = clamped;
    if (_isPlaying) {
      _baseElapsedUs = _stopwatch.elapsedMicroseconds;
      _beatCounter = 0;
      _scheduleTimer?.cancel();
      _scheduleNextBeat();
    }
    notifyListeners();
  }

  /// Increments tempo by 1 BPM (up to 240).
  void incrementBpm() {
    setBpm(_bpm + 1);
  }

  /// Decrements tempo by 1 BPM (down to 40).
  void decrementBpm() {
    setBpm(_bpm - 1);
  }

  /// Updates the time signature and resets/aligns the active beat counter if running.
  void setTimeSignature(MetronomeTimeSignature signature) {
    if (_timeSignature == signature) return;
    _timeSignature = signature;
    if (_isPlaying) {
      _baseElapsedUs = _stopwatch.elapsedMicroseconds;
      _beatCounter = 0;
      _currentBeat = 0;
      _scheduleTimer?.cancel();
      _scheduleNextBeat();
    }
    notifyListeners();
  }

  /// Tap Tempo algorithm:
  /// - Resets tap history if silence > 2500ms has elapsed.
  /// - Computes rolling average interval of up to 8 recent consecutive taps.
  /// - Updates BPM clamped between 40 and 240.
  int tapTempo([DateTime? simulatedTime]) {
    final now = simulatedTime ?? DateTime.now();

    if (_tapTimes.isNotEmpty && now.difference(_tapTimes.last) > tapResetTimeout) {
      _tapTimes.clear();
    }

    _tapTimes.add(now);

    if (_tapTimes.length < 2) {
      // First tap after reset: keep current BPM
      notifyListeners();
      return _bpm;
    }

    // Keep up to 8 recent taps for a responsive rolling average
    final recent = _tapTimes.length > 8
        ? _tapTimes.sublist(_tapTimes.length - 8)
        : _tapTimes;

    int totalDeltaMs = 0;
    for (int i = 1; i < recent.length; i++) {
      totalDeltaMs += recent[i].difference(recent[i - 1]).inMilliseconds;
    }

    final avgIntervalMs = totalDeltaMs / (recent.length - 1);
    if (avgIntervalMs > 0) {
      final calculatedBpm = (60000.0 / avgIntervalMs).round().clamp(minBpm, maxBpm);
      setBpm(calculatedBpm);
    }

    return _bpm;
  }

  /// Starts the metronome with drift-compensated Stopwatch scheduling.
  void start() {
    if (_isPlaying) return;
    _isPlaying = true;
    _stopwatch.reset();
    _stopwatch.start();
    _baseElapsedUs = 0;
    _beatCounter = 0;

    // First beat triggers immediately
    _triggerBeat(1, true);

    _scheduleNextBeat();
    notifyListeners();
  }

  /// Stops the metronome and resets current beat indicators.
  void stop() {
    _isPlaying = false;
    _scheduleTimer?.cancel();
    _scheduleTimer = null;
    _stopwatch.stop();
    _stopwatch.reset();
    _baseElapsedUs = 0;
    _beatCounter = 0;
    _currentBeat = 0;
    _isDownbeat = false;
    notifyListeners();
  }

  /// Toggles between playing and stopped state.
  void togglePlay() {
    if (_isPlaying) {
      stop();
    } else {
      start();
    }
  }

  /// Internal drift-compensated tick scheduler.
  ///
  /// Rather than accumulating Timer.periodic jitter, each subsequent beat
  /// is anchored to the Stopwatch zero start time (or base elapsed time on tempo change):
  /// targetElapsed = baseElapsed + (beatCounter * beatInterval)
  void _scheduleNextBeat() {
    if (!_isPlaying) return;

    final beatIntervalUs = (60000000.0 / _bpm).round();
    _beatCounter++;

    final targetElapsedUs = _baseElapsedUs + (_beatCounter * beatIntervalUs);
    final currentElapsedUs = _stopwatch.elapsedMicroseconds;
    final delayUs = targetElapsedUs - currentElapsedUs;

    _scheduleTimer = Timer(Duration(microseconds: math.max(0, delayUs)), () {
      if (!_isPlaying) return;

      final beatInBar = (_currentBeat % _timeSignature.beatsPerBar) + 1;
      final isAccent = beatInBar == 1;

      _triggerBeat(beatInBar, isAccent);
      _scheduleNextBeat();
    });
  }

  void _triggerBeat(int beatInBar, bool isAccent) {
    _currentBeat = beatInBar;
    _isDownbeat = isAccent;

    final wavBytes = _synth.getBeatSound(isDownbeat: isAccent);

    if (onPlayClick != null) {
      onPlayClick!(beatInBar, isAccent, wavBytes);
    } else {
      // Acoustic haptic/system click fallback for mobile device speakers
      SystemSound.play(SystemSoundType.click);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
