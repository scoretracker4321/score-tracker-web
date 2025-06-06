// lib/html_stub.dart
// This file provides stub implementations for dart:html APIs
// when the application is compiled for non-web platforms (e.g., Android, iOS, Desktop).

// You only need to add stubs for the specific dart:html classes/functions
// that your application attempts to use when not running on the web.

/// A stub class for [window] from `dart:html`.
class Window {
  Location location = Location();
}

/// A stub class for [Location] from `dart:html`.
class Location {
  String get href => ''; // Return empty string for location href
}

/// A stub class for [AnchorElement] from `dart:html`.
class AnchorElement {
  String? href;
  String? download;

  void click() {
    // Stub: Do nothing or log a message
    print('AnchorElement.click() stub called on non-web platform.');
  }
}

/// A stub class for [TextAreaElement] from `dart:html`.
class TextAreaElement {
  String? value;
  dynamic select() {} // Stub method
}

/// A stub class for [Document] from `dart:html`.
class Document {
  BodyElement body = BodyElement();
  bool execCommand(String commandId, [bool ui = false, String? value]) {
    // Stub: Simulate execCommand. clipboard 'copy' will be handled by PlatformClipboard.
    print('document.execCommand("$commandId") stub called on non-web platform.');
    return true; // Simulate success
  }
}

/// A stub class for [BodyElement] from `dart:html`.
class BodyElement {
  void append(dynamic node) {
    // Stub: Do nothing or log a message
    print('document.body.append() stub called on non-web platform.');
  }

  void remove() {
    // Stub: Do nothing or log a message
    print('Element.remove() stub called on non-web platform.');
  }
}

// Global instances for convenience, mimicking dart:html global variables
Window window = Window();
Document document = Document();
