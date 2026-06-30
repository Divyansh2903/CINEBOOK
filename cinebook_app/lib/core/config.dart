import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

//Backend base URLs. Android emulators reach the host loopback via 10.0.2.2;
//a physical device must use the host's LAN IP — override it with
//`flutter run --dart-define=API_HOST=192.168.x.x`.
class AppConfig {
  static const _hostOverride = String.fromEnvironment('API_HOST');

  static String get _host {
    if (_hostOverride.isNotEmpty) return _hostOverride;
    if (!kIsWeb && Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }

  static String get apiBaseUrl => 'http://$_host:4000';
  static String get wsBaseUrl => 'ws://$_host:4000';
}
