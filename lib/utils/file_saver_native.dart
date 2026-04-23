import 'dart:convert';
import 'package:file_picker/file_picker.dart';

/// Native implementation for saving a file using FilePicker.
Future<void> saveFile({required String title, required String content}) async {
  final bytes = utf8.encode(content);
  final fileName = '${title.replaceAll(' ', '_')}.musicxml';

  await FilePicker.platform.saveFile(
    fileName: fileName,
    bytes: bytes,
    type: FileType.custom,
    allowedExtensions: ['musicxml', 'xml'],
  );
}
