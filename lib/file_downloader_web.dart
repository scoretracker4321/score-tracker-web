// Only include this file for Flutter Web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadFileWeb(List<int> bytes, String filename) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
