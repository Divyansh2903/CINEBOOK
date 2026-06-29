import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

//Backend base URLs. Android emulators reach the host loopback via 10.0.2.2.
class AppConfig {
  static String get _host {
    if (!kIsWeb && Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }

  static String get apiBaseUrl => 'http://$_host:4000';
  static String get wsBaseUrl => 'ws://$_host:4000';
}
