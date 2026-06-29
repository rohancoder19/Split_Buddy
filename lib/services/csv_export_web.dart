import 'dart:html' as html;
import 'dart:convert';

void downloadCsv(String csvContent, String filename) {
  final bytes = utf8.encode(csvContent);
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", filename)
    ..click();
    
  html.Url.revokeObjectUrl(url);
}
