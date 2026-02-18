/// Global app configuration (API base URLs, environment flags, etc.).
class AppConfig {
  AppConfig._();

  /// Environment name, e.g. dev / staging / prod.
  static const String env = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  /// API base URL, overridable via --dart-define=API_BASE_URL=...
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.109:8089/api/v1',
  );
}
