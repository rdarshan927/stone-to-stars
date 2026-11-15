/// Application configuration.
library;

/// Base URL of the Stone to Stars backend.
///
/// Override at build/run time:
///   flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8766
///   Android emulator:  --dart-define=API_BASE_URL=http://10.0.2.2:8766
///   Physical device:   --dart-define=API_BASE_URL=http://[LAN-IP]:8766
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8766',
);

/// Request timeout. NASA POWER requests can take several seconds, and the
/// backend allows itself up to 30 s upstream.
const Duration requestTimeout = Duration(seconds: 45);
