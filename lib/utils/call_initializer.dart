// lib/utils/call_initializer.dart

import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// 只做权限申请，返回 true=全部通过
class CallInitializer {
  /// 最大重试次数
  static const _maxRetry = 2;

  /// 入口：申请所有必要权限 + 激活通知通道
  /// 返回 true 表示所有权限都已授予（iOS 直接返回 true）
  static Future<bool> initialize() async {
    if (Platform.isIOS){
      if (!await _requestPermission(Permission.microphone)) return false;//麦克风权限
      // if (!await _requestPermission(Permission.location)) return false;//本地网络权限
      // print("IOS权限状态: ${await Permission.microphone.status} ${await Permission.location.status}");
    }else if(Platform.isAndroid){
      // 麦克风、电话、忽略电池优化
      if (!await _requestPermission(Permission.microphone)) return false;
      if (!await _requestPermission(Permission.phone)) return false;
      // if (!await _requestPermission(Permission.ignoreBatteryOptimizations)) {
      //   return false;
      // }
      // 通知通道 + 通知权限
      await _activateNotificationChannel();
      if (!await _requestPermission(Permission.notification)) {
        return false;
      }
    }

    return true;
  }

  /// 申请单个权限，只请求一次，永久拒绝时直接返回 false
  static Future<bool> _requestPermission(Permission perm) async {
    int retry = 0;
    while (retry < _maxRetry) {
      final status = await perm.request();
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied) return false;
      retry++;
    }
    // 两次都没同意，就当失败
    return false;
  }

  /// 用一个短暂的前台服务来激活通知渠道
  static Future<void> _activateNotificationChannel() async {
    await FlutterForegroundTask.startService(
      notificationTitle: '初始化通知',
      notificationText: '准备中…',
    );
    // await Future.delayed(const Duration(seconds: 1));
    await FlutterForegroundTask.stopService();
  }
}