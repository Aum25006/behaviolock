import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ApiConfig {
  static String get baseUrl {
    // Always use direct connection to Flask backend
    return 'http://localhost:5000';
  }
  
  static String get webBaseUrl => 'http://localhost:5000';
  
  static bool get isWeb => kIsWeb;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
}
