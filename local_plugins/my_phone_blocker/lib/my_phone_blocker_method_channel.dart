import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'my_phone_blocker_platform_interface.dart';

/// An implementation of [MyPhoneBlockerPlatform] that uses method channels.
class MethodChannelMyPhoneBlocker extends MyPhoneBlockerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('my_phone_blocker');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
