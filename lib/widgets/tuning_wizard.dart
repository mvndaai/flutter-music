import 'dart:async';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';

/// Result returned by [showTuningWizard].
class TuningResult {
  /// Map of intended note name to actually heard note name.
  final Map<String, String> tuningOverrides;

  const TuningResult({required this.tuningOverrides});
}

/// Opens the tuning wizard as a full-screen dialog.
Future<TuningResult?> showTuningWizard(
  BuildContext context, {
  required List<String> notesToTune,
  required Color Function(String noteName) colorProvider,
  Map<String, String> initialOverrides = const {},
}) {
  if (notesToTune.isEmpty) return Future.value(null);
  
  return Navigator.push<TuningResult>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _TuningWizardScreen(
        notesToTune: notesToTune,
        initialOverrides: initialOverrides,
        colorProvider: colorProvider,
      ),
    ),
  );
}

class _TuningWizardScreen extends StatefulWidget {
  final List<String> notesToTune;
  final Map<String, String> initialOverrides;
  final Color Function(String noteName) colorProvider;

  const _TuningWizardScreen({
    required this.notesToTune,
    required this.initialOverrides,
    required this.colorProvider,
  });

  @override
  State<_TuningWizardScreen> createState() => _TuningWizardScreenState();
}

class _TuningWizardScreenState extends State<_TuningWizardScreen> {
  int _currentIndex = 0;
  final Map<String, String> _overrides = {};
  
  final AudioService _audio = AudioService();
  StreamSubscription<String>? _noteSub;
  bool _micActive = false;
  String _liveNote = '';

  String get _currentTarget => widget.notesToTune[_currentIndex];

  @override
  void initState() {
    super.initState();
    _overrides.addAll(widget.initialOverrides);
  }

  @override
  void dispose() {
    _stopMic();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _startMic() async {
    final ok = await _audio.startListening();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied.')),
        );
      }
      return;
    }
    setState(() {
      _micActive = true;
      _liveNote = '';
    });
    _noteSub = _audio.noteStream.listen((note) {
      if (mounted && note.isNotEmpty) {
        setState(() => _liveNote = note);
      }
    });
  }

  Future<void> _stopMic() async {
    await _noteSub?.cancel();
    _noteSub = null;
    await _audio.stopListening();
    if (mounted) setState(() => _micActive = false);
  }

  void _confirmNote() {
    if (_liveNote.isEmpty) return;
    
    setState(() {
      _overrides[_currentTarget] = _liveNote;
      if (_currentIndex < widget.notesToTune.length - 1) {
        _currentIndex++;
        _liveNote = '';
      } else {
        _done();
      }
    });
  }

  void _skip() {
    setState(() {
      if (_currentIndex < widget.notesToTune.length - 1) {
        _currentIndex++;
        _liveNote = '';
      } else {
        _done();
      }
    });
  }

  void _done() {
    _stopMic();
    Navigator.pop(context, TuningResult(tuningOverrides: _overrides));
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentIndex + 1) / widget.notesToTune.length;
    final targetColor = widget.colorProvider(_currentTarget);

    return Scaffold(
      key: ValueKey(_currentTarget),
      appBar: AppBar(
        title: const Text('Tune Instrument'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: progress),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Step ${_currentIndex + 1} of ${widget.notesToTune.length}',
                    style: Theme.of(context).textTheme.labelLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please play:',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Mic Button
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _micActive ? _stopMic : _startMic,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _micActive ? Colors.green : Theme.of(context).colorScheme.primary,
                            ),
                            child: Icon(
                              _micActive ? Icons.mic : Icons.mic_off,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _micActive ? 'Listening...' : 'Tap to start listening',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: targetColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: targetColor.withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _currentTarget,
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: targetColor.computeLuminance() > 0.35
                                        ? Colors.black87
                                        : Colors.white,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Fixed height container to prevent layout shifts
                        SizedBox(
                          height: 24,
                          child: _overrides.containsKey(_currentTarget)
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Currently tuned to: ${_overrides[_currentTarget]}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  if (_liveNote.isNotEmpty) ...[
                    Text(
                      'Detected:',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    Text(
                      _liveNote,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _confirmNote,
                      child: Text('Map $_currentTarget to $_liveNote'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _currentIndex > 0 
                      ? () => setState(() => _currentIndex--) 
                      : null,
                  child: const Text('Previous'),
                ),
                TextButton(
                  onPressed: _skip,
                  child: Text(_overrides.containsKey(_currentTarget) ? 'Next' : 'Skip'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
