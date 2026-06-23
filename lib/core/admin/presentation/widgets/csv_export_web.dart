// Implementação web: dispara o download de um arquivo .csv via Blob + <a download>.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool downloadCsv(String filename, String content) {
  // BOM (﻿) garante acentuação correta ao abrir no Excel.
  final bytes = '﻿$content';
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}
