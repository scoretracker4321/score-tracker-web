import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

// Conditional import for dart:html, only available on web.
// For non-web, we use a stub to avoid import errors.
// Ensure you have an empty file named html_stub.dart in your lib/ folder.
import 'dart:html' if (dart.library.io) 'package:score_tracker_app/html_stub.dart' as html;

/// Abstract class defining the contract for clipboard operations.
/// This allows for platform-specific implementations (web vs. mobile/desktop).
abstract class PlatformClipboard {
  /// Private constructor to prevent direct instantiation.
  PlatformClipboard._();

  /// The singleton instance of PlatformClipboard, chosen at runtime based on the platform.
  static PlatformClipboard get instance {
    if (kIsWeb) {
      return _PlatformClipboardWeb._(); // Return web-specific implementation
    } else {
      return _PlatformClipboardMobile._(); // Return mobile-specific implementation
    }
  }

  /// Copies the given [text] to the clipboard.
  /// This method is asynchronous and returns a [Future<void>].
  Future<void> copyText(String text);
}

/// Web-specific implementation of [PlatformClipboard].
/// Uses `document.execCommand('copy')` for compatibility in iframes.
class _PlatformClipboardWeb extends PlatformClipboard {
  _PlatformClipboardWeb._() : super._();

  @override
  Future<void> copyText(String text) async { // Changed return type to Future<void>
    try {
      // Create a temporary textarea element to hold the text.
      // This is a common workaround for clipboard operations in web environments,
      // especially within iframes where direct navigator.clipboard access might be restricted.
      final html.TextAreaElement textarea = html.TextAreaElement()
        ..value = text
        ..style.position = 'fixed' // Hide it visually
        ..style.left = '-9999px';

      // Append the textarea to the document body.
      html.document.body!.append(textarea);

      // Select the text in the textarea.
      textarea.select();

      // Execute the copy command.
      final bool success = html.document.execCommand('copy');

      // Remove the temporary textarea from the DOM.
      textarea.remove();

      if (!success) {
        print('Web clipboard copy failed via execCommand. User might need to manually copy.');
        // In a real application, you might show a user-friendly message here,
        // like "Copy failed, please copy manually: [text]".
      } else {
        print('Web clipboard copy successful.');
      }
    } catch (e) {
      print('Error copying to clipboard on web: $e');
      // Log or show an error message to the user.
    }
  }
}

/// Mobile/Desktop-specific implementation of [PlatformClipboard].
/// Uses Flutter's `Clipboard` services, which are robust for native platforms.
class _PlatformClipboardMobile extends PlatformClipboard {
  _PlatformClipboardMobile._() : super._();

  @override
  Future<void> copyText(String text) async { // Changed return type to Future<void> and made it async
    try {
      await Clipboard.setData(ClipboardData(text: text));
      print('Mobile clipboard copy successful.');
    } catch (e) {
      print('Error copying to clipboard on mobile: $e');
      // Log or show an error message to the user.
    }
  }
}
