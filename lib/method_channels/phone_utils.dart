import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // 用于平台检查

class PhoneUtils {
  static const MethodChannel _chan = MethodChannel('my_phone_blocker');

  /// 调用原生 hangupCall 并打印结果
  /// 只在Android/iOS平台有效，Web平台直接返回true
  static Future<bool> interceptCall(bool enable) async {
    // 🎯 平台检查：Web平台不支持电话拦截功能
    if (kIsWeb) {
      print('🌐 Web平台不支持电话拦截功能，跳过调用');
      return true; // Web平台返回成功，避免影响业务逻辑
    }
    
    try {
      final result = await _chan.invokeMethod<bool>(
        'hangupCall',
        {'interceptEnable': enable},
      );
      final success = result ?? false;
      print('📲 interceptCall(enable=$enable) 返回：$success');
      return success;
    } on PlatformException catch (e) {
      print('❌ interceptCall 调用出错：${e.message}');
      return false;
    } catch (e) {
      print('❌ interceptCall 未知错误：$e');
      return false;
    }
  }
}