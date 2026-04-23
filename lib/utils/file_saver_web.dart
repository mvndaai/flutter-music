import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Web implementation for downloading a file using package:web.
Future<void> saveFile({required String title, required String content}) async {
  final bytes = utf8.encode(content);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/xml'),
  );
  
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.setAttribute('download', '${title.replaceAll(' ', '_')}.musicxml');
  
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  
  web.URL.revokeObjectURL(url);
}
