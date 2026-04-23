import 'dart:convert';
import 'dart:js_interop';
import 'dart:developer' as developer;
import 'package:web/web.dart' as web;
import 'package:drift/drift.dart';
import 'package:drift/web.dart';
import '../platform_stub.dart';

/// Web implementation using Web Audio API and package:web.
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

/// Web implementation for downloading a file using package:web.
Future<void> saveFile({required String title, required String content}) async {
  final bytes = utf8.encode(content);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/xml'),
  );
  
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.setAttribute('download', '${title.replaceAll(' ', '_')}.musicxml');
  
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  
  web.URL.revokeObjectURL(url);
}

/// Opens a web-based database connection.
QueryExecutor openDatabaseConnection() {
  return WebDatabase('app_db', logStatements: false);
}
