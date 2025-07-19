import 'package:flutter/material.dart';
import 'package:test_rtc/pages/black_page.dart';
import 'pages/home_page.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '../method_channels/wakelock_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

