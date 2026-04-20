import 'dart:developer' as developer;
import 'package:web/web.dart' as web;
import 'tone_player_stub.dart';

/// Web implementation using Web Audio API through JS interop
class WebTonePlayer implements PlatformTonePlayer {
  web.AudioContext? _audioContext;

  web.AudioContext get _context {
    _audioContext ??= web.AudioContext();
    return _audioContext!;
  }

  @override
  Future<void> playTone(double frequency, int durationMs) async {
    try {
      final context = _context;
      final oscillator = context.createOscillator();
      final gainNode = context.createGain();

      oscillator.connect(gainNode);
      gainNode.connect(context.destination);

      oscillator.frequency.value = frequency;
      oscillator.type = 'sine';

      // Set volume with envelope to avoid clicks
      final now = context.currentTime;
      final duration = durationMs / 1000.0;
      const fadeTime = 0.01; // 10ms fade

      final gain = gainNode.gain;
      gain.setValueAtTime(0, now);
      gain.linearRampToValueAtTime(0.3, now + fadeTime);
      gain.setValueAtTime(0.3, now + duration - fadeTime);
      gain.linearRampToValueAtTime(0, now + duration);

      oscillator.start(now);
      oscillator.stop(now + duration);
    } catch (e) {
      // Ignore errors - audio is best-effort
      developer.log('Web audio error', error: e, name: 'WebTonePlayer');
    }
  }

  @override
  void dispose() {
    try {
      _audioContext?.close();
    } catch (e) {
      // Ignore
    }
    _audioContext = null;
  }
}

PlatformTonePlayer createPlatformPlayer() => WebTonePlayer();
