import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../music_kit/models/song.dart';
import '../music_kit/models/music_note.dart';
import '../providers/color_scheme_provider.dart';
import '../services/audio_service.dart';
import '../music_kit/utils/music_constants.dart';
import '../widgets/sheet_music_widget.dart';
import '../music_kit/utils/note_resolver.dart';
import '../widgets/note_settings_sheet.dart';
import 'color_schemes_screen.dart';

/// Practice screen: displays sheet music and listens to the microphone.
/// When the microphone hears the current note, the app advances to the next.
class PracticeScreen extends StatefulWidget {
  final Song song;

  const PracticeScreen({super.key, required this.song});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with SingleTickerProviderStateMixin {
  final AudioService _audio = AudioService();

  int _currentNoteIndex = 0;
  bool _micActive = false;
  String _detectedNote = '';
  String? _statusMessage;
  StreamSubscription<String>? _noteSubscription;

  List<MusicNote> get _notes => widget.song.allNotes;

  MusicNote? get _currentNote =>
      _currentNoteIndex < _notes.length ? _notes[_currentNoteIndex] : null;

  @override
  void dispose() {
    _noteSubscription?.cancel();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_micActive) {
      await _stopMic();
    } else {
      await _startMic();
    }
  }

  Future<void> _startMic() async {
    setState(() => _statusMessage = 'Starting microphone...');
    final success = await _audio.startListening();
    if (!success) {
      setState(() {
        _statusMessage = 'Microphone permission denied. Please allow microphone access.';
        _micActive = false;
      });
      return;
    }
    setState(() {
      _micActive = true;
      _statusMessage = null;
    });
    _noteSubscription = _audio.noteStream.listen(_onNoteDetected);
  }

  Future<void> _stopMic() async {
    await _noteSubscription?.cancel();
    _noteSubscription = null;
    await _audio.stopListening();
    setState(() {
      _micActive = false;
      _detectedNote = '';
    });
  }

  void _onNoteDetected(String detectedNoteName) {
    if (!mounted) return;
    setState(() => _detectedNote = detectedNoteName);

    final current = _currentNote;
    if (current == null || detectedNoteName.isEmpty) return;

    // Apply tuning override: if this instrument has a mapping for the expected note,
    // listen for the mapped note instead.
    final activeScheme = context.read<ColorSchemeProvider>().activeScheme;
    final specificNote = current.letterName; // e.g. "C5"

    // Resolve target note name with enharmonic and octave-fallback support
    final targetNoteName = NoteResolver.resolveTargetNote(
      note: current,
      activeScheme: activeScheme,
    );

    // Check if the detected note matches the target note (within tolerance).
    final detectedMidi = MusicConstants.noteNameToMidi(detectedNoteName);
    final targetMidi = MusicConstants.noteNameToMidi(targetNoteName);

    if (detectedMidi < 0 || targetMidi < 0) return;

    if ((detectedMidi - targetMidi).abs() <= 1) {
      // Correct note heard – advance
      _advance();

      // Pause briefly to avoid re-triggering on the same note
      _noteSubscription?.pause();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _noteSubscription?.resume();
      });
    }
  }

  void _advance() {
    if (_currentNoteIndex < _notes.length - 1) {
      setState(() => _currentNoteIndex++);
    } else {
      _onSongComplete();
    }
  }

  void _previous() {
    if (_currentNoteIndex > 0) {
      setState(() => _currentNoteIndex--);
    }
  }

  void _onSongComplete() {
    setState(() => _statusMessage = '🎉 Song complete!');
    _stopMic();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🎉 Congratulations!'),
        content: const Text('You completed the song!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentNoteIndex = 0;
                _statusMessage = null;
              });
            },
            child: const Text('Play Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    NoteSettingsSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentNote;
    final progress = _notes.isEmpty
        ? 0.0
        : (_currentNoteIndex / _notes.length).clamp(0.0, 1.0);

    return Consumer<ColorSchemeProvider>(
      builder: (context, provider, _) => Scaffold(
        appBar: AppBar(
          title: Text('Practice: ${widget.song.title}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: _openSettings,
            ),
          ],
        ),
        body: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(value: progress, minHeight: 6),

            // Status / detected note
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: _micActive
                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    _micActive ? Icons.mic : Icons.mic_off,
                    color: _micActive ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage ??
                          (_micActive
                              ? (_detectedNote.isNotEmpty
                                  ? 'Hearing: $_detectedNote'
                                  : 'Listening…')
                              : 'Tap 🎙 to start practice'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    '${_currentNoteIndex + 1} / ${_notes.length}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Current note highlight
            if (current != null)
              _CurrentNoteCard(
                note: current,
                showSolfege: provider.showSolfege,
                noteIndex: _currentNoteIndex,
                total: _notes.length,
              ),

            const Divider(height: 1),

            // Sheet music (scrollable)
            Expanded(
              child: SheetMusicWidget(
                song: widget.song,
                activeNoteIndex: _currentNoteIndex,
                showSolfege: provider.showSolfege,
                showLetter: provider.showLetter,
                labelsBelow: provider.labelsBelow,
                coloredLabels: provider.coloredLabels,
                measuresPerRow: provider.measuresPerRow,
              ),
            ),

            // Navigation controls
            _NavigationBar(
              onPrevious: _currentNoteIndex > 0 ? _previous : null,
              onNext: _currentNoteIndex < _notes.length - 1 ? _advance : null,
              onMicToggle: _toggleMic,
              micActive: _micActive,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the current note in a large, prominent card.
class _CurrentNoteCard extends StatelessWidget {
  final MusicNote note;
  final bool showSolfege;
  final int noteIndex;
  final int total;

  const _CurrentNoteCard({
    required this.note,
    required this.showSolfege,
    required this.noteIndex,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Text(
            'Play now:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            showSolfege ? note.solfegeName : note.letterName,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${MusicConstants.stepToSolfege[note.step] ?? note.step})',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onMicToggle;
  final bool micActive;

  const _NavigationBar({
    this.onPrevious,
    this.onNext,
    this.onMicToggle,
    required this.micActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous),
            onPressed: onPrevious,
            tooltip: 'Previous note',
          ),
          FloatingActionButton(
            onPressed: onMicToggle,
            backgroundColor: micActive ? Colors.green : null,
            mini: false,
            child: Icon(micActive ? Icons.mic : Icons.mic_off),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: onNext,
            tooltip: 'Next note',
          ),
        ],
      ),
    );
  }
}
