import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../music_kit/models/song.dart';
import '../providers/color_scheme_provider.dart';
import '../services/tone_player.dart';
import '../music_kit/utils/music_pdf_service.dart';
import '../widgets/sheet_music_widget.dart';
import 'practice_screen.dart';
import 'color_schemes_screen.dart';

/// Displays the full sheet music for a song with color-coded notes.
class SheetMusicScreen extends StatefulWidget {
  final Song song;

  const SheetMusicScreen({super.key, required this.song});

  @override
  State<SheetMusicScreen> createState() => _SheetMusicScreenState();
}

class _SheetMusicScreenState extends State<SheetMusicScreen> {
  // Playback state
  bool _isPlaying = false;
  int _activeNoteIndex = -1;
  Timer? _playbackTimer;
  int _currentNoteIndexInPlayback = 0;
  
  // Tempo in BPM (beats per minute)
  double _tempo = 120.0;
  
  // Audio player
  final TonePlayer _tonePlayer = TonePlayer();
  
  @override
  void dispose() {
    _stopPlayback(isDisposing: true);
    _tonePlayer.dispose();
    super.dispose();
  }
  
  void _toggleMetronome() {
    if (_tonePlayer.isMetronomeRunning) {
      _tonePlayer.stopMetronome();
    } else {
      final provider = context.read<ColorSchemeProvider>();
      _tonePlayer.startMetronome(_tempo, sound: provider.metronomeSound);
    }
    if (mounted) {
      setState(() {});
    }
  }
  
  void _togglePlayback() {
    if (_isPlaying) {
      _pausePlayback();
    } else {
      _startPlayback();
    }
  }
  
  void _startPlayback() {
    final notes = widget.song.allNotes;
    if (notes.isEmpty) return;
    
    if (mounted) {
      setState(() {
        _isPlaying = true;
        if (_activeNoteIndex == -1 || _activeNoteIndex >= notes.length - 1) {
          _activeNoteIndex = 0;
          _currentNoteIndexInPlayback = 0;
        }
      });
    }
    
    _scheduleNextNote();
  }
  
