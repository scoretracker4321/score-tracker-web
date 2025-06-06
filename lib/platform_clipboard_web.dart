import 'dart:html' as html; // Only imported here, not in main.dart
import 'package:score_tracker_app/platform_clipboard.dart';

/// Web-specific implementation of [PlatformClipboard].
/// Uses `dart:html` to interact with the browser's clipboard.
// class PlatformClipboardWeb implements PlatformClipboard {
//   @override
  // void copyText(String text) {
  //   // Directly use html.window.navigator.clipboard for web
  //   html.window.navigator.clipboard?.writeText(text);
  //   print('Web: Copied "$text" to clipboard.');
  // }
//}

// Provide the web-specific implementation to the conditional import mechanism.
// PlatformClipboard getPlatformClipboard() => PlatformClipboardWeb();
