import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/foundation.dart';

class PlatformUtils {
  static bool get isIOS =>
      foundation.defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isAndroid =>
      foundation.defaultTargetPlatform == TargetPlatform.android;
  static bool get isWeb => foundation.kIsWeb;
  static bool get isMacOS =>
      foundation.defaultTargetPlatform == TargetPlatform.macOS;
  static bool get isWindows =>
      foundation.defaultTargetPlatform == TargetPlatform.windows;
  static bool get isLinux =>
      foundation.defaultTargetPlatform == TargetPlatform.linux;
  static bool get isFuchsia =>
      foundation.defaultTargetPlatform == TargetPlatform.fuchsia;
}