  void _pausePlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }
  
  void _stopPlayback({bool isDisposing = false}) {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _isPlaying = false;
    _activeNoteIndex = -1;
    _currentNoteIndexInPlayback = 0;
    if (isDisposing) return;
    if (mounted) {
      setState(() {});
    }
  }
  
  void _scheduleNextNote() {
    final notes = widget.song.allNotes;
    if (_currentNoteIndexInPlayback >= notes.length) {
      // Song finished
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _activeNoteIndex = -1;
          _currentNoteIndexInPlayback = 0;
        });
        
        // Show completion message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎵 Song finished!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    final note = notes[_currentNoteIndexInPlayback];
    if (mounted) {
      setState(() {
        _activeNoteIndex = _currentNoteIndexInPlayback;
      });
    }
    
    // Play the note sound
    _tonePlayer.playNote(note.frequency);
    
    // Calculate duration in milliseconds
    // Assuming quarter note = 1.0 duration, and tempo is in BPM
    final quarterNoteDuration = 60000.0 / _tempo; // milliseconds per quarter note
    final noteDurationMs = (note.duration * quarterNoteDuration).toInt();
    
    _playbackTimer = Timer(Duration(milliseconds: noteDurationMs), () {
      _currentNoteIndexInPlayback++;
      if (_isPlaying && mounted) {
        _scheduleNextNote();
      }
    });
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            ),
            child: Consumer<ColorSchemeProvider>(
              builder: (context, provider, _) => SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Settings',
                      style: Theme.of(sheetCtx).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const Divider(height: 24),

                  // Letters toggle
                  SwitchListTile(
                    title: const Text('Letters'),
                    subtitle: const Text('Show letter names on notes (A, B, C…)'),
                    value: provider.showLetter,
                    onChanged: (v) => provider.setShowLetter(v),
                  ),

                  // Solfège toggle
                  SwitchListTile(
                    title: const Text('Solfège'),
                    subtitle:
                        const Text('Show solfège names on notes (Do, Re, Mi…)'),
                    value: provider.showSolfege,
                    onChanged: (v) => provider.setShowSolfege(v),
                  ),

                  // Labels below toggle
                  SwitchListTile(
                    title: const Text('Labels Below Notes'),
                    subtitle:
                        const Text('Show labels under notes instead of inside'),
                    value: provider.labelsBelow,
                    onChanged: (v) => provider.setLabelsBelow(v),
                  ),

                  // Colored labels toggle
                  SwitchListTile(
                    title: const Text('Colored Labels'),
                    subtitle:
                        const Text('Match label color to note color'),
                    value: provider.coloredLabels,
                    onChanged: (v) => provider.setColoredLabels(v),
                  ),

                  const Divider(height: 24),

                  // Tempo/Speed control
                  ListTile(
                    title: const Text('Tempo'),
                    subtitle: Text('${_tempo.round()} BPM'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Slider(
                      value: _tempo,
                      min: 40,
                      max: 240,
                      divisions: 40,
                      label: '${_tempo.round()} BPM',
                      onChanged: (v) {
                        setSheetState(() => _tempo = v);
                        setState(() => _tempo = v);
                        // Restart metronome if running
                        if (_tonePlayer.isMetronomeRunning) {
                          final provider = context.read<ColorSchemeProvider>();
                          _tonePlayer.startMetronome(_tempo, sound: provider.metronomeSound);
                        }
                      },
                    ),
                  ),

                  const Divider(height: 24),

                  // Metronome Sound
                  ListTile(
                    title: const Text('Metronome Sound'),
                    trailing: DropdownButton<String>(
                      value: provider.metronomeSound,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: 'tick',
                          child: Text('Tick'),
                        ),
                        DropdownMenuItem(
                          value: 'beep',
                          child: Text('Beep'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          provider.setMetronomeSound(v);
                          // Restart metronome if running to apply change
                          if (_tonePlayer.isMetronomeRunning) {
                            _tonePlayer.startMetronome(_tempo, sound: v);
                          }
                        }
                      },
                    ),
                  ),

                  const Divider(height: 24),
                  ListTile(
                    title: const Text('Measures per row'),
                    trailing: DropdownButton<int>(
                      value: provider.measuresPerRow,
                      underline: const SizedBox.shrink(),
                      items: [2, 3, 4, 6]
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text('$v'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          provider.setMeasuresPerRow(v);
                        }
                      },
                    ),
                  ),

                  const Divider(height: 24),

                  // Theme
                  ListTile(
                    title: const Text('Theme'),
                    trailing: DropdownButton<ThemeMode>(
                      value: provider.themeMode,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('System'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('Light'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('Dark'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          provider.setThemeMode(v);
                        }
                      },
                    ),
                  ),

                  const Divider(height: 24),

                  // Print
                  ListTile(
                    leading: const Icon(Icons.print),
                    title: const Text('Print'),
                    subtitle: const Text('Generate a PDF of this song'),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _printSong();
                    },
                  ),
                ],
              ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _printSong() async {
    final provider = context.read<ColorSchemeProvider>();
    await MusicPdfService.printSong(
      song: widget.song,
      colorScheme: provider.activeScheme,
      showSolfege: provider.showSolfege,
      showLetter: provider.showLetter,
      labelsBelow: provider.labelsBelow,
      coloredLabels: provider.coloredLabels,
      measuresPerRow: provider.measuresPerRow,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ColorSchemeProvider>(
      builder: (context, provider, _) => CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyP, control: true):
              _printSong,
          const SingleActivator(LogicalKeyboardKey.keyP, meta: true): _printSong,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.song.title),
              actions: [
                IconButton(
                  icon: const Icon(Icons.piano_outlined),
                  tooltip: 'Instruments',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ColorSchemesScreen()),
                  ),
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  tooltip: _isPlaying ? 'Pause' : 'Play',
                  onPressed: _togglePlayback,
                ),
                IconButton(
                  icon: Icon(
                    _tonePlayer.isMetronomeRunning
                      ? Icons.stop
                      : Icons.av_timer,
                  ),
                  tooltip: _tonePlayer.isMetronomeRunning
                    ? 'Stop Metronome'
                    : 'Start Metronome',
                  onPressed: _toggleMetronome,
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Settings',
                  onPressed: _openSettings,
                ),
              ],
            ),
            body: SheetMusicWidget(
              song: widget.song,
              showSolfege: provider.showSolfege,
              showLetter: provider.showLetter,
              labelsBelow: provider.labelsBelow,
              coloredLabels: provider.coloredLabels,
              activeNoteIndex: _activeNoteIndex,
              measuresPerRow: provider.measuresPerRow,
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PracticeScreen(song: widget.song),
                ),
              ),
              icon: const Icon(Icons.mic),
              label: const Text('Practice'),
            ),
          ),
        ),
      ),
    );
  }
}
