
import 'my_phone_blocker_platform_interface.dart';

class MyPhoneBlocker {
  Future<String?> getPlatformVersion() {
    return MyPhoneBlockerPlatform.instance.getPlatformVersion();
  }
}
