abstract final class BackendConfig {
  // Override at build time: --dart-define=BACKEND_URL=http://192.168.x.x:8000
  // Android emulator default: 10.0.2.2 → host machine localhost
  // iOS simulator default: use 127.0.0.1
  static const baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
