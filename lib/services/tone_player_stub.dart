/// Stub implementation - should not be used directly
abstract class PlatformTonePlayer {
  Future<void> playTone(double frequency, int durationMs);
  void dispose();
}

PlatformTonePlayer createPlatformPlayer() {
  throw UnsupportedError('Cannot create player without platform implementation');
}
