import 'package:flutter_beep/flutter_beep.dart';
import 'tone_player_stub.dart';

/// Mobile implementation using flutter_beep
class MobileTonePlayer implements PlatformTonePlayer {
  @override
  Future<void> playTone(double frequency, int durationMs) async {
    try {
      // flutter_beep doesn't support custom frequencies
      // Fall back to system beep
      await FlutterBeep.beep(false);
    } catch (e) {
      // Ignore errors - audio is best-effort
    }
  }

  @override
  void dispose() {
    // Nothing to dispose for mobile
  }
}

PlatformTonePlayer createPlatformPlayer() => MobileTonePlayer();
