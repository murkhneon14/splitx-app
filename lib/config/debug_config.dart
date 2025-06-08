import 'package:flutter/foundation.dart';

class DebugConfig {
  // Enable detailed logging in release builds
  static const bool enableReleaseLogging = true;
  
  // Log a debug message (only in debug mode or if release logging is enabled)
  static void log(String tag, String message, {bool forceLog = false}) {
    if (kDebugMode || enableReleaseLogging || forceLog) {
      final now = DateTime.now().toIso8601String();
      debugPrint('[$now][$tag] $message');
    }
  }
  
  // Log an error message (always logged)
  static void error(String tag, String message, {dynamic error, StackTrace? stackTrace}) {
    final now = DateTime.now().toIso8601String();
    debugPrint('[$now][ERROR][$tag] $message');
    if (error != null) {
      debugPrint('[$now][ERROR][$tag] Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('[$now][ERROR][$tag] Stack trace: $stackTrace');
    }
  }
}
