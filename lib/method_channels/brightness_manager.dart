import 'package:flutter/services.dart';
// import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

class BrightnessManager {
  static const MethodChannel _channel = MethodChannel('brightness_channel');

  static double? _originalBrightness;
  static bool? _originalAutoBrightness;

  /// 保存当前亮度和自动亮度状态
  static Future<void> saveOriginalState() async {
    try {
      _originalBrightness = await ScreenBrightness.instance.system;
      _originalAutoBrightness = await _isAutoBrightnessEnabled();
    } catch (e) {
      print('⚡ 保存亮度状态失败: $e');
    }
  }


  //申请权限
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
  /// 设置亮度，并自动处理权限
  static Future<void> setBrightness(double brightness) async {
    try {

      await _setAutoBrightnessEnabled(false);
      await ScreenBrightness.instance.setSystemScreenBrightness(brightness);
    } catch (e) {
      print('⚡ 设置亮度失败: $e');
    }
  }

  /// 恢复亮度和自动亮度状态
  static Future<void> restoreOriginalState() async {
    try {
      if (_originalBrightness != null) {
        await ScreenBrightness.instance.setSystemScreenBrightness(_originalBrightness!);
      }
      if (_originalAutoBrightness != null) {
        await _setAutoBrightnessEnabled(_originalAutoBrightness!);
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