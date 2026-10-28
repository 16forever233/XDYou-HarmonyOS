import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_calendar_ohos_platform_interface.dart';

/// An implementation of [DeviceCalendarOhosPlatform] that uses method channels.
class MethodChannelDeviceCalendarOhos extends DeviceCalendarOhosPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('device_calendar_ohos');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
