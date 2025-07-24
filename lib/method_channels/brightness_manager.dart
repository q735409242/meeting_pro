import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'dart:io';

class BrightnessManager {
  static const MethodChannel _channel = MethodChannel('brightness_channel');

  static double? _originalBrightness;
  static bool? _originalAutoBrightness;
  static AndroidDeviceInfo? _androidInfo;

  /// 初始化设备信息
  static Future<void> _initDeviceInfo() async {
    if (_androidInfo == null && Platform.isAndroid) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        _androidInfo = await deviceInfo.androidInfo;
        print('🔧 设备信息: ${_androidInfo!.manufacturer} ${_androidInfo!.model}');
      } catch (e) {
        print('⚠️ 获取设备信息失败: $e');
      }
    }
  }

  /// 保存当前亮度和自动亮度状态
  static Future<void> saveOriginalState() async {
    try {
      await _initDeviceInfo();
      _originalBrightness = await ScreenBrightness.instance.system;
      _originalAutoBrightness = await _isAutoBrightnessEnabled();
      print('💾 保存原始亮度: $_originalBrightness, 自动亮度: $_originalAutoBrightness');
    } catch (e) {
      print('⚡ 保存亮度状态失败: $e');
    }
  }

  /// 申请权限
  static Future<void> hasWriteSettingsPermission() async {
    try {
      bool hasPermission = await _hasWriteSettingsPermission();
      if (!hasPermission) {
        await _openWriteSettings();
      }
    } catch (e) {
      print('⚡ 请求权限失败: $e');
    }
  }

  /// 智能设置黑屏亮度 - 使用原生优化
  static Future<void> setBlackScreenBrightness() async {
    try {
      await _initDeviceInfo();
      
      // 🎯 优先使用原生方法设置最低亮度
      try {
        await _channel.invokeMethod('setSystemBrightness', {'brightness': 0.0});
        print('✅ 使用原生方法设置黑屏亮度成功');
        return;
      } catch (nativeError) {
        print('⚠️ 原生亮度设置失败，使用备用方案: $nativeError');
      }
      
      // 🎯 备用方案：使用传统方法
      await _setAutoBrightnessEnabled(false);
      double targetBrightness = await _getOptimalBlackBrightness();
      
      print('🔧 备用方案设置黑屏亮度为: $targetBrightness');
      await ScreenBrightness.instance.setSystemScreenBrightness(targetBrightness);
      
      // 🎯 验证亮度设置效果
      await Future.delayed(const Duration(milliseconds: 300));
      double actualBrightness = await ScreenBrightness.instance.system;
      print('✅ 最终亮度值: $actualBrightness');
      
      // 如果还是太高，尝试更多次设置
      if (actualBrightness > 0.02) {
        for (int attempt = 1; attempt <= 3; attempt++) {
          print('🔄 第${attempt}次尝试降低亮度');
          await ScreenBrightness.instance.setSystemScreenBrightness(0.001 / attempt);
          await Future.delayed(const Duration(milliseconds: 200));
          actualBrightness = await ScreenBrightness.instance.system;
          if (actualBrightness <= 0.02) break;
        }
      }
      
    } catch (e) {
      print('⚡ 设置黑屏亮度失败: $e');
      // 最后的备用方案
      try {
        await ScreenBrightness.instance.setSystemScreenBrightness(0.0);
      } catch (e2) {
        print('⚡ 所有亮度设置方案都失败: $e2');
      }
    }
  }

  /// 根据设备特性获取最佳黑屏亮度值
  static Future<double> _getOptimalBlackBrightness() async {
    if (_androidInfo == null) return 0.0;
    
    final manufacturer = _androidInfo!.manufacturer.toLowerCase();
    final model = _androidInfo!.model.toLowerCase();
    final sdkInt = _androidInfo!.version.sdkInt;
    
    print('🔍 设备适配: $manufacturer $model (SDK: $sdkInt)');
    
    // 🎯 根据不同厂商和机型适配最佳亮度值
    if (manufacturer.contains('xiaomi') || manufacturer.contains('redmi')) {
      // 小米设备通常需要稍高的最低值
      if (model.contains('note') || model.contains('pro')) {
        return 0.002; // Note和Pro系列
      }
      return 0.001; // 其他小米设备
    } 
    else if (manufacturer.contains('huawei') || manufacturer.contains('honor')) {
      // 华为/荣耀设备
      if (sdkInt >= 29) { // Android 10+
        return 0.001;
      }
      return 0.002;
    }
    else if (manufacturer.contains('oppo') || manufacturer.contains('oneplus')) {
      // OPPO/一加设备
      return 0.002;
    }
    else if (manufacturer.contains('vivo')) {
      // vivo设备
      return 0.001;
    }
    else if (manufacturer.contains('samsung')) {
      // 三星设备
      if (model.contains('galaxy')) {
        return 0.003; // Galaxy系列通常需要稍高值
      }
      return 0.002;
    }
    else if (manufacturer.contains('google') || manufacturer.contains('pixel')) {
      // 谷歌原生设备
      return 0.0; // 原生Android通常支持真正的0
    }
    else {
      // 其他设备使用通用值
      return 0.001;
    }
  }

  /// 设置亮度，并自动处理权限
  static Future<void> setBrightness(double brightness) async {
    try {
      await _setAutoBrightnessEnabled(false);
      await ScreenBrightness.instance.setSystemScreenBrightness(brightness);
    } catch (e) {
      print('⚡ 设置亮度失败: $e');
    }
  }

  /// 获取设备的最低亮度值（用于参考）
  static Future<double> getDeviceMinimumBrightness() async {
    try {
      final result = await _channel.invokeMethod('getMinimumBrightness');
      final minValue = (result as int) / 255.0;
      print('📱 设备最低亮度: ${result}/255 = $minValue');
      return minValue;
    } catch (e) {
      print('⚠️ 获取设备最低亮度失败: $e');
      return 0.004; // 默认值 1/255
    }
  }

  /// 恢复亮度和自动亮度状态
  static Future<void> restoreOriginalState() async {
    try {
      if (_originalBrightness != null) {
        await ScreenBrightness.instance.setSystemScreenBrightness(_originalBrightness!);
        print('🔄 恢复原始亮度: $_originalBrightness');
      }
      if (_originalAutoBrightness != null) {
        await _setAutoBrightnessEnabled(_originalAutoBrightness!);
        print('🔄 恢复自动亮度: $_originalAutoBrightness');
      }
    } catch (e) {
      print('⚡ 恢复亮度失败: $e');
    }
  }

  // ================== 私有方法 ==================

  static Future<bool> _hasWriteSettingsPermission() async {
    return await _channel.invokeMethod('hasWriteSettingsPermission');
  }

  static Future<void> _openWriteSettings() async {
    await _channel.invokeMethod('openWriteSettings');
  }

  static Future<void> _setAutoBrightnessEnabled(bool enabled) async {
    await _channel.invokeMethod('setAutoBrightnessEnabled', {"enabled": enabled});
  }

  static Future<bool> _isAutoBrightnessEnabled() async {
    return await _channel.invokeMethod('isAutoBrightnessEnabled');
  }

  /// 弹出权限提示弹窗
  // static Future<bool> _showPermissionDialog(BuildContext context) async {
  //   return await showDialog<bool>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (ctx) {
  //       return AlertDialog(
  //         title: const Text('需要权限'),
  //         content: const Text('需要打开“修改系统设置”权限才能调整亮度。请前往设置打开权限。'),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(ctx).pop(false);
  //             },
  //             child: const Text('取消'),
  //           ),
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(ctx).pop(true);
  //             },
  //             child: const Text('去设置'),
  //           ),
  //         ],
  //       );
  //     },
  //   ) ?? false;
  // }
}