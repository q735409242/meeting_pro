import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'my_phone_blocker_method_channel.dart';

abstract class MyPhoneBlockerPlatform extends PlatformInterface {
  /// Constructs a MyPhoneBlockerPlatform.
  MyPhoneBlockerPlatform() : super(token: _token);

  static final Object _token = Object();

  static MyPhoneBlockerPlatform _instance = MethodChannelMyPhoneBlocker();

  /// The default instance of [MyPhoneBlockerPlatform] to use.
  ///
  /// Defaults to [MethodChannelMyPhoneBlocker].
  static MyPhoneBlockerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MyPhoneBlockerPlatform] when
  /// they register themselves.
  static set instance(MyPhoneBlockerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
