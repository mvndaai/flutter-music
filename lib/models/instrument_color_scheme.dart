import 'package:flutter/material.dart';

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
///
/// Optionally, [octaveOverrides] can hold colors keyed by note+octave strings
/// such as `'C5'` or `'C#4'`, which take precedence over [colors] when an
/// octave is known.  This lets the same pitch class (e.g. C) appear in
/// different colors on different octaves (e.g. low-C purple, high-C pink).
class InstrumentColorScheme {
  final String id;
  final String name;
  final String? icon;

  /// Whether this is a built-in (non-deletable) scheme.
  final bool isBuiltIn;

  /// Per-note colors keyed by the values in [kNoteKeys].
  final Map<String, Color> colors;

  /// Optional octave-specific overrides, e.g. `{'C5': Color(0xFFE91E63)}`.
  /// Keys are `step + octave` (or `step# + octave` for sharps).
  final Map<String, Color> octaveOverrides;

  const InstrumentColorScheme({
    required this.id,
    required this.name,
    this.icon,
    required this.colors,
    this.isBuiltIn = false,
    this.octaveOverrides = const {},
  });

  /// Returns the color for a note given its [step] (C–B), [alter] (-1/0/+1),
  /// and optional [octave].  Octave-specific overrides are checked first.
  ///
  /// Either [context] or [brightness] must be provided for theme-aware fallback.
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

      // Also try the enharmonic sharp form for flat notes.
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

    // Dynamic standard: If it's pure black, pure white, or not set, match the theme.
    // We check the raw ARGB value to catch both Colors.black and Color(0xFF000000).
    final bool isStandard = baseColor == null ||
        baseColor.value == 0xFF000000 ||
        baseColor.value == 0xFFFFFFFF;

    if (isStandard) {
      final isDark = brightness == Brightness.dark ||
          (context != null && Theme.of(context).brightness == Brightness.dark);
      // Return high-contrast white/black for the "Standard" look.
      return isDark ? Colors.white : Colors.black;
    }

    return baseColor;
  }

  /// Creates a copy with optionally updated fields.
  InstrumentColorScheme copyWith({
    String? name,
    String? icon,
    Map<String, Color>? colors,
    Map<String, Color>? octaveOverrides,
  }) {
    return InstrumentColorScheme(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colors: colors ?? Map.from(this.colors),
      isBuiltIn: isBuiltIn,
      octaveOverrides: octaveOverrides ?? Map.from(this.octaveOverrides),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'colors': colors.map((k, v) => MapEntry(k, v.toARGB32())),
        if (octaveOverrides.isNotEmpty)
          'octaveOverrides':
              octaveOverrides.map((k, v) => MapEntry(k, v.toARGB32())),
      };

  factory InstrumentColorScheme.fromJson(Map<String, dynamic> json) {
    final raw = json['colors'] as Map<String, dynamic>;
    final rawOverrides =
        json['octaveOverrides'] as Map<String, dynamic>? ?? {};
    return InstrumentColorScheme(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      colors: raw.map((k, v) => MapEntry(k, Color(v as int))),
      octaveOverrides:
          rawOverrides.map((k, v) => MapEntry(k, Color(v as int))),
    );
  }

  // ── Built-in schemes ──────────────────────────────────────────────────────

  /// Standard scheme that follows the theme (black in light mode, white in dark).
  static const InstrumentColorScheme black = InstrumentColorScheme(
    id: 'builtin_black',
    name: 'Standard',
    isBuiltIn: true,
    colors: {}, // Empty map triggers theme-aware fallback in colorForNote
  );

  /// Xylophone with the traditional 8-bar diatonic palette:
  /// C=purple, D=blue, E=green, F=lime green, G=yellow, A=orange, B=red, C(high)=pink.
  static const InstrumentColorScheme ltXylophone1980s = InstrumentColorScheme(
    id: 'builtin_xylophone_little_tykes_1980s',
    name: 'Xylophone: Little Tikes 1980s ',
    icon: 'https://img.icons8.com/fluency/96/xylophone.png',
    isBuiltIn: true,
    colors: {
      'C': Color(0xFF8E24AA),  // purple
      'D': Color(0xFF1E88E5),  // blue
      'E': Color(0xFF43A047),  // green
      'F': Color(0xFF8BC34A),  // lime green
      'G': Color(0xFFFDD835),  // yellow
      'A': Color(0xFFF57C00),  // orange
      'B': Color(0xFFE53935),  // red
    },
    octaveOverrides: {
      'C5': Color(0xFFE91E63), // pink (high C)
    },
  );

  /// Smooth rainbow gradient across all 12 chromatic steps.
  static const InstrumentColorScheme rainbow = InstrumentColorScheme(
    id: 'builtin_rainbow',
    name: 'Rainbow',
    icon: 'https://img.icons8.com/color/96/rainbow.png',
    isBuiltIn: true,
    colors: {
      'C': Color(0xFFFF1744),
      'C#': Color(0xFFFF6D00),
      'D': Color(0xFFFFAB00),
      'D#': Color(0xFFFFEA00),
      'E': Color(0xFF76FF03),
      'F': Color(0xFF00E676),
      'F#': Color(0xFF1DE9B6),
      'G': Color(0xFF00B0FF),
      'G#': Color(0xFF2979FF),
      'A': Color(0xFF651FFF),
      'A#': Color(0xFFD500F9),
      'B': Color(0xFFFF1744),
    },
  );


  static const List<InstrumentColorScheme> builtIns = [
    black,
    rainbow,
    ltXylophone1980s,
  ];
}
