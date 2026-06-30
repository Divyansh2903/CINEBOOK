import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

//Backend base URLs. For a deployed backend, pass the full origin:
//`flutter run --dart-define=API_BASE_URL=https://cinebook-api.divyansh.space`
//(the ws/wss scheme is derived from it automatically).
//For local dev: Android emulators reach the host loopback via 10.0.2.2; a
//physical device must use the host's LAN IP — override with
//`flutter run --dart-define=API_HOST=192.168.x.x`.
class AppConfig {
  static const _baseUrlOverride = String.fromEnvironment('API_BASE_URL');
  static const _hostOverride = String.fromEnvironment('API_HOST');

  static String get _host {
    if (_hostOverride.isNotEmpty) return _hostOverride;
    if (!kIsWeb && Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }

  static String get apiBaseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    return 'http://$_host:4000';
  }

  static String get wsBaseUrl {
    // Derive ws(s) from the deployed http(s) origin: https→wss, http→ws.
    if (_baseUrlOverride.isNotEmpty) {
      return _baseUrlOverride.replaceFirst(RegExp(r'^http'), 'ws');
    }
    return 'ws://$_host:4000';
  }
}
