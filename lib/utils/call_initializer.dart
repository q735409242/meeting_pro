// lib/utils/call_initializer.dart

import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/foundation.dart';

/// 只做权限申请，返回 true=全部通过
class CallInitializer {
  /// 最大重试次数
  static const _maxRetry = 2;

  /// 入口：申请所有必要权限 + 激活通知通道
  /// 返回 true 表示所有权限都已授予
  static Future<bool> initialize() async {
    // Web平台权限处理
    if (kIsWeb) {
      return await _initializeWebPermissions();
    }
    
    // 移动端权限处理
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

  /// Web平台权限初始化
  static Future<bool> _initializeWebPermissions() async {
    try {
      // Web平台主要需要麦克风权限用于WebRTC
      // 这里我们先返回true，具体的麦克风权限会在WebRTC初始化时处理
      print('Web平台权限检查：跳过移动端特有权限，WebRTC权限将在通话时处理');
      return true;
    } catch (e) {
      print('Web权限初始化异常: $e');
      return true; // Web平台即使权限检查失败也允许继续，权限会在实际使用时再次请求
    }
  }

  /// 申请单个权限，只请求一次，永久拒绝时直接返回 false
  static Future<bool> _requestPermission(Permission perm) async {
    // Web平台跳过权限请求
    if (kIsWeb) {
      return true;
    }
    
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
    // Web平台跳过前台服务
    if (kIsWeb) {
      return;
    }
    
    await FlutterForegroundTask.startService(
      notificationTitle: '初始化通知',
      notificationText: '准备中…',
    );
    // await Future.delayed(const Duration(seconds: 1));
    await FlutterForegroundTask.stopService();
  }
}