import 'dart:async';
// Conditional imports for web vs mobile
import 'tone_player_stub.dart'
    if (dart.library.html) 'tone_player_web.dart'
    if (dart.library.io) 'tone_player_mobile.dart' as platform;

/// Service for playing musical tones and metronome clicks.
class TonePlayer {
  Timer? _metronomeTimer;
  bool _isMetronomeRunning = false;
  final _platformPlayer = platform.createPlatformPlayer();

  bool get isMetronomeRunning => _isMetronomeRunning;

  /// Plays a musical note at the given frequency.
  Future<void> playNote(double frequency) async {
    if (frequency <= 0) return;
    await _platformPlayer.playTone(frequency, 300);
  }

  /// Starts the metronome at the given tempo (BPM).
  void startMetronome(double bpm, {String sound = 'tick', void Function()? onBeat}) {
    stopMetronome();

    final intervalMs = (60000.0 / bpm).round();
    _isMetronomeRunning = true;

    // Play click immediately
    _playMetronomeClick(sound);
    onBeat?.call();

    _metronomeTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) {
        _playMetronomeClick(sound);
        onBeat?.call();
      },
    );
  }

  /// Stops the metronome.
  void stopMetronome() {
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
    _isMetronomeRunning = false;
  }

  /// Plays a metronome click sound.
  Future<void> _playMetronomeClick(String sound) async {
    if (sound == 'beep') {
      await _platformPlayer.playTone(1000.0, 100);
    } else {
      // Default 'tick' - shorter and higher pitch for a "tick" sound
      await _platformPlayer.playTone(2000.0, 20);
    }
  }

  /// Disposes of resources.
  void dispose() {
    stopMetronome();
    _platformPlayer.dispose();
  }
}
