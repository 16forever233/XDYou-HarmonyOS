import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'device_calendar_ohos_method_channel.dart';

abstract class DeviceCalendarOhosPlatform extends PlatformInterface {
  /// Constructs a DeviceCalendarOhosPlatform.
  DeviceCalendarOhosPlatform() : super(token: _token);

  static final Object _token = Object();

  static DeviceCalendarOhosPlatform _instance = MethodChannelDeviceCalendarOhos();

  /// The default instance of [DeviceCalendarOhosPlatform] to use.
  ///
  /// Defaults to [MethodChannelDeviceCalendarOhos].
  static DeviceCalendarOhosPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DeviceCalendarOhosPlatform] when
  /// they register themselves.
  static set instance(DeviceCalendarOhosPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
