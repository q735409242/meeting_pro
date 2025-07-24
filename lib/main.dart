import 'package:flutter/material.dart';
import 'package:test_rtc/pages/black_page.dart';
import 'pages/home_page.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '../method_channels/wakelock_service.dart';
import 'package:flutter/foundation.dart';
import 'utils/web_security.dart';

// Web平台条件导入已移除 - 暂时禁用Web特定功能

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    WebSecurity.initialize();
  }
  // Web平台性能优化 - 暂时禁用以修复编译问题
  // _initWebOptimizations();
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

/// Web平台性能优化初始化 (暂时禁用)
// void _initWebOptimizations() {
//   if (kIsWeb) {
//     Logger.network('初始化Web平台基础优化');
//     
//     try {
//       // 延迟执行，确保DOM已加载
//       Future.delayed(const Duration(milliseconds: 100), () {
//         _setupWebBasicOptimizations();
//       });
//       
//       Logger.success('Web平台基础优化已启动');
//     } catch (e) {
//       Logger.error('Web平台优化启动失败: $e');
//     }
//   }
// }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: '欢迎使用云协通',
        home: const HomePage(),
        builder: EasyLoading.init());
  }
}

