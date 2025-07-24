import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '../../method_channels/phone_utils.dart';
import '../../api/api.dart';
import '../../method_channels/screen_stream_channel.dart' as screen;

/// 生命周期管理模块 - 处理应用生命周期和初始化/清理逻辑
mixin LifecycleManagerMixin<T extends StatefulWidget> on State<T> {
  
  // 需要子类实现的抽象属性
  bool get isCaller;
  String? get registrationCode;
  String? get deviceId;
  String get roomId;
  String? get channel;
  
  // 需要子类实现的抽象方法
  void setupKeyboardListener();
  Future<void> initializeCall();
  void startDurationTimer();
  void setupWebPageRefreshConfirmation();
  void endCallWithNotice();
  
  // 生命周期相关状态
  Timer? _userCheckTimer;
  int _checkFailCount = 0;
  
  /// 初始化生命周期管理
  Future<void> initializeLifecycle() async {
    print('🔄 初始化生命周期管理模块');
    
    // 添加Widget生命周期观察者
    WidgetsBinding.instance.addObserver(this as WidgetsBindingObserver);
    
    // 初始化基础组件
    await _initializeBasicComponents();
    
    // 设置键盘监听（仅Web端主控需要）
    if (kIsWeb && isCaller) {
      setupKeyboardListener();
    }
    
    // 初始化视频帧接收通道（仅iOS需要）
    _initializeVideoFrameChannel();
    
    // 启动用户检查（仅主控端需要）
    if (isCaller && registrationCode != null && deviceId != null) {
      _startUserCheck();
    }
    
    // 设置Web平台页面刷新确认
    if (kIsWeb) {
      setupWebPageRefreshConfirmation();
    }
    
    // 启动通话初始化
    await initializeCall();
    
    // 启动计时器（仅被控端需要）
    if (!isCaller) {
      startDurationTimer();
    }
    
    print('✅ 生命周期管理模块初始化完成');
  }
  
  /// 基础组件初始化
  Future<void> _initializeBasicComponents() async {
    print('🔧 初始化基础组件');
    
    // 这里可以添加一些基础的初始化逻辑
    // 比如权限检查、配置加载等
  }
  
  /// 初始化视频帧接收通道
  void _initializeVideoFrameChannel() {
    if (!kIsWeb && Platform.isIOS) {
      print('📺 初始化iOS视频帧接收通道');
      // 这里的具体实现需要在StateManagerMixin中处理
      // screenStreamChannel = screen.ScreenStreamChannel();
    }
  }
  
  /// 启动用户检查定时器
  void _startUserCheck() {
    print('⏰ 启动用户检查定时器');
    
    _userCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      await _checkUserInfo();
    });
  }
  
  /// 检查用户信息
  Future<void> _checkUserInfo() async {
    if (registrationCode == null || deviceId == null) return;
    
    String? serverDeviceId;
    Map<String, dynamic> result = {};
    
    try {
      // 查询用户信息
      result = await Api.searchUserInfo(registrationCode!);
      print('📋 查询用户信息：$result');
      
      // 获取远端设备ID
      if (result['data'] != null && result['data'].isNotEmpty) {
        serverDeviceId = result['data'][0]['device_id'];
        print('📱 远端设备ID：$serverDeviceId, 本地设备ID：$deviceId');
      }
    } catch (e) {
      _checkFailCount++;
      print('❌ 查询用户信息失败，第 $_checkFailCount 次: $e');
    }
    
    // 判断设备ID是否一致或者result为空
    if (serverDeviceId != deviceId || result['data'].isEmpty) {
      _checkFailCount++;
      print('⚠️ 设备ID不一致，第 $_checkFailCount 次');
      
      if (_checkFailCount >= 3 && mounted) {
        print('❌ 连续 3 次设备ID 不一致，结束通话');
        _userCheckTimer?.cancel();
        endCallWithNotice();
      }
    } else {
      _checkFailCount = 0; // 重置失败次数
    }
  }
  
  /// 处理应用生命周期变化（需要在主类中调用）
  void handleAppLifecycleState(AppLifecycleState state) {
    print('🔄 应用生命周期变化: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.inactive:
        _handleAppInactive();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        _handleAppHidden();
        break;
    }
  }
  
  /// 处理应用恢复到前台
  void _handleAppResumed() {
    print('📱 应用恢复到前台');
    // 可以在这里添加应用恢复时的逻辑
    // 比如重新激活某些功能、刷新状态等
  }
  
  /// 处理应用进入后台
  void _handleAppPaused() {
    print('📱 应用进入后台');
    // 可以在这里添加应用暂停时的逻辑
    // 比如保存状态、暂停某些功能等
  }
  
  /// 处理应用变为非活跃状态
  void _handleAppInactive() {
    print('📱 应用变为非活跃状态');
    // 处理应用非活跃状态的逻辑
  }
  
  /// 处理应用被分离
  void _handleAppDetached() {
    print('📱 应用被分离');
    // 处理应用被分离时的逻辑
  }
  
  /// 处理应用被隐藏
  void _handleAppHidden() {
    print('📱 应用被隐藏');
    // 处理应用被隐藏时的逻辑
  }
  
  /// 启动前台服务
  Future<void> startForegroundService() async {
    if (!kIsWeb && Platform.isAndroid) {
      print('🚀 Android 启动前台服务');
      try {
        await FlutterForegroundTask.startService(
          notificationTitle: '语音通话进行中',
          notificationText: '请勿关闭应用以保持通话稳定',
        );
      } catch (e) {
        print('❌ 启动前台服务失败: $e');
      }
    } else {
      print('🚀 ${kIsWeb ? "Web" : Platform.isIOS ? "iOS" : "其他平台"} 无需前台服务');
    }
  }
  
  /// 停止前台服务
  Future<void> stopForegroundService() async {
    if (!kIsWeb && Platform.isAndroid) {
      print('🛑 Android 停止前台服务');
      try {
        await FlutterForegroundTask.stopService();
      } catch (e) {
        print('❌ 停止前台服务失败: $e');
      }
    }
  }
  
  /// 检查并等待通话结束（iOS特有）
  Future<void> checkAndWaitForCallEnd() async {
    if (!kIsWeb && Platform.isIOS) {
      const channel = MethodChannel('call_status_channel');
      bool isInCall = false;
      
      try {
        isInCall = await channel.invokeMethod<bool>('isInCall') ?? false;
      } catch (e) {
        print("❌ 检测通话状态失败: $e");
      }
      
      if (isInCall) {
        print('📞 检测到正在通话，等待通话结束...');
        
        // 轮询等待通话结束
        while (isInCall) {
          await EasyLoading.showToast(
            '检测到当前正在通话，挂断电话之后将自动进入',
            duration: const Duration(seconds: 1),
          );
          await Future.delayed(const Duration(seconds: 1));
          
          try {
            isInCall = await channel.invokeMethod<bool>('isInCall') ?? false;
          } catch (_) {
            isInCall = false;
          }
        }
        
        print('✅ 通话已结束，继续初始化');
      }
    }
  }
  
  /// 清理生命周期资源
  void disposeLifecycleManager() {
    print('🧹 清理生命周期管理模块资源');
    
    // 移除Widget生命周期观察者
    WidgetsBinding.instance.removeObserver(this as WidgetsBindingObserver);
    
    // 取消用户检查定时器
    _userCheckTimer?.cancel();
    _userCheckTimer = null;
    
    // 恢复来电拦截
    try {
      PhoneUtils.interceptCall(false);
    } catch (e) {
      print('❌ 恢复来电拦截失败: $e');
    }
    
    // 停止前台服务
    stopForegroundService();
    
    print('✅ 生命周期管理模块资源清理完成');
  }
} 