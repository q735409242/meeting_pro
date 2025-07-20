import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:test_rtc/pages/black_page.dart';
import 'pages/home_page.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '../method_channels/wakelock_service.dart';

// Web平台条件导入
import 'dart:html' as html if (dart.library.html) 'dart:html';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Web平台性能优化
  _initWebOptimizations();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'voice_call_channel_id',
      channelName: '语音通话服务',
      channelDescription: '用于后台语音通话的通知',
      channelImportance: NotificationChannelImportance.HIGH,
      priority: NotificationPriority.HIGH,
      iconData: const NotificationIconData(
        resType: ResourceType.mipmap,
        resPrefix: ResourcePrefix.ic,
        name: 'launcher',
      ),
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 5000,
      isOnceEvent: false,
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
  WakelockService.acquire();
  runApp(const MyApp());
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BlackPage(),
    ),
  );
}

/// Web平台性能优化初始化
void _initWebOptimizations() {
  if (kIsWeb) {
    print('🌐 初始化Web平台基础优化');
    
    try {
      // 延迟执行，确保DOM已加载
      Future.delayed(const Duration(milliseconds: 100), () {
        _setupWebBasicOptimizations();
      });
      
      print('✅ Web平台基础优化已启动');
    } catch (e) {
      print('❌ Web平台优化启动失败: $e');
    }
  }
}

/// 设置Web基础优化（简化版本）
void _setupWebBasicOptimizations() {
  if (kIsWeb) {
    try {
      // 基础字体优化
      html.document.body?.classes.add('font-loaded');
      
      // 基础触摸优化（仅在移动设备）
      if (html.window.navigator.userAgent.contains(RegExp(r'Mobile|Android|iPhone|iPad'))) {
        html.document.body?.style.touchAction = 'manipulation';
      }
      
      print('🎨 Web基础优化已应用');
    } catch (e) {
      print('❌ Web基础优化失败: $e');
      // 不阻止应用启动
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: '欢迎使用云助通',
        home: const HomePage(),
        builder: EasyLoading.init());
  }
}

