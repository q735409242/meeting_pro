import 'package:flutter/services.dart';
// import 'package:flutter/foundation.dart';  // for debugPrint

class PhoneUtils {
  static const MethodChannel _chan = MethodChannel('my_phone_blocker');

  /// 调用原生 hangupCall 并打印结果
  static Future<bool> interceptCall(bool enable) async {
    try {
      final result = await _chan.invokeMethod<bool>(
        'hangupCall',
        {'interceptEnable': enable},
      );
      final success = result ?? false;
      // debugPrint('📲 interceptCall(enable=$enable) 返回：$success');
      return success;
    } on PlatformException catch (e) {
      print('❌ interceptCall 调用出错：${e.message}');
      return false;
    }
  }
}