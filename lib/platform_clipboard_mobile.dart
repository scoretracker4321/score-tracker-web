import 'package:flutter/services.dart'; // Required for mobile clipboard
import 'package:score_tracker_app/platform_clipboard.dart';

/// Mobile-specific implementation of [PlatformClipboard].
/// Uses Flutter's `Clipboard` service for actual copy, or prints a message.
class PlatformClipboardMobile implements PlatformClipboard {
  @override
  void copyText(String text) {
    // For actual mobile clipboard functionality, uncomment the line below:
    // Clipboard.setData(ClipboardData(text: text));
    print('Mobile: Clipboard copy not directly available for this feature in this version.');
    // You could also show a SnackBar or other UI message here for the user.
  }
}

// Provide the mobile-specific implementation to the conditional import mechanism.
PlatformClipboard getPlatformClipboard() => PlatformClipboardMobile();
