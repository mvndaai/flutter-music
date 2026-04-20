import 'dart:js' as js;
import 'tone_player_stub.dart';

/// Web implementation using Web Audio API through JS interop
class WebTonePlayer implements PlatformTonePlayer {
  js.JsObject? _audioContext;

  js.JsObject get _context {
    if (_audioContext == null) {
      final audioContextClass = js.context['AudioContext'] ?? js.context['webkitAudioContext'];
      _audioContext = js.JsObject(audioContextClass as js.JsFunction);
    }
    return _audioContext!;
  }

  @override
  Future<void> playTone(double frequency, int durationMs) async {
    try {
      final context = _context;
      final oscillator = context.callMethod('createOscillator');
      final gainNode = context.callMethod('createGain');

      oscillator.callMethod('connect', [gainNode]);
      gainNode.callMethod('connect', [context['destination']]);

      oscillator['frequency']['value'] = frequency;
      oscillator['type'] = 'sine';

      // Set volume with envelope to avoid clicks
      final now = context['currentTime'] as num;
      final duration = durationMs / 1000.0;
      final fadeTime = 0.01; // 10ms fade

      final gain = gainNode['gain'];
      gain.callMethod('setValueAtTime', [0, now]);
      gain.callMethod('linearRampToValueAtTime', [0.3, now + fadeTime]);
      gain.callMethod('setValueAtTime', [0.3, now + duration - fadeTime]);
      gain.callMethod('linearRampToValueAtTime', [0, now + duration]);

      oscillator.callMethod('start', [now]);
      oscillator.callMethod('stop', [now + duration]);
    } catch (e) {
      // Ignore errors - audio is best-effort
      print('Web audio error: $e');
    }
  }

  @override
  void dispose() {
    try {
      _audioContext?.callMethod('close');
    } catch (e) {
      // Ignore
    }
    _audioContext = null;
  }
}

PlatformTonePlayer createPlatformPlayer() => WebTonePlayer();
