import 'package:flutter/foundation.dart' show kIsWeb;

abstract final class BackendConfig {
  /// Returns the backend base URL for the current platform.
  ///
  /// Priority order:
  ///   1. Manual override: --dart-define=BACKEND_URL=http://192.168.x.x:8000
  ///   2. Web browser:     http://127.0.0.1:8000  (auto-detected)
  ///   3. Android emulator: http://10.0.2.2:8000  (default fallback)
  static String get baseUrl {
    // Allow full manual override at build/run time (physical device, iOS, etc.)
    const override = String.fromEnvironment('BACKEND_URL');
    if (override.isNotEmpty) return override;
    // Auto-select based on platform
    if (kIsWeb) return 'http://127.0.0.1:8000';
    return 'http://10.0.2.2:8000'; // Android emulator → host machine localhost
  }
}

