import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// The canonical 12 chromatic note keys used as keys in a color scheme.
const List<String> kNoteKeys = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
];

/// Flat-to-sharp equivalents for enharmonic lookup.
const Map<String, String> kFlatToSharp = {
  'Db': 'C#',
  'Eb': 'D#',
  'Gb': 'F#',
  'Ab': 'G#',
  'Bb': 'A#',
};

/// A named mapping from each of the 12 chromatic notes to a display [Color].
class InstrumentColorScheme {
  final String id;
  final String name;
  final String? icon;

  /// Whether this is a built-in (non-deletable) scheme.
  final bool isBuiltIn;

  /// Whether this was imported from the library (prevents sharing/re-submitting).
  final bool isImported;

  /// Per-note colors keyed by the values in [kNoteKeys].
  final Map<String, Color> colors;

  /// Optional octave-specific overrides, e.g. `{'C5': Color(0xFFE91E63)}`.
  final Map<String, Color> octaveOverrides;

  const InstrumentColorScheme({
    required this.id,
    required this.name,
    this.icon,
    required this.colors,
    this.isBuiltIn = false,
    this.isImported = false,
    this.octaveOverrides = const {},
  });

  /// Returns the color for a note given its [step] (C–B), [alter] (-1/0/+1),
  /// and optional [octave].
  Color colorForNote(
    String step,
    double alter, {
    int? octave,
    BuildContext? context,
    Brightness? brightness,
  }) {
    Color? baseColor;

    if (octave != null && octaveOverrides.isNotEmpty) {
      final key = alter == 1
          ? '$step#$octave'
          : alter == -1
              ? '${step}b$octave'
              : '$step$octave';
      if (octaveOverrides.containsKey(key)) baseColor = octaveOverrides[key]!;

      if (baseColor == null && alter == -1) {
        final enharmonic = kFlatToSharp['${step}b'];
        if (enharmonic != null &&
            octaveOverrides.containsKey('$enharmonic$octave')) {
          baseColor = octaveOverrides['$enharmonic$octave']!;
        }
      }
    }

    if (baseColor == null) {
      if (alter == 1) {
        baseColor = colors['$step#'] ?? colors[step];
      } else if (alter == -1) {
        final enharmonic = kFlatToSharp['${step}b'];
        baseColor = colors[enharmonic] ?? colors[step];
      } else {
        baseColor = colors[step];
      }
    }

    final bool isStandard = baseColor == null ||
        baseColor.value == 0xFF000000 ||
        baseColor.value == 0xFFFFFFFF;

    if (isStandard) {
      final isDark = brightness == Brightness.dark ||
          (context != null && Theme.of(context).brightness == Brightness.dark);
      return isDark ? Colors.white : Colors.black;
    }

    return baseColor;
  }

  InstrumentColorScheme copyWith({
    String? id,
    String? name,
    String? icon,
    Map<String, Color>? colors,
    Map<String, Color>? octaveOverrides,
    bool? isBuiltIn,
    bool? isImported,
  }) {
    return InstrumentColorScheme(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colors: colors ?? Map.from(this.colors),
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isImported: isImported ?? this.isImported,
      octaveOverrides: octaveOverrides ?? Map.from(this.octaveOverrides),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (icon != null) 'icon': icon,
        'isBuiltIn': isBuiltIn,
        if (isImported) 'isImported': isImported,
        'colors': colors.map((k, v) => MapEntry(k, v.toARGB32())),
        if (octaveOverrides.isNotEmpty)
          'octaveOverrides':
              octaveOverrides.map((k, v) => MapEntry(k, v.toARGB32())),
      };

  factory InstrumentColorScheme.fromJson(Map<String, dynamic> json, {String? fallbackId}) {
    final rawColors = json['colors'] as Map<String, dynamic>? ?? {};
    final rawOverrides =
        json['octaveOverrides'] as Map<String, dynamic>? ?? {};
    return InstrumentColorScheme(
      id: (json['id'] as String?) ?? fallbackId ?? const Uuid().v7(),
      name: json['name'] as String,
      icon: json['icon'] as String?,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      isImported: json['isImported'] as bool? ?? false,
      colors: rawColors.map((k, v) => MapEntry(k, Color(v as int))),
      octaveOverrides:
          rawOverrides.map((k, v) => MapEntry(k, Color(v as int))),
    );
  }

  static const InstrumentColorScheme black = InstrumentColorScheme(
    id: 'builtin_black',
    name: 'Standard',
    isBuiltIn: true,
    colors: {},
  );
}
