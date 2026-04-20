import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/measure.dart';
import '../models/music_note.dart';
import '../models/song.dart';
import '../providers/color_scheme_provider.dart';
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
  bool _showLetter = true;
  bool _showSolfege = false;
  int _measuresPerRow = 4;

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final provider = context.watch<ColorSchemeProvider>();
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            ),
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
                  value: _showLetter,
                  onChanged: (v) {
                    setState(() => _showLetter = v);
                    setSheetState(() {});
                    context
                        .read<ColorSchemeProvider>()
                        .setShowNoteLabels(v || _showSolfege);
                  },
                ),

                // Solfège toggle
                SwitchListTile(
                  title: const Text('Solfège'),
                  subtitle:
                      const Text('Show solfège names on notes (Do, Re, Mi…)'),
                  value: _showSolfege,
                  onChanged: (v) {
                    setState(() => _showSolfege = v);
                    setSheetState(() {});
                    context
                        .read<ColorSchemeProvider>()
                        .setShowNoteLabels(_showLetter || v);
                  },
                ),

                const Divider(height: 24),

                // Measures per row
                ListTile(
                  title: const Text('Measures per row'),
                  trailing: DropdownButton<int>(
                    value: _measuresPerRow,
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
                        setState(() => _measuresPerRow = v);
                        setSheetState(() {});
                      }
                    },
                  ),
                ),

                const Divider(height: 24),

                // Instrument
                ListTile(
                  title: const Text('Instrument'),
                  subtitle: Text(provider.activeScheme.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ColorSchemesScreen(),
                      ),
                    );
                  },
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
          );
        },
      ),
    );
  }

  Future<void> _printSong() async {
    final provider = context.read<ColorSchemeProvider>();
    final song = widget.song;

    await Printing.layoutPdf(
      name: song.title,
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document();

        if (song.measures.isEmpty) {
          doc.addPage(
            pw.Page(
              pageFormat: format,
              build: (_) => pw.Center(
                child: pw.Text('No notes found in this song.'),
              ),
            ),
          );
          return doc.save();
        }

        // Staff notation constants
        const double lineSpacing = 10.0;
        const double staffHeight = lineSpacing * 4; // 5 lines = 4 spaces
        const double topMargin = lineSpacing * 4;
        const double bottomMargin = lineSpacing * 4;
        const double rowHeight = topMargin + staffHeight + bottomMargin;
        const double clefWidth = 35.0;
        const double timeSigWidth = 20.0;
        const double headerHeight = 80;

        final pageWidth = format.availableWidth;
        final pageHeight = format.availableHeight;

        // Split measures into rows
        final List<List<Measure>> rows = [];
        for (int i = 0; i < song.measures.length; i += _measuresPerRow) {
          rows.add(
            song.measures.sublist(
              i,
              (i + _measuresPerRow).clamp(0, song.measures.length),
            ),
          );
        }

        final rowsPerPage =
            ((pageHeight - headerHeight) / rowHeight).floor().clamp(1, rows.length);

        for (int pageStart = 0;
            pageStart < rows.length;
            pageStart += rowsPerPage) {
          final pageRows = rows.sublist(
            pageStart,
            (pageStart + rowsPerPage).clamp(0, rows.length),
          );

          doc.addPage(
            pw.Page(
              pageFormat: format,
              build: (pw.Context ctx) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (pageStart == 0) ...[
                      pw.Text(
                        song.title,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (song.composer.isNotEmpty)
                        pw.Text(
                          song.composer,
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      pw.SizedBox(height: 12),
                      pw.Divider(),
                      pw.SizedBox(height: 8),
                    ],
                    ...pageRows.asMap().entries.map((entry) {
                      final rowIndex = pageStart + entry.key;
                      final rowMeasures = entry.value;
                      final isFirstRow = rowIndex == 0;
                      final isLastRow = rowIndex == rows.length - 1;

                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 16),
                        child: _buildStaffRow(
                          rowMeasures,
                          provider,
                          pageWidth,
                          lineSpacing,
                          topMargin,
                          staffHeight,
                          clefWidth,
                          timeSigWidth,
                          isFirstRow,
                          isLastRow,
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          );
        }

        return doc.save();
      },
    );
  }

  // Build a staff row with proper notation
  pw.Widget _buildStaffRow(
    List<Measure> measures,
    ColorSchemeProvider provider,
    double width,
    double ls,
    double topMargin,
    double staffHeight,
    double clefWidth,
    double timeSigWidth,
    bool isFirstRow,
    bool isLastRow,
  ) {
    return pw.SizedBox(
      height: topMargin + staffHeight + topMargin,
      width: width,
      child: pw.Stack(
        children: [
          // Staff lines (5 horizontal lines)
          ...List.generate(5, (i) {
            return pw.Positioned(
              left: 0,
              right: 0,
              top: topMargin + i * ls,
              child: pw.Container(
                height: 0.5,
                color: PdfColors.grey700,
              ),
            );
          }),

          // Treble clef
          pw.Positioned(
            left: 2,
            top: topMargin + staffHeight / 2 - 20,
            child: pw.Text(
              '𝄞',
              style: pw.TextStyle(
                fontSize: 40,
                color: PdfColors.grey800,
              ),
            ),
          ),

          // Time signature (first row only)
          if (isFirstRow && measures.isNotEmpty) ...[
            pw.Positioned(
              left: clefWidth + 2,
              top: topMargin + ls * 0.2,
              child: pw.Text(
                '${measures.first.beats}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
            ),
            pw.Positioned(
              left: clefWidth + 2,
              top: topMargin + staffHeight / 2 + ls * 0.2,
              child: pw.Text(
                '${measures.first.beatType}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
            ),
          ],

          // Notes and bar lines
          ..._buildMeasuresContent(
            measures,
            provider,
            width,
            ls,
            topMargin,
            staffHeight,
            clefWidth,
            timeSigWidth,
            isFirstRow,
            isLastRow,
          ),
        ],
      ),
    );
  }

  // Build notes and bar lines for all measures in a row
  List<pw.Widget> _buildMeasuresContent(
    List<Measure> measures,
    ColorSchemeProvider provider,
    double width,
    double ls,
    double topMargin,
    double staffHeight,
    double clefWidth,
    double timeSigWidth,
    bool isFirstRow,
    bool isLastRow,
  ) {
    final widgets = <pw.Widget>[];
    double x = clefWidth + (isFirstRow ? timeSigWidth : 0);

    // Calculate spacing
    final slotCounts = measures
        .map((m) => m.notes.where((n) => !n.isChordContinuation).length)
        .map((count) => count.clamp(1, 999))
        .toList();
    final totalSlots = slotCounts.fold<int>(0, (sum, count) => sum + count);
    final availWidth = width - x;
    final slotWidth = totalSlots > 0 ? (availWidth / totalSlots) : 24.0;

    for (int mi = 0; mi < measures.length; mi++) {
      final measure = measures[mi];
      final measureSlots = slotCounts[mi];
      final measureWidth = measureSlots * slotWidth;

      // Measure number
      widgets.add(
        pw.Positioned(
          left: x + 2,
          top: 2,
          child: pw.Text(
            '${measure.number}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey500,
            ),
          ),
        ),
      );

      // Notes in measure
      final displayNotes = measure.notes.where((n) => !n.isChordContinuation).toList();
      for (int ni = 0; ni < displayNotes.length; ni++) {
        final note = displayNotes[ni];
        if (!note.isRest) {
          final noteX = x + (ni + 0.5) * slotWidth;
          widgets.addAll(_buildNote(
            note,
            noteX,
            topMargin,
            staffHeight,
            ls,
            provider,
          ));
        }
      }

      x += measureWidth;

      // Bar line
      final isLastMeasure = mi == measures.length - 1;
      if (isLastMeasure && isLastRow) {
        // Double bar line at end
        widgets.addAll([
          pw.Positioned(
            left: x - 3,
            top: topMargin,
            child: pw.Container(
              width: 2,
              height: staffHeight,
              color: PdfColors.grey700,
            ),
          ),
          pw.Positioned(
            left: x,
            top: topMargin,
            child: pw.Container(
              width: 1,
              height: staffHeight,
              color: PdfColors.grey700,
            ),
          ),
        ]);
      } else {
        widgets.add(
          pw.Positioned(
            left: x,
            top: topMargin,
            child: pw.Container(
              width: 1,
              height: staffHeight,
              color: PdfColors.grey700,
            ),
          ),
        );
      }
    }

    return widgets;
  }

  // Build a single note with staff notation
  List<pw.Widget> _buildNote(
    MusicNote note,
    double x,
    double topMargin,
    double staffHeight,
    double ls,
    ColorSchemeProvider provider,
  ) {
    final widgets = <pw.Widget>[];

    // Calculate staff position
    const diatonic = {'C': 0, 'D': 1, 'E': 2, 'F': 3, 'G': 4, 'A': 5, 'B': 6};
    final pos = note.octave * 7 + (diatonic[note.step] ?? 0) - 30;
    final y = topMargin + staffHeight - pos * ls / 2;

    final color = provider.colorForNote(note.step, note.alter, octave: note.octave);
    final pdfColor = PdfColor(color.r, color.g, color.b);

    // Ledger lines (below staff)
    if (pos < 0) {
      final lowest = pos.isEven ? pos : pos + 1;
      for (int lp = -2; lp >= lowest; lp -= 2) {
        final ly = topMargin + staffHeight - lp * ls / 2;
        widgets.add(
          pw.Positioned(
            left: x - 10,
            top: ly - 0.3,
            child: pw.Container(
              width: 20,
              height: 0.6,
              color: PdfColors.grey700,
            ),
          ),
        );
      }
    }

    // Ledger lines (above staff)
    if (pos > 8) {
      final highest = pos.isEven ? pos : pos - 1;
      for (int lp = 10; lp <= highest; lp += 2) {
        final ly = topMargin + staffHeight - lp * ls / 2;
        widgets.add(
          pw.Positioned(
            left: x - 10,
            top: ly - 0.3,
            child: pw.Container(
              width: 20,
              height: 0.6,
              color: PdfColors.grey700,
            ),
          ),
        );
      }
    }

    // Accidental (sharp or flat)
    if (note.alter != 0) {
      widgets.add(
        pw.Positioned(
          left: x - 18,
          top: y - 8,
          child: pw.Text(
            note.alter > 0 ? '♯' : '♭',
            style: const pw.TextStyle(
              fontSize: 16,
              color: PdfColors.black,
            ),
          ),
        ),
      );
    }

    // Note head
    final noteHeadWidth = 8.0;
    final noteHeadHeight = 5.0;
    final filled = note.type != 'whole' && note.type != 'half';

    widgets.add(
      pw.Positioned(
        left: x - noteHeadWidth / 2,
        top: y - noteHeadHeight / 2,
        child: pw.Transform.rotate(
          angle: -0.20,
          child: pw.Container(
            width: noteHeadWidth,
            height: noteHeadHeight,
            decoration: pw.BoxDecoration(
              color: filled ? pdfColor : null,
              border: filled ? null : pw.Border.all(
                color: pdfColor,
                width: 1.5,
              ),
              borderRadius: pw.BorderRadius.circular(noteHeadWidth / 2),
            ),
          ),
        ),
      ),
    );

    // Stem
    if (note.type != 'whole') {
      final stemUp = pos < 5;
      final stemLength = ls * 3.4;
      
      widgets.add(
        pw.Positioned(
          left: stemUp ? x + noteHeadWidth / 2 - 0.6 : x - noteHeadWidth / 2 - 0.6,
          top: stemUp ? y - stemLength : y,
          child: pw.Container(
            width: 1.2,
            height: stemLength,
            color: PdfColors.black,
          ),
        ),
      );
    }

    // Note label
    if (_showLetter || _showSolfege) {
      String label = '';
      if (_showLetter && _showSolfege) {
        label = '${note.step}\n${note.solfegeName}';
      } else if (_showLetter) {
        label = note.step;
        if (note.alter == 1) label += '#';
        if (note.alter == -1) label += 'b';
      } else if (_showSolfege) {
        label = note.solfegeName;
      }

      final textColor = color.computeLuminance() > 0.35
          ? PdfColors.black
          : PdfColors.white;

      widgets.add(
        pw.Positioned(
          left: x - 4,
          top: y - 4,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 5,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SheetMusicWidget(
        song: widget.song,
        showSolfege: _showSolfege,
        showLetter: _showLetter,
        measuresPerRow: _measuresPerRow,
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
    );
  }
}
