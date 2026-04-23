import '../models/music_note.dart';
import '../models/instrument_color_scheme.dart';
import 'music_constants.dart';

/// Handles resolving musical notes considering enharmonics, octaves, and instrument-specific tunings.
class NoteResolver {
  NoteResolver._();

  /// Resolves the target note name that the app should listen for or display,
  /// accounting for instrument-specific [activeScheme] tuning overrides.
  static String resolveTargetNote({
    required MusicNote note,
    required InstrumentColorScheme activeScheme,
  }) {
    final specificNote = note.letterName; // e.g. "C5"

    // 1. Exact match (e.g. "C5")
    if (activeScheme.tuningOverrides.containsKey(specificNote)) {
      return activeScheme.tuningOverrides[specificNote]!;
    }

    // 2. Exact match on base step (e.g. "C")
    if (activeScheme.tuningOverrides.containsKey(note.step)) {
      return activeScheme.tuningOverrides[note.step]!;
    }

    // 3. Enharmonic match (e.g. Db -> C#)
    final enharmonicStep = note.alter == 1
        ? '${note.step}#'
        : (note.alter == -1 ? '${note.step}b' : note.step);

    final mappingKeys = [
      enharmonicStep,
      _toSharp(enharmonicStep),
      '$enharmonicStep${note.octave}',
      _toSharp('$enharmonicStep${note.octave}'),
    ];

    for (final key in mappingKeys) {
      if (activeScheme.tuningOverrides.containsKey(key)) {
        return activeScheme.tuningOverrides[key]!;
      }
    }

    // 4. Fallback to octave 4 mapping if available (common for simple instruments)
    final base4 = '${note.step}4';
    final enhBase4 = _toSharp(base4);

    final mapped4 = activeScheme.tuningOverrides[base4] ??
        activeScheme.tuningOverrides[enhBase4];
        
    if (mapped4 != null) {
      // Apply the same interval shift to the current note's octave
      final originalMidi4 = MusicConstants.noteNameToMidi(enhBase4);
      final mappedMidi4 = MusicConstants.noteNameToMidi(mapped4);
      if (originalMidi4 > 0 && mappedMidi4 > 0) {
        final shift = mappedMidi4 - originalMidi4;
        return MusicConstants.midiToNoteName(note.midiNumber + shift);
      }
    }

    return specificNote;
  }

  static String _toSharp(String note) {
    return note
        .replaceAll('Db', 'C#')
        .replaceAll('Eb', 'D#')
        .replaceAll('Gb', 'F#')
        .replaceAll('Ab', 'G#')
        .replaceAll('Bb', 'A#');
  }
}
