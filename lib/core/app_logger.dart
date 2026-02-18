import 'dart:developer' as developer;

/// Centralized logging utility for the app.
class AppLogger {
  const AppLogger._();

  static void info(String message, {String name = 'APP'}) {
    developer.log(message, name: name, level: 800); // INFO
  }

  static void warning(String message, {String name = 'APP'}) {
    developer.log(message, name: name, level: 900); // WARNING
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String name = 'APP',
  }) {
    developer.log(
      message,
      name: name,
      level: 1000, // SEVERE
      error: error,
      stackTrace: stackTrace,
    );
  }
}
