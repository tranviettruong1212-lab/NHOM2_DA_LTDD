import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _configuredPort = int.fromEnvironment(
    'API_PORT',
    defaultValue: 5265,
  );

  static String get baseUrl {
    final configuredBaseUrl = _configuredBaseUrl.trim();
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    }

    final host = kIsWeb
        ? Uri.base.host
        : defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';

    if (kIsWeb) {
      final scheme = Uri.base.scheme == 'https' ? 'https' : 'http';
      return Uri(scheme: scheme, host: host, port: _configuredPort).toString();
    }

    return Uri(scheme: 'http', host: host, port: _configuredPort).toString();
  }
}
