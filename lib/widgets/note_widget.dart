import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/instrument_provider.dart';
import '../music_kit/widgets/note_renderer.dart';
import '../music_kit/models/music_note.dart';

/// App-specific wrapper around [NoteRenderer] that connects it to [InstrumentProvider].
class NoteWidget extends StatelessWidget {
  final MusicNote note;
  final bool isActive;
  final bool isPast;
  final double size;
  final bool showSolfege;
  final bool showLetter;

  const NoteWidget({
    super.key,
    required this.note,
    this.isActive = false,
    this.isPast = false,
    this.size = 52,
    this.showSolfege = false,
    this.showLetter = true,
  });

  @override
  Widget build(BuildContext context) {
    final instrumentProvider = context.watch<InstrumentProvider>();
    
    return NoteRenderer(
      note: note,
      instrument: instrumentProvider.activeScheme,
      showNoteLabels: colorProvider.showNoteLabels,
      isActive: isActive,
      isPast: isPast,
      size: size,
      showSolfege: showSolfege,
      showLetter: showLetter,
    );
  }
}
