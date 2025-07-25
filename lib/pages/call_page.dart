// ignore_for_file: non_constant_identifier_names, avoid_print
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

// Web平台条件导入已移除 - 暂时禁用Web特定功能

// import 'dart:math' as math;
// import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../utils/signaling.dart';
import '../../method_channels/phone_utils.dart';
import '../api/api.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../method_channels/gestue_channel.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../method_channels/brightness_manager.dart';

// import 'package:byteplus_rtc/byteplus_rtc.dart';

// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/services.dart';
import '../method_channels/screen_stream_channel.dart' as screen;
// import 'dart:ui' as ui;

/// 通话页面：负责麦克风权限、音频路由、屏幕共享、WebRTC 连接等逻辑
class CallPage extends StatefulWidget {
  final String roomId;
  final bool isCaller;
  final String? registrationCode;
  final String? deviceId;
  final String? appid_cf;
  final String? certificate_cf;
  final String? appid_sdk;
  final String? certificate_sdk;
  final String? type;
  final String? channel;

  const CallPage(
      {Key? key,
      required this.roomId,
      required this.isCaller,
      required this.registrationCode,
      required this.deviceId,
      required this.appid_cf,
      required this.certificate_cf,
      required this.appid_sdk,
      required this.certificate_sdk,
      required this.type,
      required this.channel})
      : super(key: key);

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> with WidgetsBindingObserver {
  Timer? _checkUserTimer;

  // 手势处理相关变量
  Offset? _pointerDownPosition;
  int? _pointerDownTime;
  bool _isDragging = false;
  static const double _tapThreshold = 10.0; // 点击阈值：移动距离小于10像素认为是点击
  static const int _tapTimeThreshold = 500; // 点击时间阈值：500ms内认为是点击
  
  // Web平台的点击阈值（鼠标更精确，降低阈值提高拖拽响应）
  static double get _webTapThreshold => kIsWeb ? 3.0 : _tapThreshold; // 从5.0降低到3.0
  static int get _webTapTimeThreshold => kIsWeb ? 300 : _tapTimeThreshold;
  
  // 长按支持相关变量
  Timer? _longPressTimer;
  bool _isLongPressing = false;
  bool _longPressTriggered = false;
  static const int _longPressThreshold = 600; // 长按阈值：600ms
  
  // 键盘监听相关
  FocusNode? _keyboardFocusNode;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  Signaling? _signaling;
  MediaStream? _screenStream;
  RTCRtpSender? _screenSender;

  //BytePlus sdk
  // RTCVideo? _rtcVideo;
  // RTCRoom? _rtcRoom;
  // final RTCVideoEventHandler _videoHandler = RTCVideoEventHandler();
  // final RTCRoomEventHandler _roomHandler = RTCRoomEventHandler();
  //
  // // RTCViewContext? _localRenderContext;
  // RTCViewContext? _firstRemoteRenderContext;
  // RTCViewContext? _secondRemoteRenderContext;
  // RTCViewContext? _thirdRemoteRenderContext;
  // RTCViewContext? _remoteScreenContext;

  // 声网引擎
  // late final RtcEngineEx _agoraEngine;

  ///通道
  final MethodChannel _iosScreenShareChannel =
      const MethodChannel('example_screensharing_ios');

  //切换线路

  // bool _changeChannel=true;
  late String _channel;

  int _checkFailCount = 0; // 连续失败次数
  //自己的麦克风
  bool _micphoneOn = true;

  //屏幕开关
  bool _screenShareOn = false;

  ///拦截开关
  bool _interceptOn = false;

  /////远控
  bool _remoteOn = false;
  Offset? _buttonGroupPosition;

  //提示开关
  bool _showBlack = false;

  // didChangeDependencies removed

  // //对方的麦克风
  bool _contributorSpeakerphoneOn = true;

  final GlobalKey _videoKey = GlobalKey();
  double _remoteScreenWidth = 0;
  double _remoteScreenHeight = 0;

  // 远端是否有音视频流
  bool _remoteHasVideo = false;
  bool _remoteHasAudio = false;

  // 当前 App 是否处于前台
  bool _isAppInForeground = true;

  // 是否有延迟执行的屏幕共享请求
  bool _pendingStartScreen = false;

  //是否刷新
  bool _isrefresh = false;
  bool _icerefresh = false;
  bool _canRefresh = true;
  bool _canShareScreen = true; // 控制屏幕共享按钮是否可用
  
  // ICE状态跟踪 
  RTCIceConnectionState? _currentIceState;

  bool _isManualRefresh = false; // 标记是否为手动刷新
  
  // 重连前的状态保存
  bool _savedScreenShareOn = false;
  bool _savedMicphoneOn = true;
  bool _savedSpeakerphoneOn = true;
  // 📄 新增：保存页面读取状态
  bool _savedShowNodeRects = false;
  
  // 重连前的流保存（关键：保存实际的流对象）
  MediaStream? _savedScreenStream;
  RTCRtpSender? _savedScreenSender;

  // String? _Uid;

  String? _remoteUid;

  //显示通话时间
  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;

  // 视频帧处理
  screen.ScreenStreamChannel? _screenStreamChannel;

  // screen.VideoFrame? _lastVideoFrame;
  StreamSubscription? _videoFrameSubscription;

  List<_AccessibilityNode> _nodeRects = [];

  bool _showNodeRects = false;

  Timer? _nodeTreeTimer;

  // 保存RTCVideoView的分辨率信息，用于节点树显示
  double _savedRemoteScreenWidth = 0.0;
  double _savedRemoteScreenHeight = 0.0;

  // 保存视频容器的位置和尺寸信息，用于屏幕共享关闭后的坐标转换
  Offset? _savedVideoContainerTopLeft;
  double? _savedVideoDisplayWidth;
  double? _savedVideoDisplayHeight;
  double? _savedVideoOffsetX;
  double? _savedVideoOffsetY;
  bool _hasValidVideoContainerInfo = false; // 标记是否有有效的容器信息

  // Web平台页面刷新监听器 - 使用dynamic避免编译时类型检查
  dynamic _beforeUnloadListener;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    _channel = widget.channel!;
    _remoteRenderer.initialize();
    _initializeCall();
    if (!widget.isCaller) _startDurationTimer(); // ← 只有被控端启动
    
    // Web端键盘事件监听 - 只有主控端需要
    if (kIsWeb && widget.isCaller) {
      _setupKeyboardListener();
    }
    // 初始化视频帧接收通道
    if (!kIsWeb && Platform.isIOS) {
      _screenStreamChannel = screen.ScreenStreamChannel();
      // _videoFrameSubscription = _screenStreamChannel?.videoFrameStream.listen(_handleVideoFrame);
    }

    /// 整体初始化：启动前台服务、准备音频、注册路由监听、启动通话
    if (widget.isCaller &&
        widget.registrationCode != null &&
        widget.deviceId != null) {
      _checkUserTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
        String? serverDeviceId; // 将变量声明为可空类型
        Map<String, dynamic> result = {};

        try {
          // 查询用户信息
          result = await Api.searchUserInfo(widget.registrationCode!);
          print('查询用户信息：$result');

          // 获取远端设备ID
          if (result['data'] != null && result['data'].isNotEmpty) {
            serverDeviceId = result['data'][0]['device_id'];
            print('远端设备ID：$serverDeviceId, 本地设备ID：${widget.deviceId}');
          }
        } catch (e) {
          _checkFailCount++;
          print('查询用户信息失败，第 $_checkFailCount 次');
        }

        // 判断设备ID是否一致或者result为空
        if (serverDeviceId != widget.deviceId || result['data'].isEmpty) {
          _checkFailCount++;
          print('设备ID不一致，第 $_checkFailCount 次');
          if (_checkFailCount >= 3 && mounted) {
            print('连续 3 次设备ID 不一致，结束通话');
            _endCallWithNotice();
          }
        } else {
          _checkFailCount = 0; // 重置失败次数
        }
      });
    }

    // Web平台：设置页面刷新前确认
    _setupWebPageRefreshConfirmation();
  }

  /// 设置Web平台键盘监听器
  void _setupKeyboardListener() {
    if (!kIsWeb || !widget.isCaller) return;
    
    print('🎹 设置Web端键盘监听器');
    _keyboardFocusNode = FocusNode();
    
    // 确保焦点节点能接收键盘事件
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_keyboardFocusNode != null && mounted) {
        _keyboardFocusNode!.requestFocus();
        print('🎹 键盘监听器焦点已获取');
      }
    });
  }
  
  /// 处理键盘输入事件
  void _handleKeyboardInput(String text) {
    // 只有主控端且开启远程控制时才发送键盘输入
    if (!widget.isCaller || !_remoteOn) return;
    
    String displayText = text;
    if (text == 'BACKSPACE') {
      displayText = '退格键';
    } else if (text == 'ENTER') {
      displayText = '回车键';
    } else if (text.startsWith('PASTE:')) {
      displayText = '黏贴内容';
    }
    
    print('🎹 Web端键盘输入: "$displayText"');
    
    if (_channel == 'cf') {
      _signaling?.sendCommand({
        'type': 'key_input',
        'text': text,
      });
      print('🎹 已发送键盘输入命令: "$displayText"');
    }
  }
  
  /// 处理黏贴操作
  void _handlePasteOperation() async {
    try {
      print('🎹 开始获取剪切板内容...');
      
      // 获取剪切板内容
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final pasteText = clipboardData?.text;
      
      if (pasteText != null && pasteText.isNotEmpty) {
        print('🎹 获取到剪切板内容: "${pasteText.length > 50 ? pasteText.substring(0, 50) + '...' : pasteText}"');
        
        // 发送黏贴命令，使用特殊格式标识
        _handleKeyboardInput('PASTE:$pasteText');
      } else {
        print('🎹 剪切板为空或无文本内容');
      }
    } catch (e) {
      print('🎹 获取剪切板内容失败: $e');
    }
  }
  
      
  /// 设置Web平台页面刷新前确认
  void _setupWebPageRefreshConfirmation() {
    if (kIsWeb) {
      print('🌐 设置Web页面刷新前确认');
      _beforeUnloadListener = (event) {
        // 阻止默认行为
        event.preventDefault();
        
        // 设置确认消息 - 这会显示浏览器原生确认对话框
        const confirmMessage = '确定刷新页面?刷新页面后将退出房间';
        (event as dynamic).returnValue = confirmMessage;
        
        // 异步执行退出房间逻辑（不阻塞页面关闭）
        _handlePageUnload();
        
        // 返回确认消息（某些浏览器需要）
        return confirmMessage;
      };
      
      // 添加监听器 - 暂时禁用避免编译问题
      // TODO: 重新实现Web页面刷新监听
      if (kIsWeb) {
        print('Web页面刷新监听暂时禁用');
      }
      print('🌐 Web页面刷新确认已设置');
    }
  }

  /// 处理页面卸载 - 执行退出房间逻辑
  void _handlePageUnload() {
    try {
      print('📤 页面即将刷新/关闭，执行退出房间逻辑');
      
      // 发送退出房间信令（同步执行，尽快发送）
      _onExitRoom();
      
      // 快速清理关键资源
      _signaling?.close();
      _localStream?.getAudioTracks().forEach((t) => t.stop());
      _screenStream?.getTracks().forEach((t) => t.stop());
      
      print('📤 退出房间信令已发送');
    } catch (e) {
      print('❌ 页面卸载处理失败: $e');
    }
  }



  //显示通话时长
  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _callDuration += const Duration(seconds: 1);
      });
    });
  }

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  /// 退出通话并弹出"通话结束"提示
  void _endCallWithNotice() {
    if (!mounted) return;
    Navigator.of(context).pop(); // 先退出 CallPage
    // 延迟弹窗，避免使用已 dispose 的 context
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      showDialog(
        context: context,
        useRootNavigator: true, // 使用根 Navigator
        builder: (_) => const AlertDialog(
          title: Text('通话结束'),
          content: Text('注册码绑定的设备已更换，请重新绑定后再试'),
          // actions: [
          //   TextButton(
          //     onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          //     child: const Text('确定'),
          //   ),
          // ],
        ),
      );
    });
  }

  Future<void> _checkAndWaitForCallEnd() async {
    if (WebRTC.platformIsIOS) {
      const channel = MethodChannel('call_status_channel');
      bool isInCall = false;
      try {
        isInCall = await channel.invokeMethod<bool>('isInCall') ?? false;
      } catch (e) {
        print("检测通话状态失败: $e");
      }

      if (isInCall) {
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
      }
    }
  }

  /// 整体初始化：启动前台服务、准备音频、注册路由监听、启动通话
  Future<void> _initializeCall() async {
    print('🚀 开始初始化通话: isCaller=${widget.isCaller}, roomId=${widget.roomId}');
    await _checkAndWaitForCallEnd(); // 检测是否有正在进行的通话
    await _startForegroundService(); //通知保活
    // await _prepareAudioSession(); //打开麦克风权限,ios设置成扬声器模式
    await _startCall();
    await _registerRouteListener(); //监听耳机
    await _startForegroundService(); // 通知保活
  }

  /// 启动 Android 前台服务，iOS 和 Web 无需
  Future<void> _startForegroundService() async {
    if (!kIsWeb && Platform.isAndroid) {
      print('🚀 Android 启动前台服务');
      await FlutterForegroundTask.startService(
        notificationTitle: '语音通话进行中',
        notificationText: '请勿关闭应用以保持通话稳定',
      );
    } else {
      print('🚀 ${kIsWeb ? "Web" : Platform.isIOS ? "iOS" : "其他平台"} 无需前台服务');
    }
  }

  /// 停止前台服务
  Future<void> _stopForegroundService() async {
    if (!kIsWeb && Platform.isAndroid) {
      print('🛑 Android 停止前台服务');
      await FlutterForegroundTask.stopService();
    }
  }

  /// 准备音频会话：请求权限 + 配置 AVAudioSession
  Future<void> _prepareAudioSession() async {
    print('🎧 IOS准备切换到扬声器模式');
    // 1. 请求麦克风权限
    // final status = await Permission.microphone.request();
    // if (!status.isGranted) {
    //   print('❌ 麦克风权限未授权，退出通话');
    //   throw Exception('麦克风权限未授权');
    // } else if (status.isGranted) {
    //   // 用户已授权
    //   print('✅ 麦克风权限已开启');
    // }

    if (!kIsWeb && Platform.isIOS) {
      // 2. 初始化并配置 AVAudioSession
      await Helper.ensureAudioSession();
      await Helper.setAppleAudioConfiguration(AppleAudioConfiguration(
        appleAudioCategory: AppleAudioCategory.playAndRecord,
        appleAudioMode: AppleAudioMode.voiceChat,
        appleAudioCategoryOptions: {
          AppleAudioCategoryOption.defaultToSpeaker,
          AppleAudioCategoryOption.allowBluetooth,
          // AppleAudioCategoryOption.interruptSpokenAudioAndMixWithOthers,
          // AppleAudioCategoryOption.mixWithOthers,
        },
      ));
      // 配置音频I/O模式为语音聊天，并优先使用扬声器
      await Helper.setAppleAudioIOMode(AppleAudioIOMode.localAndRemote,
          preferSpeakerOutput: true);
      // await Helper.setSpeakerphoneOn(true); // iOS 默认开启扬声器
      print('✅ iOS AVAudioSession 已配置为 playAndRecord+默认扬声器');
    }
  }

  /// 注册音频路由变化监听（Android 插拔耳机），iOS 和 Web 使用默认行为
  Future<void> _registerRouteListener() async {
    if (!kIsWeb && Platform.isAndroid) {
      print('🔈 Android 注册音频路由监听');
      navigator.mediaDevices.ondevicechange = (_) => _handleAudioRoute();
      await _handleAudioRoute();
    } else {
      print('🔈 ${kIsWeb ? "Web" : "iOS"} 使用默认音频路由行为');
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    _isAppInForeground = state == AppLifecycleState.resumed;
    // 如果回到前台时有待执行的屏幕共享请求，就执行
    if (state == AppLifecycleState.resumed &&
        _pendingStartScreen &&
        !kIsWeb && Platform.isAndroid) {
      print('📺 应用恢复前台，执行延迟的屏幕共享');
      _pendingStartScreen = false;
      await _startScreenShareSafely();
    } else if (state == AppLifecycleState.paused &&
        !kIsWeb && Platform.isIOS &&
        !_screenShareOn) {
      print(' IOS 进入后台，开启扬声器');
      await _prepareAudioSession();
      // await Helper.setSpeakerphoneOn(true);
      // await Helper.ensureAudioSession();
      //延迟1秒执行屏幕共享
      if (_pendingStartScreen) {
        Future.delayed(const Duration(seconds: 1), () async {
          // iOS 后台时开启扬声器
          _pendingStartScreen = false;
          await _startScreenShareSafely();
        });
        // _pendingStartScreen = false;
        // await _toggleScreenShare();
      }
      // try{
      //   Helper.setSpeakerphoneOn(true); // iOS 后台时开启扬声器
      // }catch (e) {
      //   print('❌ 设置扬声器失败，可能是 iOS 后台限制');
      // }
    }
  }

  /// 枚举音频设备，检测耳机插拔并切换扬声器
  Future<void> _handleAudioRoute() async {
    final devices = await navigator.mediaDevices.enumerateDevices();
    final audioDevices =
        devices.where((d) => d.kind?.startsWith('audio') ?? false).toList();
    // print('🔈 音频设备(${audioDevices.length})');
    // for (var d in audioDevices) {
    // print('  • ${d.kind}: ${d.label} (${d.deviceId})');
    // }
    // 匹配可能的耳机关键字
    const patterns = [
      'headphone',
      'headset',
      'earbud',
      'airpod',
      'earphone', // 入耳式通用叫法
      'ear-piece', // 有些系统把听筒也叫 earpiece，需要排除时再做判断
      'in-ear', // 部分真无线耳机会带 in-ear
      'wired', // 有线耳机、Wired Headset
      'wireless', // 无线耳机
      'bluetooth', // 蓝牙
      'usb', // USB 耳机 / USB audio
      'aux', // AUX 外放
      'jack', // 3.5mm jack
      'lineout', // line-out 输出
      'lightning', // iPhone Lightning 耳机
      'digital', // 部分 USB/HDMI/Digital Audio 设备
      // 如果你还想根据中文来匹配：
      '耳机',
      '有线',
      '无线',
      '蓝牙',
    ];
    final hasHeadset = audioDevices.any((d) {
      final lb = d.deviceId.toLowerCase();
      return patterns.any((p) => lb.contains(p));
    });
    if (hasHeadset) {
      print('🎧 检测到耳机，关闭扬声器');
      await Helper.setSpeakerphoneOn(false);
    } else {
      print('🔊 未检测到耳机，开启扬声器');
      await Helper.setSpeakerphoneOn(true);
    }
  }

  // 处理pointer down事件 - 支持长按检测
  void _onPointerDown(Offset globalPos) {
    _pointerDownPosition = globalPos;
    _pointerDownTime = DateTime.now().millisecondsSinceEpoch;
    _isDragging = false;
    _longPressTriggered = false;
    
    if (!widget.isCaller || !_remoteOn) {
      return;
    }
    
    // 启动长按检测定时器
    _startLongPressTimer(globalPos);
    
    // 移动端立即发送swipStart，Web端等待移动确认
    if (!kIsWeb) {
      _onTouch(globalPos, 'swipStart');
    }
    
    print('🖱️ 按下: (${globalPos.dx.toInt()}, ${globalPos.dy.toInt()}) - 长按检测已启动');
  }
  
  // 处理pointer move事件 - 支持长按和拖拽
  void _onPointerMove(Offset globalPos) {
    if (!widget.isCaller || !_remoteOn || _pointerDownPosition == null) return;
    
    final distance = (globalPos - _pointerDownPosition!).distance;
    
    // 如果移动距离超过阈值，取消长按检测并标记为拖拽
    if (distance > _webTapThreshold) {
      // 取消长按检测
      _cancelLongPressTimer();
      
      if (!_isDragging) {
        // 第一次确认为拖拽 - 立即发送swipStart提高响应速度
        _isDragging = true;
        print('🖱️ 检测到拖拽开始，距离: ${distance.toStringAsFixed(1)}px - 长按检测已取消');
        _onTouch(_pointerDownPosition!, 'swipStart');
      }
      
      // 立即发送滑动移动事件，不做额外延迟
      _onTouch(globalPos, 'swipMove');
    } else if (distance > 1.0) {
      // 显示微小移动，但不触发拖拽，保持长按检测
      print('🖱️ 微小移动，距离: ${distance.toStringAsFixed(1)}px (阈值: ${_webTapThreshold}px) - 长按检测继续');
    }
  }
  
  // 处理pointer up事件 - 支持长按、点击和拖拽
  void _onPointerUp(Offset globalPos) {
    // 检查是否有down数据
    if (_pointerDownPosition == null) {
      return;
    }
    
    // 取消长按检测定时器
    _cancelLongPressTimer();
    
    if (!widget.isCaller || !_remoteOn) {
      _clearPointerData();
      return;
    }
    
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final duration = currentTime - (_pointerDownTime ?? currentTime);
    final distance = (globalPos - _pointerDownPosition!).distance;
    
    // 判断事件类型：长按 > 拖拽 > 点击
    if (_longPressTriggered) {
      // 长按已经触发，这里是长按结束
      print('🖱️ 长按结束: (${globalPos.dx.toInt()}, ${globalPos.dy.toInt()})');
      _onTouch(globalPos, 'longPressEnd');
    } else if (_isDragging || distance > _webTapThreshold || duration > _webTapTimeThreshold) {
      // 滑动结束
      print('🖱️ 滑动结束: (${globalPos.dx.toInt()}, ${globalPos.dy.toInt()}) 距离:${distance.toInt()}px');
      _onTouch(globalPos, 'swipEnd');
    } else {
      // 普通点击
      print('🖱️ 点击: (${globalPos.dx.toInt()}, ${globalPos.dy.toInt()})');
      _onTouch(globalPos, 'tap');
    }
    
    _clearPointerData();
  }
  
  // 清理指针数据
  void _clearPointerData() {
    _pointerDownPosition = null;
    _pointerDownTime = null;
    _isDragging = false;
    _isLongPressing = false;
    _longPressTriggered = false;
    _cancelLongPressTimer();
  }
  
  // 启动长按检测定时器
  void _startLongPressTimer(Offset position) {
    _cancelLongPressTimer(); // 确保没有重复的定时器
    
    _longPressTimer = Timer(Duration(milliseconds: _longPressThreshold), () {
      if (_pointerDownPosition != null && !_isDragging && !_longPressTriggered) {
        _longPressTriggered = true;
        _isLongPressing = true;
        print('🖱️ 长按触发: (${position.dx.toInt()}, ${position.dy.toInt()}) - ${_longPressThreshold}ms');
        _onTouch(position, 'longPress');
      }
    });
  }
  
  // 取消长按检测定时器
  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _onTouch(Offset globalPos, String type) {
    // 只有主控端发送坐标，且在开启远程控制时响应
    if (!widget.isCaller || !_remoteOn) return;
    
    // 快速计算相对于视频区域的被控端坐标
    final position = getPosition(globalPos);
    if (position == null) return;
    
    final int mx = position.dx.toInt();
    final int my = position.dy.toInt();
    
    // 减少非必要的调试日志，只在关键事件时打印
    if (type == 'swipStart' || type == 'swipEnd' || type == 'tap' || type == 'longPress' || type == 'longPressEnd') {
      print('🎯 $type: ($mx, $my)');
    }
    
    if (_channel == 'cf') {
      _signaling?.sendCommand({
        'type': type,
        'x': mx,
        'y': my,
      });
    }
    // } else if (_channel == 'sdk') {
    //   // _rtcRoom?.sendRoomMessage(
    //   //   jsonEncode({
    //   //     'type': type,
    //   //     'x': mx,
    //   //     'y': my,
    //   //   }),
    //   // );
    // }
  }

  /// 将全局点击坐标转换为远端视频真实像素坐标（考虑 contain 模式 letterbox）
  Offset? getPosition(Offset clientPosition) {
    // 使用保存的分辨率或当前分辨率
    final effectiveWidth = _savedRemoteScreenWidth > 0 ? _savedRemoteScreenWidth : _remoteScreenWidth;
    final effectiveHeight = _savedRemoteScreenHeight > 0 ? _savedRemoteScreenHeight : _remoteScreenHeight;
    
    // 只有在已知远端分辨率时才计算
    if (effectiveWidth == 0 || effectiveHeight == 0) {
      print('⚠️ 远端分辨率未知，无法进行坐标转换');
      return null;
    }
    
    // 尝试获取当前视频容器
    final box = _videoKey.currentContext?.findRenderObject() as RenderBox?;
    
    if (box != null && _remoteHasVideo) {
      // 视频容器存在且有视频流时，计算并保存容器信息
      print('📱 视频容器存在，更新保存的容器信息');
      return _calculateAndSavePosition(clientPosition, box, effectiveWidth, effectiveHeight);
    } else if (_hasValidVideoContainerInfo) {
      // 视频容器不存在但有保存的信息时，使用保存的信息
      print('📱 视频容器不存在，使用保存的容器信息进行坐标转换');
      return _calculatePositionFromSaved(clientPosition, effectiveWidth, effectiveHeight);
    } else {
      // 没有任何容器信息，提示用户
      if (effectiveWidth > 0 && effectiveHeight > 0) {
        print('⚠️ 没有有效的视频容器信息，请先开启屏幕共享并等待画面显示后再操作');
      } else {
        print('⚠️ 远端分辨率未知，请先开启屏幕共享以校准坐标转换');
      }
      return null;
    }
  }

  /// 计算坐标并保存容器信息
  Offset? _calculateAndSavePosition(Offset clientPosition, RenderBox box, double remoteW, double remoteH) {
    final topLeft = box.localToGlobal(Offset.zero);
    final viewW = box.size.width;
    final viewH = box.size.height;
    
    // contain 模式下视频展示尺寸与偏移
    final scale = min(viewW / remoteW, viewH / remoteH);
    final dispW = remoteW * scale;
    final dispH = remoteH * scale;
    final offsetX = (viewW - dispW) / 2;
    final offsetY = (viewH - dispH) / 2;
    
    // 保存容器信息
    _savedVideoContainerTopLeft = topLeft;
    _savedVideoDisplayWidth = dispW;
    _savedVideoDisplayHeight = dispH;
    _savedVideoOffsetX = offsetX;
    _savedVideoOffsetY = offsetY;
    _hasValidVideoContainerInfo = true;
    
    // print('📱 保存容器信息: 位置=${topLeft.dx.toStringAsFixed(1)},${topLeft.dy.toStringAsFixed(1)}, '
    //       '容器=${viewW.toStringAsFixed(1)}x${viewH.toStringAsFixed(1)}, '
    //       '显示=${dispW.toStringAsFixed(1)}x${dispH.toStringAsFixed(1)}, '
    //       '偏移=${offsetX.toStringAsFixed(1)},${offsetY.toStringAsFixed(1)}');
    
    // 计算点击在视频显示区域内的坐标
    final localX = clientPosition.dx - topLeft.dx - offsetX;
    final localY = clientPosition.dy - topLeft.dy - offsetY;
    
    if (localX < 0 || localX > dispW || localY < 0 || localY > dispH) {
      print('⚠️ 点击超出视频显示区域: 点击=(${localX.toStringAsFixed(1)},${localY.toStringAsFixed(1)}), 区域=0,0-${dispW.toStringAsFixed(1)},${dispH.toStringAsFixed(1)}');
      return null;
    }
    
    // 映射到远端真实像素
    final mappedX = (localX / dispW) * remoteW;
    final mappedY = (localY / dispH) * remoteH;
    
    print('📱 坐标转换成功: 屏幕=(${clientPosition.dx.toStringAsFixed(1)},${clientPosition.dy.toStringAsFixed(1)}) -> '
          '本地=(${localX.toStringAsFixed(1)},${localY.toStringAsFixed(1)}) -> '
          '远端=(${mappedX.toStringAsFixed(1)},${mappedY.toStringAsFixed(1)})');
    
    return Offset(mappedX, mappedY);
  }

  /// 使用保存的容器信息计算坐标
  Offset? _calculatePositionFromSaved(Offset clientPosition, double remoteW, double remoteH) {
    final topLeft = _savedVideoContainerTopLeft!;
    final dispW = _savedVideoDisplayWidth!;
    final dispH = _savedVideoDisplayHeight!;
    final offsetX = _savedVideoOffsetX!;
    final offsetY = _savedVideoOffsetY!;
    
    // 计算点击在视频显示区域内的坐标
    final localX = clientPosition.dx - topLeft.dx - offsetX;
    final localY = clientPosition.dy - topLeft.dy - offsetY;
    
    if (localX < 0 || localX > dispW || localY < 0 || localY > dispH) {
      print('⚠️ 点击超出保存的视频显示区域: 点击=(${localX.toStringAsFixed(1)},${localY.toStringAsFixed(1)}), '
            '保存区域=0,0-${dispW.toStringAsFixed(1)},${dispH.toStringAsFixed(1)}');
      return null;
    }
    
    // 映射到远端真实像素
    final mappedX = (localX / dispW) * remoteW;
    final mappedY = (localY / dispH) * remoteH;
    
    print('📱 使用保存信息转换成功: 屏幕=(${clientPosition.dx.toStringAsFixed(1)},${clientPosition.dy.toStringAsFixed(1)}) -> '
          '本地=(${localX.toStringAsFixed(1)},${localY.toStringAsFixed(1)}) -> '
          '远端=(${mappedX.toStringAsFixed(1)},${mappedY.toStringAsFixed(1)})');
    
    return Offset(mappedX, mappedY);
  }



  /// 主动保存当前的视频容器信息（在收到视频流时调用）
  void _saveCurrentVideoContainerInfo() {
    // 确保有有效的分辨率信息
    final effectiveWidth = _savedRemoteScreenWidth > 0 ? _savedRemoteScreenWidth : _remoteScreenWidth;
    final effectiveHeight = _savedRemoteScreenHeight > 0 ? _savedRemoteScreenHeight : _remoteScreenHeight;
    
    if (effectiveWidth <= 0 || effectiveHeight <= 0) {
      print('📱 分辨率信息不完整，无法保存容器信息');
      return;
    }
    
    // 获取视频容器
    final box = _videoKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      print('📱 视频容器不存在，无法保存容器信息');
      return;
    }
    
    try {
      final topLeft = box.localToGlobal(Offset.zero);
      final viewW = box.size.width;
      final viewH = box.size.height;
      
      // contain 模式下视频展示尺寸与偏移
      final scale = min(viewW / effectiveWidth, viewH / effectiveHeight);
      final dispW = effectiveWidth * scale;
      final dispH = effectiveHeight * scale;
      final offsetX = (viewW - dispW) / 2;
      final offsetY = (viewH - dispH) / 2;
      
      // 保存容器信息
      _savedVideoContainerTopLeft = topLeft;
      _savedVideoDisplayWidth = dispW;
      _savedVideoDisplayHeight = dispH;
      _savedVideoOffsetX = offsetX;
      _savedVideoOffsetY = offsetY;
      _hasValidVideoContainerInfo = true;
      
      print('📱 主动保存容器信息成功: 位置=${topLeft.dx.toStringAsFixed(1)},${topLeft.dy.toStringAsFixed(1)}, '
            '容器=${viewW.toStringAsFixed(1)}x${viewH.toStringAsFixed(1)}, '
            '显示=${dispW.toStringAsFixed(1)}x${dispH.toStringAsFixed(1)}, '
            '偏移=${offsetX.toStringAsFixed(1)},${offsetY.toStringAsFixed(1)}');
    } catch (e) {
      print('📱 保存容器信息失败: $e');
    }
  }

  /// 优化节点树显示性能统计
  void _printNodeTreeStats() {
    if (_nodeRects.isEmpty) {
      print('📊 节点树统计: 无节点数据');
      return;
    }

    int smallNodes = 0, mediumNodes = 0, largeNodes = 0;
    double totalArea = 0;
    
    for (final node in _nodeRects) {
      final area = node.bounds.width * node.bounds.height;
      totalArea += area;
      
      if (area < 100) { // 小于100平方像素
        smallNodes++;
      } else if (area < 1000) { // 小于1000平方像素  
        mediumNodes++;
      } else {
        largeNodes++;
      }
    }
    
    print('📊 节点树性能统计:');
    print('   总节点数: ${_nodeRects.length}');
    print('   节点分布: 小型($smallNodes) 中型($mediumNodes) 大型($largeNodes)');
    print('   总覆盖面积: ${totalArea.toStringAsFixed(0)}px²');
    print('   平均节点面积: ${(totalArea / _nodeRects.length).toStringAsFixed(1)}px²');
    
    // 性能建议
    if (_nodeRects.length > 800) {
      print('💡 建议: 节点数量较多，可考虑进一步过滤小节点提升性能');
    } else if (_nodeRects.length < 50) {
      print('💡 建议: 节点数量较少，可尝试降低过滤条件显示更多控件');
    }
  }



  void _handleRemoteTouch(double rx, double ry, String type) {
    // 1. 记录日志
    print('收到远端$type: $rx, $ry');
    print('📲 触发点击: $rx, $ry');
    GestureChannel.handleMessage(jsonEncode({
      'type': type,
      'x': rx,
      'y': ry,
    }));
  }

  /// 处理接收到的视频帧
  // void _handleVideoFrame(screen.VideoFrame frame) {
  //   print('收到视频帧');
  //
  // }
  // Future<void> _initVideoEventHandler() async {
  //   /// The user receives this callback after the SDK receives the first frame of remote video decoding data.
  //   _videoHandler.onVideoDeviceStateChanged = (String deviceId,
  //       VideoDeviceType deviceType,
  //       MediaDeviceState deviceState,
  //       MediaDeviceError deviceError) {
  //     if (deviceType == VideoDeviceType.screenCaptureDevice) {
  //       if (deviceState == MediaDeviceState.started) {
  //         // 开始发布屏幕流（音视频）
  //         print('开始发布屏幕流');
  //         _rtcRoom?.publishScreen(MediaStreamType.video);
  //       } else if (deviceState == MediaDeviceState.stopped ||
  //           deviceState == MediaDeviceState.runtimeError) {
  //         // 停止发布
  //         print('停止发布屏幕流');
  //         _rtcRoom?.unpublishScreen(MediaStreamType.both);
  //       }
  //     }
  //   };
  //   _videoHandler.onFirstRemoteVideoFrameDecoded =
  //       (RemoteStreamKey streamKey, VideoFrameInfo videoFrameInfo) {
  //     print('onFirstRemoteVideoFrameDecoded: ${streamKey.uid}');
  //     String? uid = streamKey.uid;
  //     if (_firstRemoteRenderContext?.uid == uid ||
  //         _secondRemoteRenderContext?.uid == uid ||
  //         _thirdRemoteRenderContext?.uid == uid) {
  //       return;
  //     }
  //
  //     /// Sets the view to use when rendering a video stream from a specified remote user uid.
  //     if (_firstRemoteRenderContext == null) {
  //       setState(() {
  //         _firstRemoteRenderContext =
  //             RTCViewContext.remoteContext(roomId: widget.roomId, uid: uid);
  //       });
  //     } else if (_secondRemoteRenderContext == null) {
  //       setState(() {
  //         _secondRemoteRenderContext =
  //             RTCViewContext.remoteContext(roomId: widget.roomId, uid: uid);
  //       });
  //     } else if (_thirdRemoteRenderContext == null) {
  //       setState(() {
  //         _thirdRemoteRenderContext =
  //             RTCViewContext.remoteContext(roomId: widget.roomId, uid: uid);
  //       });
  //     } else {}
  //   };
  //
  //   /// Callback of warnings, see {https://pub.dev/documentation/byteplus_rtc/latest/api_bytertc_common_defines/WarningCode.html}.
  //   _videoHandler.onWarning = (WarningCode code) {
  //     print('warningCode: $code');
  //   };
  //
  //   /// Callback of errors, see {https://pub.dev/documentation/byteplus_rtc/latest/api_bytertc_common_defines/ErrorCode.html}.
  //   _videoHandler.onError = (ErrorCode code) {
  //     print('errorCode: $code');
  //   };
  // }
  //
  // Future<void> _initRoomEventHandler() async {
  //   print('✅ RTCRoomEventHandler 已绑定');
  //
  //   /// Callback for remote visible user joining the room.
  //   _roomHandler.onUserJoined = (UserInfo userInfo, int elapsed) {
  //     _remoteUid = userInfo.uid;
  //     print('onUserJoined: ${userInfo.uid}');
  //   };
  //   _roomHandler.onUserPublishScreen = (String uid, MediaStreamType type) {
  //     // 先订阅屏幕流（双流模式 both 包含音视频）
  //     _rtcRoom?.subscribeScreen(
  //       uid: uid,
  //       type: MediaStreamType.both,
  //     );
  //
  //     // 然后更新渲染上下文
  //     setState(() {
  //       _remoteScreenContext = RTCViewContext.remoteContext(
  //         roomId: widget.roomId,
  //         uid: uid,
  //         streamType: StreamIndex.screen,
  //       );
  //     });
  //   };
  //   _roomHandler.onRoomMessageReceived = (String uid, String message) {
  //     // msg.uid 是发送者 uid
  //     // msg.message 是你发过去的字符串
  //     print('收到来自 $uid 的消息：$message');
  //     _receivedMsg(message);
  //   };
  //
  //   _roomHandler.onUserPublishStream =
  //       (String uid, MediaStreamType type) async {
  //     print('📡 用户 $uid 发布了 $type，正在订阅...');
  //     // 订阅远端视频流
  //     await _rtcRoom?.subscribeStream(uid: uid, type: type);
  //     // 更新渲染上下文（只使用第一路流示例，可根据需要扩展）
  //     if (_firstRemoteRenderContext?.uid != uid) {
  //       setState(() {
  //         _firstRemoteRenderContext = RTCViewContext.remoteContext(
  //           roomId: widget.roomId,
  //           uid: uid,
  //         );
  //       });
  //     }
  //   };
  //
  //   /// Callback for remote visible user leaving the room.
  //   _roomHandler.onUserLeave = (String uid, UserOfflineReason reason) {
  //     print('onUserLeave: $uid reason: $reason');
  //     if (_firstRemoteRenderContext?.uid == uid) {
  //       setState(() {
  //         _firstRemoteRenderContext = null;
  //       });
  //       _rtcVideo?.removeRemoteVideo(uid: uid, roomId: widget.roomId);
  //     } else if (_secondRemoteRenderContext?.uid == uid) {
  //       setState(() {
  //         _secondRemoteRenderContext = null;
  //       });
  //       _rtcVideo?.removeRemoteVideo(uid: uid, roomId: widget.roomId);
  //     } else if (_thirdRemoteRenderContext?.uid == uid) {
  //       setState(() {
  //         _thirdRemoteRenderContext = null;
  //       });
  //       _rtcVideo?.removeRemoteVideo(uid: uid, roomId: widget.roomId);
  //     }
  //   };
  // }
  //
  // Future<void> _receivedMsg(String msg) async {
  //   print('收到消息：$msg');
  //   // 尝试解析成 JSON
  //   dynamic data;
  //   try {
  //     data = jsonDecode(msg);
  //   } catch (e) {
  //     print('⚠️ 非 JSON 格式消息，忽略');
  //     return;
  //   }
  //
  //   final String? type = data['type'] as String?;
  //   switch (type) {
  //     // —— 手势事件 ——
  //     case 'tap':
  //     case 'swipStart':
  //     case 'swipMove':
  //     case 'swipEnd':
  //       final double remoteX = (data['x'] as num).toDouble();
  //       final double remoteY = (data['y'] as num).toDouble();
  //       _handleRemoteTouch(remoteX, remoteY, type!);
  //       break;
  //     case 'tapBack':
  //       _handleRemoteTouch(0, 0, 'tapBack');
  //       break;
  //     case 'tapHome':
  //       _handleRemoteTouch(0, 0, 'tapHome');
  //       break;
  //     case 'tapRecent':
  //       _handleRemoteTouch(0, 0, 'tapRecent');
  //       break;
  //
  //     // —— 屏幕共享控制 ——
  //     case 'start_screen_share':
  //       _screenShareOn = false;
  //       _toggleScreenShare();
  //       break;
  //     case 'stop_screen_share':
  //       _screenShareOn = true;
  //       _toggleScreenShare();
  //       break;
  //
  //     // —— 屏幕分辨率信息 ——
  //     case 'screen_info':
  //       final double w = (data['width'] as num).toDouble();
  //       final double h = (data['height'] as num).toDouble();
  //       setState(() {
  //         _remoteScreenWidth = w;
  //         _remoteScreenHeight = h;
  //       });
  //       print('📺 已更新远端分辨率：${w.toInt()}x${h.toInt()}');
  //       break;
  //
  //     // —— CF 模式下的刷新屏幕请求 ——
  //     case 'refresh_screen':
  //       print('📺 收到刷新屏幕请求');
  //       if (_screenStream != null) {
  //         final track = _screenStream!.getVideoTracks().first;
  //         track.enabled = false;
  //         await Future.delayed(const Duration(milliseconds: 50));
  //         track.enabled = true;
  //       }
  //       break;
  //
  //     // —— 退出房间 ——
  //     case 'exit_room':
  //       print('📺 收到退出房间请求');
  //       if (!mounted) return;
  //       Navigator.of(context).popUntil((route) => route.isFirst);
  //       break;
  //
  //     // —— 麦克风控制 ——
  //     case 'stop_speakerphone':
  //       print('📺 收到关闭对方麦克风请求');
  //       _contributorSpeakerphoneOn = false;
  //       _toggleSpeakerphone();
  //       setState(() {});
  //       break;
  //     case 'start_speakerphone':
  //       print('📺 收到打开对方麦克风请求');
  //       _contributorSpeakerphoneOn = true;
  //       _toggleSpeakerphone();
  //       setState(() {});
  //       break;
  //
  //     // —— 来电拦截 ——
  //     case 'on_intercept_call':
  //       print('📺 收到开启电话拦截请求');
  //       _interceptOn = true;
  //       _toggleIntercept(_interceptOn);
  //       break;
  //     case 'off_intercept_call':
  //       print('📺 收到关闭电话拦截请求');
  //       _interceptOn = false;
  //       _toggleIntercept(_interceptOn);
  //       break;
  //
  //     // —— 远程控制 ——
  //     case 'remote_control_on':
  //       print('📺 收到开启远程控制请求');
  //       await BrightnessManager.hasWriteSettingsPermission();
  //       await Future.delayed(const Duration(milliseconds: 100));
  //       await const AndroidIntent(
  //         action: 'android.settings.ACCESSIBILITY_SETTINGS',
  //       ).launch();
  //       if (!await FlutterOverlayWindow.isPermissionGranted()) {
  //         await FlutterOverlayWindow.requestPermission();
  //       }
  //       setState(() {
  //         _remoteOn = true;
  //       });
  //       break;
  //     case 'remote_control_off':
  //       print('📺 收到关闭远程控制请求');
  //       await const AndroidIntent(
  //         action: 'android.settings.ACCESSIBILITY_SETTINGS',
  //       ).launch();
  //       setState(() {
  //         _remoteOn = false;
  //       });
  //       break;
  //
  //     // —— 黑屏 ——
  //     case 'showBlack':
  //       print('📺 收到显示黑屏请求');
  //       await BrightnessManager.hasWriteSettingsPermission();
  //       if (!await FlutterOverlayWindow.isPermissionGranted()) {
  //         await FlutterOverlayWindow.requestPermission();
  //       }
  //       await FlutterOverlayWindow.showOverlay(
  //         flag: OverlayFlag.clickThrough,
  //         height: 5000,
  //       );
  //       await Future.delayed(const Duration(milliseconds: 100));
  //       try {
  //         await BrightnessManager.setBrightness(0.0);
  //         print('已将亮度调到最低');
  //       } catch (e) {
  //         print('⚡ 调整亮度失败: $e');
  //       }
  //       setState(() {
  //         _showBlack = true;
  //       });
  //       break;
  //     case 'hideBlack':
  //       print('📺 收到隐藏黑屏请求');
  //       await FlutterOverlayWindow.closeOverlay();
  //       await BrightnessManager.setBrightness(0.5);
  //       setState(() {
  //         _showBlack = false;
  //       });
  //       break;
  //
  //     // —— 切换线路 / 刷新 ——
  //     case 'refresh_sdk':
  //       if (!widget.isCaller) {
  //         print('📺 收到刷新请求 (切到 SDK)');
  //         _channel = 'sdk';
  //         await _refresh();
  //       }
  //       break;
  //     case 'refresh_cf':
  //       if (!widget.isCaller) {
  //         print('📺 收到刷新请求 (切到 CF)');
  //         _channel = 'cf';
  //         await _refresh();
  //       }
  //       break;
  //
  //     default:
  //       print('⚠️ 未知消息类型：$type');
  //   }
  // }
  //
  // Future<void> _initVideoAndJoinRoom() async {
  //   /// Create engine objects.
  //   _rtcVideo = await RTCVideo.createRTCVideo(
  //       RTCVideoContext(widget.certificate_sdk!, eventHandler: _videoHandler));
  //
  //   if (_rtcVideo == null) {
  //     print('❌ 创建 RTCVideo 失败');
  //     return;
  //   }
  //   final tokenData = await Api.get_token(widget.roomId);
  //   print('获取 token: $tokenData');
  //   var rtcToken = tokenData['token'];
  //   _Uid = tokenData['userId'].toString();
  //
  //   /// Start pushing multiple video streams and set the video parameters when pushing multiple streams,
  //   /// Including resolution, frame rate, bit rate, zoom mode, fallback strategy when the network is poor, etc.
  //   // VideoEncoderConfig solution = VideoEncoderConfig(
  //   //   width: 360,
  //   //   height: 640,
  //   //   frameRate: 15,
  //   //   maxBitrate: 800,
  //   //   encoderPreference: VideoEncoderPreference.maintainFrameRate,
  //   // );
  //   // _rtcVideo?.setMaxVideoEncoderConfig(solution);
  //
  //   /// Sets the view used when rendering local videos.
  //   // setState(() {
  //   //   _localRenderContext = RTCViewContext.localContext(uid: _Uid!);
  //   // });
  //
  //   /// Enable internal video capture immediately. The default is off.
  //   _rtcVideo?.startVideoCapture();
  //
  //   /// Enables internal audio capture. The default is off.
  //   _rtcVideo?.startAudioCapture();
  //
  //   // /// 开启音频音量报告（调试是否采集到声音）
  //   // await _rtcVideo?.enableAudioPropertiesReport(AudioPropertiesConfig(
  //   //   interval: 200, // 每 200ms 报告一次音量
  //   //   localMainReportMode: AudioReportMode.normal, // 正常精度即可
  //   //   audioReportMode: AudioPropertiesMode.microphone, // 麦克风输入
  //   //   enableVad: false,  // 暂时不启用语音活动检测（非必须）
  //   // ));
  //   //
  //   // _videoHandler.onLocalAudioPropertiesReport = (List<LocalAudioPropertiesInfo> list) {
  //   //   for (final info in list) {
  //   //     print('🎤 本地用户 ${info.streamIndex} 音量: ${info.audioPropertiesInfo?.linearVolume}');
  //   //   }
  //   // };
  //   /// Create a room.
  //   _rtcRoom = await _rtcVideo?.createRTCRoom(widget.roomId);
  //
  //   /// Set room event callback handler
  //   _rtcRoom?.setRTCRoomEventHandler(_roomHandler);
  //
  //   /// Join the room.
  //   UserInfo userInfo = UserInfo(uid: _Uid!);
  //   RoomConfig roomConfig = RoomConfig(
  //       isAutoPublish: true,
  //       isAutoSubscribeAudio: true,
  //       isAutoSubscribeVideo: true);
  //   print('👉 我将加入房间 roomId=${widget.roomId}, uid=$_Uid');
  //
  //   int? ret = await _rtcRoom?.joinRoom(
  //     token: rtcToken,
  //     userInfo: userInfo,
  //     roomConfig: roomConfig,
  //   );
  //   print('加入房间返回: $ret');
  // }

  /// 启动 WebRTC 通话
  Future<void> _startCall() async {
    if (_channel == 'cf') {
      print('🎤 获取本地音频流');
      final audioStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          // 基础处理
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          // 高通滤波，去除麦克风低频呼吸声
          'highpassFilter': true,
          // Opus 编码参数
          'opusFec': true, // 前向纠错
          // 'opusDtx': true, // 静音传输时省带宽
          // 采样和声道
          'sampleRate': 48000,
          'sampleSize': 16,
          'channelCount': 1,
        },
        'video': false,
      });
      _localStream = audioStream;
      await _prepareAudioSession();
      print('⚙️ 创建 PeerConnection');
      // final username = _channel == 'cf'
      //     ? widget.appid_cf // Cloudflare 用 token 作为用户名
      //     // : 'test'; // ryxma 上你配置的 coturn 用户名
      //     : widget.appid_cf;
      //
      // final credential = _channel == 'cf'
      //     ? widget.certificate_cf // Cloudflare 的签名
      //     // : 'test123456789.'; // ryxma coturn 密码
      //     : widget.certificate_cf; // ryxma 上你配置的 coturn 密码
      // final urls = _channel == 'cf'
      //     ? [
      //         'stun:stun.cloudflare.com:3478',
      //         'turn:turn.cloudflare.com:3478?transport=udp',
      //         'turn:turn.cloudflare.com:3478?transport=tcp',
      //         'turns:turn.cloudflare.com:5349?transport=tcp',
      //       ]
      //     : [
      //         // 'stun:stun.miwifi.com:3478',
      //         // 'turn:18.162.123.70:3478?transport=udp',
      //         // 'turn:18.162.123.70:3478?transport=tcp',
      //         'stun:stun.cloudflare.com:3478',
      //         'turn:turn.cloudflare.com:3478?transport=udp',
      //         'turn:turn.cloudflare.com:3478?transport=tcp',
      //         'turns:turn.cloudflare.com:5349?transport=tcp',
      //       ];
      final config = {
        'iceServers': [
          {
            'urls': [
              'stun:stun.cloudflare.com:3478',
              'turn:turn.cloudflare.com:3478?transport=udp',
              'turn:turn.cloudflare.com:3478?transport=tcp',
              'turns:turn.cloudflare.com:5349?transport=tcp',
            ],
            'username': widget.appid_cf,
            'credential': widget.certificate_cf,
            // 'username': widget.appid_cf,
            // 'username': 'test',
            // 'credential': widget.certificate_cf,
            // 'credential': 'test123456789.',
          }
        ],
        // 新增这一行：只走 relay
        // 'iceTransportPolicy': 'relay',
        // 'iceTransportPolicy': 'all',
        // 'iceTransportPolicy': _channel == 'cf' ? 'all' : 'relay',
        'iceTransportPolicy': _icerefresh ? 'relay' : 'all',
      };
      try {
        _pc = await createPeerConnection(config, {
          'sdpSemantics': 'unified-plan',
          'optional': [
            {'googCpuOveruseDetection': false},
          ]
        });
        print('☑️ PeerConnection 创建成功,当前channel: $_channel');

        _pc?.onIceConnectionState = (RTCIceConnectionState state) async {
          print('🛰️ ICE连接状态变化: $state (重连状态: _isrefresh=$_isrefresh, _canRefresh=$_canRefresh)');
          
          // 更新当前ICE状态
          if (mounted) {
            setState(() {
              _currentIceState = state;
            });
          }
          

          
          // 🔄 处理连接断开时的状态重置
          if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
            if (mounted) {
              setState(() {
                // 清理渲染器但保持状态变量
                if (widget.isCaller) {
                  print('🎮 主控端：连接断开，暂时清理渲染器但保持状态变量');
                  _remoteRenderer.srcObject = null; // 清理远端渲染器
                  // 保持状态变量不变，等待后续处理
                } else {
                  print('📱 被控端：连接断开，暂时清理渲染器但保持状态变量');
                  _remoteRenderer.srcObject = null;
                  // 🎯 被控端也保持状态变量，等重连结果确定
                }
              });
            }
          }
          
          // 保留原有的关键状态处理
          if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
              state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
            if (mounted) {
              setState(() {
            _isrefresh = false;
            _icerefresh = false;
              });
              
              // 主控端连接成功后检查远端流状态
              if (widget.isCaller && _savedScreenShareOn) {
                Future.delayed(const Duration(milliseconds: 1500), () async {
                  if (mounted && !_remoteHasVideo && _savedScreenShareOn) {
                    print('🎮 主控端：连接成功后检查远端流状态');
                    await _checkAndRestoreRemoteStream();
                  }
                });
              }
            }
            _printSelectedCandidateInfo();
          }
          
          // 🔄 处理ICE连接失败，执行硬重连
          if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
            if (mounted && !_isrefresh && _canRefresh && widget.isCaller) {
              print('❌ ICE连接失败，准备执行硬重连');
              setState(() {
                _remoteHasVideo = false;
                _remoteHasAudio = false;
                _remoteRenderer.srcObject = null;
              });
              
              // 🚀 优化：减少延迟到500ms，加快响应速度
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && _pc != null && !_isrefresh && _canRefresh) {
                  print('🔄 ICE连接失败，开始执行硬重连');
                  // 先关闭可能存在的其他loading
                  if (EasyLoading.isShow) {
                    EasyLoading.dismiss();
                  }
                  EasyLoading.showToast('连接失败，正在重新连接...', duration: const Duration(seconds: 1));
                  _performHardReconnect();
                }
              });
            } else if (_isrefresh) {
              print('🔄 ICE连接失败，但硬重连已在进行中，跳过');
            }
          }

          if (state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
            if (!mounted) return;
            setState(() {
              _remoteHasVideo = false;
              _remoteHasAudio = false;
              // 🔄 连接关闭时，主控端也要重置屏幕共享状态
              if (widget.isCaller) {
                _screenShareOn = false;
                print('🎮 主控端：连接关闭，重置屏幕共享状态');
              }
            });
          }
        };
      } catch (e) {
        print('❌ 创建 PeerConnection 失败: $e');
        return;
      }

      // ➕ 添加本地音轨并优化编码参数
      print('➕ 添加本地音轨');
      for (var track in audioStream.getAudioTracks()) {
        // 把音轨加进 PeerConnection
        final sender = await _pc!.addTrack(track, audioStream);

        // 拿到当前参数
        final params = sender.parameters;
        // 只对 audio sender 做限速
        params.encodings = [
          RTCRtpEncoding(
            maxBitrate: 64 * 1000, // 64kbps 够清晰又省带宽
          )
        ];
        // 应用参数
        final ok = await sender.setParameters(params);
        print('🔧 音频编码参数已更新: $ok');
      }

      _pc!.onTrack = (event) {
        print('🎧 收到远端流 - 流数量: ${event.streams.length}');
        if (event.streams.isEmpty) {
          print('⚠️ onTrack事件中没有流');
          return;
        }
        
        final stream = event.streams[0];
        final hasVideo = stream.getVideoTracks().isNotEmpty;
        final hasAudio = stream.getAudioTracks().isNotEmpty;
        
        print('📺 远端流分析: 视频track数=${stream.getVideoTracks().length}, 音频track数=${stream.getAudioTracks().length}');
        print('🎬 流内容: hasVideo=$hasVideo, hasAudio=$hasAudio');
        
        setState(() {
          _remoteRenderer.srcObject = stream;
          print('远端开始推送视频');
          _remoteHasVideo = hasVideo;
          _remoteHasAudio = hasAudio;
          
          // 🔄 关键：主控端收到视频流时，更新屏幕共享状态
          if (hasVideo && widget.isCaller) {
            print('🎮 主控端：收到屏幕共享视频流，更新状态 (之前状态: $_screenShareOn)');
            _screenShareOn = true; // 主控端看到视频就认为屏幕共享开启了
            print('🎮 主控端：屏幕共享状态已更新为: $_screenShareOn');
          }
        });
        
        // 如果收到视频流，延迟一下主动保存容器信息
        if (hasVideo) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _saveCurrentVideoContainerInfo();
          });
        }
      };
      _pc!.onIceCandidate = (cand) {
        print('📡 本地 ICE Candidate');
        _signaling?.sendCandidate(cand);
      };
      if (!_isrefresh) {
        print('🌐 初始化信令');
        _signaling = Signaling(
          roomId: widget.roomId,
          isCaller: widget.isCaller,
          pc: _pc!,
          onRemoteSDP: _onRemoteSDP,
          onRemoteCandidate: _onRemoteCandidate,
          onRemoteCommand: (cmd) async {
            if (cmd['type'] == 'screen_info') {
              setState(() {
                _remoteScreenWidth = (cmd['width'] as num).toDouble();
                _remoteScreenHeight = (cmd['height'] as num).toDouble();
                // 保存分辨率信息，用于节点树显示
                _savedRemoteScreenWidth = _remoteScreenWidth;
                _savedRemoteScreenHeight = _remoteScreenHeight;
                print('📏 保存屏幕分辨率: ${_savedRemoteScreenWidth}x$_savedRemoteScreenHeight');
              });
              
              // 分辨率信息更新后，如果有视频流，主动保存容器信息
              if (_remoteHasVideo) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  _saveCurrentVideoContainerInfo();
                });
              }
            } else if (!widget.isCaller && cmd['type'] == 'refresh_screen') {
              print('📺 收到刷新屏幕请求');
              if (_screenStream != null) {
                // 拿到当前共享的 video track
                final track = _screenStream!.getVideoTracks().first;
                // 先关掉，等一下再打开
                track.enabled = false;
                await Future.delayed(const Duration(milliseconds: 50));
                track.enabled = true;
              }
            } else if (!widget.isCaller &&
                cmd['type'] == 'start_screen_share') {
              print('📺 收到屏幕共享请求 - 开始处理');
              print('🔍 被控端调试: 当前_screenShareOn=$_screenShareOn, _screenStream=${_screenStream != null}, _screenSender=${_screenSender != null}');
              print('🔍 被控端调试: _savedScreenShareOn=$_savedScreenShareOn, _savedScreenStream=${_savedScreenStream != null}');
              print('🔍 被控端调试: _pc为null? ${_pc == null}');
              
              // 🎯 智能检查：区分正常重复请求和硬重连后的恢复请求
              if (_screenShareOn && _screenStream != null && _screenSender != null) {
                // 屏幕共享正常运行，只需要重新发送分辨率信息
                print('📺 被控端：屏幕共享正常运行，重新发送分辨率信息');
                if (mounted) {
                  final mq = MediaQuery.of(context);
                  final logicalSize = mq.size;
                  final dpr = mq.devicePixelRatio;
                  final int width = (logicalSize.width * dpr).toInt();
                  final int height = (logicalSize.height * dpr).toInt();
                  
                  _signaling?.sendCommand({
                    'type': 'screen_info',
                    'width': width,
                    'height': height,
                  });
                  print('📺 重新发送屏幕分辨率: $width x $height');
                }
                return;
              } else if (_screenShareOn && (_screenStream == null || _screenSender == null)) {
                // 🎯 检测到硬重连后的恢复场景：状态为true但流对象缺失
                print('📺 被控端：检测到硬重连后的恢复场景，尝试智能恢复');
                try {
                  await _restoreScreenShareForJoiner();
                  return;
                } catch (e) {
                  print('❌ 智能恢复失败，继续标准流程: $e');
                  // 继续执行下面的标准开启流程
                }
              }
              
              print('📺 被控端：当前屏幕共享状态=false，准备开启');
              _screenShareOn = false; // 确保状态一致性
              
              if (!kIsWeb && Platform.isAndroid) {
                if (_isAppInForeground) {
                  // 前台时立即共享
                  print('📺 App 在前台，开始共享屏幕');
                  await _startScreenShareSafely();
                } else {
                  // 后台时先标记，等回到前台再执行
                  print('📺 App 不在前台，延迟执行屏幕共享');
                  _pendingStartScreen = true;
                }
              } else {
                if (_isAppInForeground) {
                  // 前台时立即共享
                  print('📺 App 在前台,回到后台后再执行屏幕共享');
                  _pendingStartScreen = true;
                  await _iosScreenShareChannel.invokeMethod('suspendApp');
                } else {
                  // 后台时先标记，等回到前台再执行
                  print('📺 App 在后台，直接执行屏幕共享');
                  await _prepareAudioSession();
                  await _startScreenShareSafely();
                }
                print('ios准备执行屏幕共享');
              }
            } else if (cmd['type'] == 'stop_screen_share') {
              print('📺 收到停止屏幕共享请求');
              
              // 🎯 关键修复：被控端收到停止命令时，真正停止屏幕捕获
              if (_screenShareOn) {
                print('🖥️ 被控端：根据主控端请求真正停止屏幕共享');
                
                // 停止屏幕流和清理资源
                if (_screenSender != null) {
                  await _pc!.removeTrack(_screenSender!);
                  _screenSender = null;
                  print('🖥️ 已移除屏幕track');
                }
                
                if (_screenStream != null) {
                  for (var track in _screenStream!.getTracks()) {
                    track.stop();
                    print('🖥️ 已停止屏幕track: ${track.id}');
                  }
                  _screenStream = null;
                  print('🖥️ 已清理屏幕流');
                }
                
                // 清理保存的屏幕流（如果有）
                if (_savedScreenStream != null) {
                  for (var track in _savedScreenStream!.getTracks()) {
                    track.stop();
                  }
                  _savedScreenStream = null;
                  print('🖥️ 已清理保存的屏幕流');
                }
                
                // 重新协商以移除视频流
                try {
                  final offer = await _pc!.createOffer();
                  await _pc!.setLocalDescription(offer);
                  _signaling?.sendSDP(offer);
                  print('📡 被控端停止屏幕共享后的offer已发送');
                } catch (e) {
                  print('❌ 被控端停止屏幕共享重新协商失败: $e');
                }
              }
              
              setState(() {
                _screenShareOn = false;
                _remoteHasVideo = false;
                print('📺 屏幕共享已停止，切换到纯音频模式');
                
                // 立即检查音频状态，确保UI正确显示
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    _hasAnyAudio(); // 这会同步更新 _remoteHasAudio 状态
                  }
                });
              });
            } else if (cmd['type'] == 'exit_room') {
              print('📺 收到退出房间请求');
              // if (!mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else if (cmd['type'] == 'stop_speakerphone') {
              print('📺 收到关闭对方麦克风请求');
              _contributorSpeakerphoneOn = false;
              _toggleSpeakerphone();
              setState(() {});
            } else if (cmd['type'] == 'start_speakerphone') {
              print('📺 收到打开对方麦克风请求');
              _contributorSpeakerphoneOn = true;
              _toggleSpeakerphone();
              setState(() {});
            } else if (cmd['type'] == 'on_intercept_call') {
              print('📺 收到开启电话拦截请求');
              _interceptOn = true;
              _toggleIntercept(_interceptOn);
            } else if (cmd['type'] == 'off_intercept_call') {
              print('📺 收到关闭电话拦截请求');
              _interceptOn = false;
              _toggleIntercept(_interceptOn);
            } else if (cmd['type'] == 'remote_control_on') {
              print('📺 收到开启远程控制请求');
              //申请修改系统设置权限
              // await BrightnessManager.hasWriteSettingsPermission();
              //延迟0.1秒，确保权限申请成功
              // await Future.delayed(const Duration(milliseconds: 100));
              const intent = AndroidIntent(
                action: 'android.settings.ACCESSIBILITY_SETTINGS',
              );
              await intent.launch();
              // if (!await FlutterOverlayWindow.isPermissionGranted()) {
              //   await FlutterOverlayWindow.requestPermission();
              // }
              setState(() {
                _remoteOn = true;
              });
            } else if (cmd['type'] == 'remote_control_off') {
              print('📺 收到关闭远程控制请求');
              const intent = AndroidIntent(
                action: 'android.settings.ACCESSIBILITY_SETTINGS',
              );
              intent.launch();
              setState(() {
                _remoteOn = false;
              });
            } else if (cmd['type'] == 'showBlack') {
              print('📺 收到显示黑屏请求');
              
              // 🎯 保存当前亮度状态
              await BrightnessManager.saveOriginalState();
              
              //申请修改系统设置权限
              await BrightnessManager.hasWriteSettingsPermission();
              
              //申请悬浮窗权限
              if (!await FlutterOverlayWindow.isPermissionGranted()) {
                await FlutterOverlayWindow.requestPermission();
              }
              if (!await FlutterOverlayWindow.isPermissionGranted()) {
                print('⚠️ 悬浮窗权限未授予，黑屏功能可能不完整');
                // 即使没有悬浮窗权限，也继续设置亮度
              } else {
                await FlutterOverlayWindow.showOverlay(
                  flag: OverlayFlag.clickThrough,
                  height: 5000,
                );
                print('✅ 黑屏悬浮窗已显示');
              }
              
              try {
                // 🎯 使用智能黑屏亮度控制
                print('🔧 开始设置黑屏亮度...');
                await BrightnessManager.setBlackScreenBrightness();
                print('✅ 黑屏亮度设置完成');
              } catch (e) {
                print('⚡ 设置黑屏亮度失败: $e');
              }
              
              setState(() {
                _showBlack = true;
              });
            } else if (cmd['type'] == 'hideBlack') {
              print('📺 收到隐藏黑屏请求');
              
              // 关闭悬浮窗
              try {
                await FlutterOverlayWindow.closeOverlay();
                print('✅ 黑屏悬浮窗已关闭');
              } catch (e) {
                print('⚠️ 关闭悬浮窗失败: $e');
              }
              
              // 🎯 恢复原始亮度状态
              try {
                await BrightnessManager.restoreOriginalState();
                print('✅ 亮度已恢复到原始状态');
              } catch (e) {
                print('⚡ 恢复亮度失败，使用默认值: $e');
                // 备用方案：设置为中等亮度
                await BrightnessManager.setBrightness(0.5);
              }

              setState(() {
                _showBlack = false;
              });
            } else if (cmd['type'] == 'tap' ||
                cmd['type'] == 'longPress' ||
                cmd['type'] == 'longPressEnd' ||
                cmd['type'] == 'swipStart' ||
                cmd['type'] == 'swipMove' ||
                cmd['type'] == 'swipEnd') {
              final String type = cmd['type'] as String;
              final double remoteX = (cmd['x'] as num).toDouble();
              final double remoteY = (cmd['y'] as num).toDouble();
              _handleRemoteTouch(remoteX, remoteY, type);
            } else if (cmd['type'] == 'tapBack' ||
                cmd['type'] == 'tapHome' ||
                cmd['type'] == 'tapRecent') {
              final String type = cmd['type'] as String;
              const double remoteX = 0;
              const double remoteY = 0;
              _handleRemoteTouch(remoteX, remoteY, type);
            } else if (cmd['type'] == 'key_input') {
              // 处理键盘输入命令 - 只有被控端处理
              if (!widget.isCaller) {
                final String text = cmd['text'] as String;
                
                // 根据不同类型显示不同的日志
                String logText = text;
                if (text == 'BACKSPACE') {
                  logText = '退格键';
                } else if (text == 'ENTER') {
                  logText = '回车键';
                } else if (text.startsWith('PASTE:')) {
                  final pasteContent = text.substring(6);
                  logText = '黏贴内容: "${pasteContent.length > 30 ? pasteContent.substring(0, 30) + '...' : pasteContent}"';
                }
                
                print('📱 收到键盘输入命令: $logText');
                GestureChannel.handleMessage(jsonEncode({
                  'type': 'key_input',
                  'text': text,
                }));
              }
            } else if (cmd['type'] == 'refresh_sdk') {
              if (!widget.isCaller) {
                print('📺 收到刷新请求 - 直接执行硬重连');
                _channel = 'sdk';
                await _performHardReconnect();
              }
            } else if (cmd['type'] == 'refresh_cf') {
              if (!widget.isCaller) {
                print('📺 收到刷新请求 - 直接执行硬重连');
                _channel = 'cf';
                await _performHardReconnect();
              }
            } else if (cmd['type'] == 'show_view') {
              const platform = MethodChannel('accessibility_channel');
              try {
                print('📱 开始获取页面节点树...');
                
                // 添加超时保护，防止无限等待
                final treeJson = await platform
                    .invokeMethod<String>('dumpAccessibilityTree')
                    .timeout(const Duration(seconds: 5), onTimeout: () {
                      throw TimeoutException('获取节点树超时', const Duration(seconds: 5));
                    });
                
                if (treeJson == null || treeJson.isEmpty) {
                  print('⚠️ 获取到空的节点树数据');
                  return;
                }
                
                // 检查数据大小，避免发送过大的数据（已优化）
                if (treeJson.length > 2 * 1024 * 1024) { // 超过2MB（增加限制）
                  print('⚠️ 节点树数据过大 (${treeJson.length} 字符)，跳过发送');
                  return;
                }
                
                print('📱 节点树获取成功，大小: ${treeJson.length} 字符');
                _signaling?.sendCommand(
                  {'type': 'accessibility_tree', 'data': treeJson},
                );
              } catch (e) {
                print('❌ 无障碍 dump 失败: $e');
                // 发送错误信息而不是崩溃
                _signaling?.sendCommand(
                  {'type': 'accessibility_tree_error', 'error': e.toString()},
                );
              }
            } else if (cmd['type'] == 'accessibility_tree_error') {
              final error = cmd['error'] as String;
              print('❌ 对方设备节点树获取失败: $error');
              
              // 特殊处理无障碍服务相关错误
              if (error.contains('rootInActiveWindow') || error.contains('无障碍')) {
                print('📄 检测到无障碍服务问题，延迟重试...');
                EasyLoading.showToast('远控服务正在恢复，请稍候...', duration: const Duration(seconds: 2));
                
                // 延迟重试
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted && _showNodeRects && _signaling != null) {
                    print('📄 重新尝试页面读取...');
                    _signaling!.sendCommand({'type': 'show_view'});
                  }
                });
              }
              
              setState(() {
                _nodeRects.clear(); // 清空节点显示
              });
            } else if (cmd['type'] == 'accessibility_tree') {
              try {
                final treeJson = cmd['data'] as String;
                print('📱 收到节点树数据，大小: ${treeJson.length} 字符');
                
                // 检查是否是错误信息
                if (treeJson.startsWith('⚠️')) {
                  print('⚠️ 收到节点树错误: $treeJson');
                  
                  // 特殊处理rootInActiveWindow问题
                  if (treeJson.contains('rootInActiveWindow')) {
                    print('📄 检测到rootInActiveWindow问题，可能是无障碍服务未就绪');
                    // 延迟重试页面读取
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted && _showNodeRects && _signaling != null) {
                        print('📄 重新尝试页面读取...');
                        _signaling!.sendCommand({'type': 'show_view'});
                      }
                    });
                  }
                  
                  setState(() {
                    _nodeRects.clear(); // 清空之前的节点
                  });
                  return;
                }
                
                final parsed = jsonDecode(treeJson);
                print('📱 原始JSON解析完成，开始提取节点...');
                
                final nodes = <_AccessibilityNode>[];
                _extractNodes(parsed, nodes);
                print('📱 节点提取完成');
                
                // 统计不同类型的节点
                int textNodes = 0, editableNodes = 0, clickableNodes = 0, borderOnlyNodes = 0;
                for (final node in nodes) {
                  if (node.label == '') {
                    editableNodes++;
                  } else if (node.label == '') {
                    clickableNodes++;
                  } else if (node.label.isEmpty) {
                    borderOnlyNodes++;
                  } else {
                    textNodes++;
                  }
                }
                
                print('📱 解析节点统计: 总数=${nodes.length}, 文本节点=$textNodes, 可编辑控件=$editableNodes, 可点击控件=$clickableNodes, 仅边框节点=$borderOnlyNodes');
                setState(() {
                  _nodeRects = nodes;
                });
                
                // 提供性能统计
                _printNodeTreeStats();
              } catch (e) {
                print('❌ 解析节点树失败: $e');
                setState(() {
                  _nodeRects.clear(); // 清空之前的节点
                });
              }
              // final treeJson = cmd['data'] as String;
              // void printLongText(String text, {int chunkSize = 800}) {
              //   for (var i = 0; i < text.length; i += chunkSize) {
              //     final end = (i + chunkSize < text.length)
              //         ? i + chunkSize
              //         : text.length;
              //     debugPrint(text.substring(i, end));
              //   }
              // }
              // printLongText('收到页面节点树: $treeJson');
            }
            else {
              print('📺 收到未知命令: $cmd');
            }
          },
          onDisconnected: () {
            print('⚡️ 信令断开了，显示提示...');
            // EasyLoading.show(status: '连接中...');
          },
          onReconnected: () async {
            print('✅ 信令重连成功');
            // 如果我是加入者，重连后主动再发一次 Offer
            if (!widget.isCaller) {
              print('📤 重连后加入者重新发送 Offer');
              final offer = await _pc!.createOffer();
              await _pc!.setLocalDescription(offer);
              _signaling!.sendSDP(offer);
            }
            // EasyLoading.showSuccess('重连成功');
          },
        );
        await _signaling!.connect();
      }
      if (!widget.isCaller) {
        print('📤 加入者发送 Offer');
        final offer = await _pc!.createOffer();
        await _pc!.setLocalDescription(offer);
        _signaling!.sendSDP(offer);
        print('📤 加入者已发送 Offer: $offer');
      } else {
        print('⏳ 创建者等待远端 Offer');
      }
      // WebRTC模式下，确保收到第一帧时UI会刷新，并保存容器信息
      _remoteRenderer.onResize = () {
        setState(() {});
        // 视频尺寸变化时，延迟保存容器信息
        if (_remoteHasVideo) {
          Future.delayed(const Duration(milliseconds: 200), () {
            _saveCurrentVideoContainerInfo();
          });
        }
      };
    }
    // if (_channel == 'sdk') {
    //   if (!_isrefresh) {
    //     print('初始化引擎');
    //     await _initVideoEventHandler();
    //     await _initRoomEventHandler();
    //     await _initVideoAndJoinRoom();
    //   }
    //   print('开始sdk流程');
    //   await _rtcVideo?.setDefaultAudioRoute(AudioRoute.speakerphone);
    // }
  }

  void _extractNodes(dynamic node, List<_AccessibilityNode> list) {
    if (node is Map && node.containsKey('bounds')) {
      final bounds = _parseBounds(node['bounds']);
      final text = (node['text'] ?? '').toString().trim();
      final desc = (node['contentDescription'] ?? '').toString().trim();
      final isEditable = node['editable'] == true;
      final isClickable = node['clickable'] == true;

      // 优化：更宽松的节点过滤条件
      String label;
      if (text.isNotEmpty && desc.isNotEmpty && text != desc) {
        label = '$text $desc';
      } else {
        label = text.isNotEmpty ? text : desc;
      }

      // 极低过滤条件：几乎包含所有有效节点，但优化文字显示
      bool shouldInclude = false;
      
      if (label.isNotEmpty) {
        // 有文本标签的节点 - 保持原文字
        shouldInclude = true;
      } else if (isEditable) {
        // 任何可编辑控件 - 用简洁符号
        label = '';
        shouldInclude = true;
      } else if (isClickable) {
        // 任何可点击控件 - 用简洁符号
        label = '';
        shouldInclude = true;
      } else if (bounds.width > 0 && bounds.height > 0) {
        // 任何有有效尺寸的控件都包含，但不显示文字避免遮挡
        label = ''; // 不显示文字，只显示边框
        shouldInclude = true;
      }

      if (shouldInclude && bounds.width > 0 && bounds.height > 0) {
        list.add(_AccessibilityNode(bounds: bounds, label: label));
      }
    }

    if (node is Map && node['children'] is List) {
      for (final child in node['children']) {
        _extractNodes(child, list);
      }
    }
  }
  Rect _parseBounds(String str) {
    final parts = str.split(RegExp(r'[ ,]+')).map((e) => int.tryParse(e) ?? 0).toList();
    if (parts.length >= 4) {
      return Rect.fromLTRB(
        parts[0].toDouble(),
        parts[1].toDouble(),
        parts[2].toDouble(),
        parts[3].toDouble(),
      );
    }
    return Rect.zero;
  }
  ///检查连接类型
  Future<void> _printSelectedCandidateInfo() async {
    if (_pc == null) return;
    print('准备打印连接类型');

    final stats = await _pc!.getStats();
    String? pairId;

    // 优先从 transport 里找 selectedCandidatePairId
    for (var r in stats) {
      if (r.type == 'transport' &&
          r.values['selectedCandidatePairId'] != null) {
        pairId = r.values['selectedCandidatePairId'] as String;
        break;
      }
    }
    // 回退到 candidate-pair 里带 selected 标志的
    if (pairId == null) {
      for (var r in stats) {
        if (r.type == 'candidate-pair' &&
            r.values['state'] == 'succeeded' &&
            r.values['selected'] == true) {
          pairId = r.id;
          break;
        }
      }
    }
    if (pairId == null) {
      print('⚠️ 尚未选出候选对（请确认已 Connected）');
      return;
    }

    // 找到该 pair，拿 localCandidateId
    final pairRep = stats.firstWhere((r) => r.id == pairId);
    final localId = pairRep.values['localCandidateId'] as String?;
    if (localId == null) {
      print('⚠️ 选中候选对里缺少 localCandidateId');
      return;
    }

    // 查 local-candidate，看 candidateType
    final localRep = stats.firstWhere((r) => r.id == localId);
    final mode = localRep.values['candidateType'];
    print('🏷️ 当前 ICE 模式：$mode'); // relay=TURN，srflx/STUN=直连
  }

  ///开/关电话拦截
  void _toggleIntercept(bool interceptOn) async {
    if (!kIsWeb && Platform.isAndroid) {
      if (interceptOn) {
        final ok = await PhoneUtils.interceptCall(true);
        if (ok) {
          print('🔔 开启来电拦截成功');
        } else {
          print('❌ 开启来电拦截失败');
        }
      } else {
        final ok = await PhoneUtils.interceptCall(false);
        if (ok) {
          print('🔔 关闭来电拦截成功');
        } else {
          print('❌ 关闭来电拦截失败');
        }
      }
    }
    setState(() {
      _interceptOn = interceptOn;
    });
  }

  //开/关对方麦克风
  void _toggleSpeakerphone() {
    if (_contributorSpeakerphoneOn) {
      print('🔇 通知开启麦克风');
      _setMicrophoneOn(true);
    } else {
      print('🔊 通知关闭麦克风');
      _setMicrophoneOn(false);
    }
    setState(() {
      _contributorSpeakerphoneOn = !_contributorSpeakerphoneOn;
    });
  }

  RTCSessionDescription _fixSdp(RTCSessionDescription s) {
    final String sdp = s.sdp!.replaceAll(
      'profile-level-id=640c1f',
      'profile-level-id=42e032',
    );
    return RTCSessionDescription(sdp, s.type);
  }

  /// 开/关屏幕共享
  Future<void> _toggleScreenShare() async {
    if (_screenShareOn) {
      // 停止屏幕共享
      print('🖥️ 停止屏幕共享');
      // if (_channel == "sdk") {
      //   // 停止屏幕采集
      //   await _rtcVideo!.stopScreenCapture();
      // } else {
      if (_screenSender != null) {
        await _pc!.removeTrack(_screenSender!);
        _screenSender = null;
      }
      if (_screenStream != null) {
        for (var track in _screenStream!.getTracks()) {
          track.stop();
        }
        _screenStream = null;
      }
      _screenStream = null;
      // }
      _screenShareOn = false;
      // }
    } else {
      // 开始屏幕共享
      print('🖥️ 开始屏幕共享');

      if (_channel == "cf") {
        Map<String, dynamic> frameRate;
        if (!kIsWeb && Platform.isIOS) {
          // iOS 设备，最大帧率 30，最小帧率 15
          frameRate = {'ideal': 60, 'max': 90};
        } else {
          // 其他设备（例如 Android 或 Web），最大帧率 60，最小帧率 30
          frameRate = {'ideal': 60, 'max': 90};
        }
        // try {
        //   _screenStream = await navigator.mediaDevices.getDisplayMedia({
        //     'video': {
        //       'frameRate': frameRate,
        //       'width': {'ideal': 640},
        //       'height': {'ideal': 360},
        //       'deviceId': 'broadcast',
        //     },
        //     'audio': false,
        //   });
        // } catch (e) {
        //   EasyLoading.showToast('获取屏幕共享流失败',
        //       duration: const Duration(seconds: 3));
        //   return;
        // }
        for (int attempt = 1; attempt <= 5; attempt++) {
          try {
            _screenStream = await navigator.mediaDevices.getDisplayMedia({
              'video': {
                'frameRate': frameRate,
                'width': {'ideal': 640},
                'height': {'ideal': 360},
                'deviceId': 'broadcast',
              },
              'audio': false,
            });
            print('✅ 第 $attempt 次尝试成功获取屏幕共享流');
            break;
          } catch (e) {
            print('❌ 第 $attempt 次尝试获取屏幕共享流失败: $e');
            if (attempt == 5) {
              EasyLoading.showToast('获取屏幕共享流失败  $e',
                  duration: const Duration(seconds: 3));
              return;
            }
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }

        final track = _screenStream!.getVideoTracks().first;
        _screenSender = await _pc!.addTrack(track, _screenStream!);
        // 设置编码参数
        // final params = _screenSender?.parameters;
        // if (params != null) {
        //   params.encodings = [
        //     RTCRtpEncoding(
        //       maxBitrate: 300 * 1000,
        //       maxFramerate: 30,
        //     )
        //   ];
        //   await _screenSender?.setParameters(params);
        //   print('🔧 屏幕共享编码参数已设置');
        // }
        //尝试解决ios白屏问题
        try {
          final offer = await _pc!.createOffer();
          // 仅在 iOS 平台上修改 SDP
          if (!kIsWeb && Platform.isIOS) {
            await _pc!.setLocalDescription(_fixSdp(offer));
          } else {
            await _pc!.setLocalDescription(offer);
          }
          _signaling?.sendSDP(offer);
          print('📡 屏幕共享 offer 已发送');
        } catch (e) {
          print('❌ 屏幕共享 renegotiation 失败: $e');
        }

        //老的方式
        // try {
        //   final offer = await _pc!.createOffer();
        //   await _pc!.setLocalDescription(offer);
        //   _signaling?.sendSDP(offer);
        //   print('📡 屏幕共享 offer 已发送');
        // } catch (e) {
        //   print('❌ 屏幕共享 renegotiation 失败: $e');
        // }
      }
      // } else if (_channel == "sdk") {
      //   ScreenVideoEncoderConfig screenStream = ScreenVideoEncoderConfig(
      //       width: 1280,
      //       height: 720,
      //       frameRate: 30,
      //       maxBitrate: 1024,
      //       minBitrate: 100,
      //       encoderPreference: ScreenVideoEncoderPreference.maintainFrameRate);
      //
      //   await _rtcVideo!.setScreenVideoEncoderConfig(screenStream);
      //   try {
      //     final dynamic res = await _rtcVideo!.startScreenCapture(
      //       ScreenMediaType.videoOnly,
      //     );
      //     // Android 插件目前会返回 bool
      //     final int? code = res is bool
      //         ? (res ? 0 : -1) // true 当作 0 成功，false 当作 -1 失败
      //         : res as int?; // 正常应当是 int
      //     print('startScreenCapture 返回：$code');
      //   } catch (e) {
      //     print('⚠️ startScreenCapture 返回了非 int 类型，已忽略：$e');
      //   }
      //   // 动态切换，只采集视频（静音效果）
      //   await _rtcVideo!.updateScreenCapture(ScreenMediaType.videoOnly);
      // }
      // 发送被控端屏幕分辨率给主控端
      if (!mounted) return;
      final mq = MediaQuery.of(context);
      // 逻辑像素
      final logicalSize = mq.size;
      // 设备像素比
      final dpr = mq.devicePixelRatio;
      final int width = (logicalSize.width * dpr).toInt();
      final int height = (logicalSize.height * dpr).toInt();
      print('📺 发送屏幕分辨率: $width x $height');
      if (_channel == 'cf') {
        _signaling?.sendCommand({
          'type': 'screen_info',
          'width': width,
          'height': height,
        });
      }
      // } else if (_channel == 'sdk') {
      //   // BytePlus RTC 房间内广播 JSON 格式的屏幕信息
      //   _rtcRoom?.sendRoomMessage(jsonEncode({
      //     'type': 'screen_info',
      //     'width': width,
      //     'height': height,
      //   }));
      // }
      _screenShareOn = true;
    }
    setState(() {});
  }

  /// 处理远端 SDP
  Future<void> _onRemoteSDP(RTCSessionDescription desc) async {
    print('📩 收到 SDP: ${desc.type}');
    
    // 🔍 调试：检查SDP是否包含视频
    if (desc.sdp != null) {
      final sdpLines = desc.sdp!.split('\n');
      final hasVideo = sdpLines.any((line) => line.contains('m=video'));
      final hasAudio = sdpLines.any((line) => line.contains('m=audio'));
      print('📺 SDP分析: 包含视频=$hasVideo, 包含音频=$hasAudio');
      
      if (hasVideo && widget.isCaller) {
        print('🎮 主控端：SDP包含视频内容，等待onTrack触发');
        
        // 🎯 设置一个检查器，如果2秒后还没收到onTrack，就主动检查
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_remoteHasVideo && _savedScreenShareOn) {
            print('⚠️ 主控端：2秒后仍未收到onTrack，主动检查远端流状态');
            _checkAndRestoreRemoteStream();
          }
        });
      }
    }
    
    print('📥 设置远端 SDP: ${desc.type}');
    await _pc!.setRemoteDescription(desc);
    
    if (desc.type == 'offer') {
      print('📤 创建者发送 Answer');
      final answer = await _pc!.createAnswer();
      
      // 🔍 调试：检查答案SDP
      if (answer.sdp != null) {
        final answerLines = answer.sdp!.split('\n');
        final answerHasVideo = answerLines.any((line) => line.contains('m=video'));
        print('📺 Answer SDP包含视频: $answerHasVideo');
      }
      
      await _pc!.setLocalDescription(answer);
      _signaling!.sendSDP(answer);
    }
  }

  /// 处理远端 Candidate
  Future<void> _onRemoteCandidate(RTCIceCandidate cand) async {
    print('📥 添加远端 Candidate');
    await _pc!.addCandidate(cand);
  }

  @override
  void dispose() {
    print('📴 清理资源');
    
    // Web平台：移除页面刷新监听器 - 暂时禁用
    if (kIsWeb && _beforeUnloadListener != null) {
      // TODO: 重新实现removeEventListener
      print('移除Web页面刷新监听器 - 暂时禁用');
      _beforeUnloadListener = null;
      print('🌐 已移除Web页面刷新监听器');
    }
    
    // 清理键盘监听器
    _keyboardFocusNode?.dispose();
    _keyboardFocusNode = null;
    
    // 清理长按检测定时器
    _cancelLongPressTimer();
    
    _nodeTreeTimer?.cancel(); // → 增：取消节点树定时器
    _durationTimer?.cancel(); // → 增：取消计时器
    // 1. 恢复来电拦截，停止前台服务
    PhoneUtils.interceptCall(false);
    _stopForegroundService();

    // try {
    //   if (_channel == "sdk") {
    //     print('📴 正在释放sdk资源');
    //
    //     /// Destroy the RTC room.
    //     _rtcRoom?.destroy();
    //
    //     /// Destroy the RTC engine.
    //     _rtcVideo?.destroy();
    //   }
    // } catch (e) {
    //   print("❌ 声网资源释放失败: $e");
    // }
    // 2. 停止并释放本地流
    _localStream?.getAudioTracks().forEach((t) => t.stop());
    _localStream = null;

    // 3. 停止并释放屏幕共享流
    try {
      _screenStream?.getTracks().forEach((t) => t.stop());
      _screenStream = null;
      _screenSender = null;
    } catch (e) {
      print('❌ 停止屏幕共享流失败: $e');
    }
    // 4. 取消定时器
    if (widget.isCaller) {
      _checkUserTimer?.cancel();
    } else {
      try {
        FlutterOverlayWindow.closeOverlay();
        //恢复屏幕亮度
        BrightnessManager.setBrightness(0.5);
      } catch (e) {
        print('加入者恢复屏幕失败 $e');
      }
    }

    // 5. 移除音频路由监听
    navigator.mediaDevices.ondevicechange = null;

    // 6. 清理状态保存
    
    // 清理状态保存变量和流
    _savedScreenShareOn = false;
    _savedMicphoneOn = true;
    _savedSpeakerphoneOn = true;
    // 📄 清理页面读取状态保存
    _savedShowNodeRects = false;
    
    // 清理保存的屏幕共享流
    if (_savedScreenStream != null) {
      _savedScreenStream?.getTracks().forEach((t) => t.stop());
      _savedScreenStream = null;
      _savedScreenSender = null;
      print('🧹 清理保存的屏幕共享流');
    }
    
    // 7. 关闭信令和 PeerConnection
    _signaling?.close();
    _pc?.close();
    _pc = null;

    // 7. 释放渲染器
    _remoteRenderer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    // WakelockService.release();
    // 清理视频帧订阅
    _videoFrameSubscription?.cancel();
    _screenStreamChannel?.dispose();
    print('📴 资源已释放');

    super.dispose();
  }

  /// 静音／取消静音麦克风
  void _setMicrophoneOn(bool enabled) {
    if (_channel == 'sdk') {
      // if (enabled) {
      //   _rtcRoom?.publishStream(MediaStreamType.audio);
      // } else {
      //   _rtcRoom?.unpublishStream(MediaStreamType.audio);
      // }
    } else if (_channel == 'cf') {
      if (_localStream == null) return;
      if (widget.isCaller) {
        for (var track in _localStream!.getAudioTracks()) {
          track.enabled = enabled;
        }
      } else {
        if (!kIsWeb && Platform.isAndroid) {
          for (var track in _localStream!.getAudioTracks()) {
            track.enabled = enabled;
          }
        } else {
          if (!_screenShareOn) {
            for (var track in _localStream!.getAudioTracks()) {
              track.enabled = enabled;
            }
          }
        }
      }
    }
    print('🎤 麦克风已${enabled ? '开启' : '静音'}');
  }

  /// 创建者点击后，向对端发送"开始屏幕共享"命令
  void _onRequestScreenShare() {
    print('📣 发送屏幕共享请求给加入者');
    switch (_channel) {
      // case 'sdk':
      //   _rtcRoom?.sendRoomMessage(jsonEncode({
      //     'type': 'start_screen_share',
      //   }));
      //   break;
      case 'cf':
        _signaling?.sendCommand({'type': 'start_screen_share'});
        break;
    }
  }

  //关闭屏幕共享命令
  void _onStopScreenShare() async {
    print('📣 停止屏幕共享');
    
    // 🎯 关键修复：被控端需要真正停止屏幕捕获
    if (_screenShareOn) {
      print('🖥️ 被控端：真正停止屏幕共享');
      
      // 停止屏幕流和清理资源
      if (_screenSender != null) {
        await _pc!.removeTrack(_screenSender!);
        _screenSender = null;
        print('🖥️ 已移除屏幕track');
      }
      
      if (_screenStream != null) {
        for (var track in _screenStream!.getTracks()) {
          track.stop();
          print('🖥️ 已停止屏幕track: ${track.id}');
        }
        _screenStream = null;
        print('🖥️ 已清理屏幕流');
      }
      
      // 清理保存的屏幕流（如果有）
      if (_savedScreenStream != null) {
        for (var track in _savedScreenStream!.getTracks()) {
          track.stop();
        }
        _savedScreenStream = null;
        print('🖥️ 已清理保存的屏幕流');
      }
      
      _screenShareOn = false;
      
      // 重新协商以移除视频流
      try {
        final offer = await _pc!.createOffer();
        await _pc!.setLocalDescription(offer);
        _signaling?.sendSDP(offer);
        print('📡 停止屏幕共享后的offer已发送');
      } catch (e) {
        print('❌ 停止屏幕共享重新协商失败: $e');
      }
    }
    
    // 发送停止命令给对方
    switch (_channel) {
      case 'cf':
        _signaling?.sendCommand({'type': 'stop_screen_share'});
        break;
    }
    
    setState(() {
      _remoteHasVideo = false;
      _remoteScreenWidth = 0.0;
      _remoteScreenHeight = 0.0;
    });
  }

  //关闭对方麦克风命令
  void _onStopSpeakerphone() {
    print('📣 发送关闭对方麦克风请求');
    if (_channel == 'sdk') {
      // _rtcRoom?.sendRoomMessage(jsonEncode({'type': 'stop_speakerphone'}));
    } else if (_channel == 'cf') {
      _signaling?.sendCommand({'type': 'stop_speakerphone'});
    }
  }

  //打开对方麦克风命令
  void _onStartSpeakerphone() {
    print('📣 发送打开对方麦克风请求');
    if (_channel == 'sdk') {
      // _rtcRoom?.sendRoomMessage(jsonEncode({'type': 'start_speakerphone'}));
    } else if (_channel == 'cf') {
      _signaling?.sendCommand({'type': 'start_speakerphone'});
    }
  }

  //开关远程控制
  void _onRemoteControl(bool enable) {
    if (enable) {
      print('📣 发送开启远程控制请求');
      if (_channel == 'sdk') {
        // _rtcRoom?.sendRoomMessage(jsonEncode({'type': 'remote_control_on'}));
      } else if (_channel == 'cf') {
        _signaling?.sendCommand({'type': 'remote_control_on'});
      }
    } else {
      print('📣 发送关闭远程控制请求');
      if (_channel == 'sdk') {
        // _rtcRoom?.sendRoomMessage(jsonEncode({'type': 'remote_control_off'}));
      } else if (_channel == 'cf') {
        _signaling?.sendCommand({'type': 'remote_control_off'});
      }
    }
  }

  //开关黑屏
  void _onBlackScreen(bool enable) {
    if (enable) {
      print('📣 发送开启黑屏请求');
      if (_channel == 'sdk') {
        // _rtcRoom?.sendRoomMessage(jsonEncode({'type': 'showBlack'}));
      } else if (_channel == 'cf') {
        _signaling?.sendCommand({'type': 'showBlack'});
      }
    } else {
      print('📣 发送关闭黑屏请求');
      if (_channel == 'sdk') {
        // _rtcRoom?.sendRoomMessage(jsonEncode({'type': 'hideBlack'}));
      } else if (_channel == 'cf') {
        _signaling?.sendCommand({'type': 'hideBlack'});
      }
    }
  }

  //开启电话拦截
  void _sendInterceptCommand(bool intercept) {
    if (intercept) {
      print('📣 发送开启电话拦截请求');
      if (_channel == 'sdk') {
        // _rtcRoom?.sendRoomMessage(jsonEncode({'type': 'on_intercept_call'}));
      } else if (_channel == 'cf') {
        _signaling?.sendCommand({'type': 'on_intercept_call'});
      }
    } else {
      print('📣 发送关闭电话拦截请求');
      if (_channel == 'sdk') {
        // _rtcRoom?.sendRoomMessage(jsonEncode({'type': 'off_intercept_call'}));
      } else if (_channel == 'cf') {
        _signaling?.sendCommand({'type': 'off_intercept_call'});
      }
    }
  }

  //通知对方退出房间
  void _onExitRoom() {
    print('📣 发送退出房间请求');
    if (_channel == 'sdk') {
      // _rtcRoom?.sendRoomMessage(jsonEncode({'type': 'exit_room'}));
    } else if (_channel == 'cf') {
      _signaling?.sendCommand({'type': 'exit_room'});
    }
  }

  //开关显示黑屏
  void _changeBlackScreen() async {
    _showBlack = !_showBlack;
    if (_showBlack) {
      // 开启黑屏时显示3秒的权限提示
      await EasyLoading.showToast(
        '已开启黑屏\n如果不生效请回到App打开权限后再次开启',
        duration: const Duration(seconds: 3),
      );
    } else {
      // 关闭黑屏时显示正常时长
      await EasyLoading.showToast('已关闭黑屏');
    }
    _showBlack ? _onBlackScreen(true) : _onBlackScreen(false);
    setState(() {});
  }
  
  /// 检查是否有音频连接
  bool _hasAnyAudio() {
    // 首先检查状态变量
    if (_remoteHasAudio) return true;
    
    // 检查PeerConnection中的音频流
    if (_pc != null) {
      try {
        final streams = _pc!.getRemoteStreams();
        for (final stream in streams) {
          if (stream != null) {
            final audioTracks = stream.getAudioTracks();
            for (final track in audioTracks) {
              if (track.enabled != false) { // 不是明确禁用的就算有效
                print('🎮 检测到活跃音频track: ${track.id}');
                // 同步更新状态
                if (!_remoteHasAudio) {
                  setState(() {
                    _remoteHasAudio = true;
                  });
                }
                return true;
              }
            }
          }
        }
      } catch (e) {
        print('🎮 检查音频流失败: $e');
      }
    }
    
    return false;
  }

  /// 重连后恢复页面读取功能
  void _restorePageReadingAfterReconnect() {
    try {
      if (_savedShowNodeRects && _signaling != null) {
        print('📄 开始恢复页面读取功能...');
        
        // 检查分辨率信息是否可用
        if (_savedRemoteScreenWidth <= 0 || _savedRemoteScreenHeight <= 0) {
          print('⚠️ 分辨率信息不可用，页面读取功能暂时无法恢复');
          return;
        }
        
        // 恢复状态和启动定时器
        _showNodeRects = true;
        
        // 🎯 关键：页面读取场景下，UI会根据_showNodeRects正确显示黑屏+节点框框
        print('📄 页面读取恢复：当前状态 - _showNodeRects=true, _remoteHasVideo=$_remoteHasVideo');
        
        // 延迟发送页面读取请求，给无障碍服务更多准备时间
        print('📄 延迟发送第一次页面读取请求...');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_signaling != null && _showNodeRects && mounted) {
            print('📄 发送第一次页面读取请求');
            _signaling!.sendCommand({'type': 'show_view'});
          }
        });
        
        // 重新启动定时器
        _nodeTreeTimer?.cancel(); // 确保没有重复的定时器
        final updateInterval = _nodeRects.length > 500 
            ? const Duration(seconds: 3) 
            : const Duration(seconds: 2);
        _nodeTreeTimer = Timer.periodic(updateInterval, (_) {
          if (_signaling != null && _showNodeRects) {
            _signaling!.sendCommand({'type': 'show_view'});
          }
        });
        
        setState(() {});
        print('✅ 页面读取功能已恢复');
        EasyLoading.showToast('页面读取功能已恢复', duration: const Duration(seconds: 2));
        
      } else {
        print('ℹ️ 页面读取功能未开启或信令连接不可用');
      }
    } catch (e) {
      print('❌ 恢复页面读取功能失败: $e');
    }
  }

  //开关显示节点树
  void _changeShowNodeTree() async {
    _showNodeRects = !_showNodeRects;

    if (_showNodeRects) {
      // 显示优化改进提示
      await EasyLoading.showToast('已开启页面读取');
      
      // 检查是否有保存的分辨率信息
      if (_savedRemoteScreenWidth <= 0 || _savedRemoteScreenHeight <= 0) {
        await EasyLoading.showToast('请先开启屏幕共享以获取分辨率信息');
        _showNodeRects = false;
        setState(() {});
        return;
      }
      
      // 开启定时发送 - 即使没有视频流也可以发送命令
      if (_signaling != null) {
        print('📱 开始发送页面读取请求...');
        _signaling!.sendCommand({'type': 'show_view'});
        _nodeTreeTimer?.cancel(); // 防止重复开启
        // 根据节点数量动态调整更新频率
        final updateInterval = _nodeRects.length > 500 
            ? const Duration(seconds: 3) // 节点多时降低频率
            : const Duration(seconds: 2); // 节点少时正常频率
        _nodeTreeTimer = Timer.periodic(updateInterval, (_) {
          _signaling?.sendCommand({'type': 'show_view'});
        });
      } else {
        // 如果没有signaling连接，显示提示
        await EasyLoading.showToast('未连接到对方设备，无法获取页面信息');
        _showNodeRects = false;
      }
    } else {
      await EasyLoading.showToast('已关闭页面读取');
      // 停止发送并清除节点
      _nodeTreeTimer?.cancel();
      _nodeTreeTimer = null;
      _nodeRects.clear();
      print('📱 已停止页面读取');
    }

    setState(() {});
  }
  /// 开关远程控制
  void _changeRemotoe() async {
    if (widget.type != '2') {
      await showOkAlertDialog(
        context: context,
        title: '温馨提示',
        message: '当前注册码只有语音功能,请联系管理员开通远控功能',
        okLabel: '确定',
      );
      return;
    }
    final result = await showOkCancelAlertDialog(
      context: context,
      title: '温馨提示',
      message: _remoteOn
          ? '确认要关闭远程控制？\n\n请先打开app,保证app在前台运行后,进入设置手动关闭无障碍权限'
          : '确认要打开远程控制？\n\n请让对方打开app,保证app在前台运行后,进入设置打开无障碍权限',
      okLabel: '确认',
      cancelLabel: '取消',
    );
    if (result == OkCancelResult.ok) {
      setState(() {
        _remoteOn = !_remoteOn;
        // 重置按钮组位置为屏幕正中心
        if (_remoteOn) {
          final screenSize = MediaQuery.of(context).size;
          final centerX = screenSize.width / 2 - 50;
          final centerY = screenSize.height / 2;
          print('centerX:$centerX, centerY:$centerY');
          _buttonGroupPosition = Offset(centerX, centerY);
        }
      });
      _remoteOn ? _onRemoteControl(true) : _onRemoteControl(false);
    }
  }

  //设置电话拦截开关
  void _changeIntercept() async {
    final result = await showOkCancelAlertDialog(
      context: context,
      title: '温馨提示',
      message: _interceptOn ? '确认要关闭电话拦截？' : '确认要打开电话拦截？',
      okLabel: '确认',
      cancelLabel: '取消',
    );
    if (result == OkCancelResult.ok) {
      _interceptOn = !_interceptOn;
      await EasyLoading.showToast(_interceptOn ? '已开启电话拦截' : '已关闭电话拦截');
      _interceptOn ? _sendInterceptCommand(true) : _sendInterceptCommand(false);

      setState(() {});
    }
  }

  /// ///打开关闭对方屏幕
  void _changeContributorScreen() async {
    if (widget.type != '2') {
      await showOkAlertDialog(
        context: context,
        title: '温馨提示',
        message: '当前注册码只有语音功能,请联系管理员开通屏幕功能',
        okLabel: '确定',
      );
      return;
    }
    final result = await showOkCancelAlertDialog(
      context: context,
      title: '温馨提示',
      message: _screenShareOn
          ? '确认要关闭对方屏幕？'
          : '确认要打开对方屏幕？\n\n如果无画面,让对方打开app,保证app在前台运行后,同意授权',
      okLabel: '确认',
      cancelLabel: '取消',
    );
    if (result == OkCancelResult.ok) {
      _screenShareOn = !_screenShareOn;
      await EasyLoading.showToast(_screenShareOn ? '打开对方屏幕' : '关闭对方屏幕');
      _screenShareOn ? _onRequestScreenShare() : _onStopScreenShare();
      // 在点击"确定"后禁用按钮
      setState(() {
        _canShareScreen = false;
      });
    }
    // 5 秒后恢复按钮可用
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _canShareScreen = true;
      });
    });
  }

  /// /// 设置对方麦克风
  void _setContributorSpeakerphoneOn() async {
    final result = await showOkCancelAlertDialog(
      context: context,
      title: '温馨提示',
      message: _contributorSpeakerphoneOn
          ? '确认要关闭对方麦克风？'
          : '确认要打开对方麦克风？\n\n如果无声音,让对方打开app,保证app在前台运行',
      okLabel: '确认',
      cancelLabel: '取消',
    );
    if (result == OkCancelResult.ok) {
      _contributorSpeakerphoneOn = !_contributorSpeakerphoneOn;
      await EasyLoading.showToast(
          _contributorSpeakerphoneOn ? '打开对方麦克风' : '关闭对方麦克风');
      _contributorSpeakerphoneOn
          ? _onStartSpeakerphone()
          : _onStopSpeakerphone();

      setState(() {});
    }
  }

  /// 设置自己的麦克风
  void _setMicphoneOn() async {
    final result = await showOkCancelAlertDialog(
      context: context,
      title: '温馨提示',
      message: _micphoneOn ? '确认要关闭自己的麦克风？' : '确认要打开自己的麦克风？',
      okLabel: '确认',
      cancelLabel: '取消',
    );
    if (result == OkCancelResult.ok) {
      _micphoneOn = !_micphoneOn;
      await EasyLoading.showToast(_micphoneOn ? '已开启麦克风' : '已关闭麦克风');
      _micphoneOn ? _setMicrophoneOn(true) : _setMicrophoneOn(false);
      setState(() {});
    }
  }

  /// 主控端：检查并恢复远端流状态
  Future<void> _checkAndRestoreRemoteStream() async {
    try {
      print('🎮 主控端：主动检查PeerConnection远端流状态');
      
      if (_pc == null) {
        print('❌ PeerConnection为空，无法检查远端流');
        return;
      }
      
      // 🎯 统一使用 getRemoteStreams() API，避免双重检查的不一致
      final streams = _pc!.getRemoteStreams();
      print('🎮 主控端：PeerConnection中有 ${streams.length} 个远端流');
      
      if (streams.isEmpty) {
        print('🎮 主控端：当前无远端流');
        return;
      }
      
      // 检查是否有活跃的音视频流
      MediaStream? videoStream;
      bool hasActiveAudio = false;
      
      for (final stream in streams) {
        if (stream != null) {
          final videoTracks = stream.getVideoTracks();
          final audioTracks = stream.getAudioTracks();
          print('🎮 远端流 ${stream.id}: 视频tracks=${videoTracks.length}, 音频tracks=${audioTracks.length}');
          
          // 检查音频tracks
          for (final track in audioTracks) {
            print('🎮 音频track: id=${track.id}, enabled=${track.enabled}, muted=${track.muted}');
            // 🎯 放宽检测条件：只要track存在且不是明确禁用就算有效
            if (track.enabled != false) { // 不是明确禁用的就算有效
              hasActiveAudio = true;
              print('🎮 找到音频track（已放宽检测条件）');
            }
          }
          
          // 检查视频tracks  
          for (final track in videoTracks) {
            print('🎮 视频track: id=${track.id}, enabled=${track.enabled}, muted=${track.muted}');
            
            // 🎯 放宽检测条件：只要track存在且enabled就认为是有效的视频流
            if (track.enabled != false) { // 不是明确禁用的就算有效
              videoStream = stream;
              print('🎮 找到视频track和对应流（已放宽检测条件）');
              break;
            }
          }
          
          if (videoStream != null) break;
        }
      }
      
      // 🎯 更新音频状态
      if (_remoteHasAudio != hasActiveAudio) {
        setState(() {
          _remoteHasAudio = hasActiveAudio;
          print('🎮 更新音频状态: $_remoteHasAudio');
        });
      }
      
      // 🎯 关键修复：无论当前状态如何，都要检查实际的srcObject
      final currentSrcObject = _remoteRenderer.srcObject;
      final needsRestore = videoStream != null && (
        currentSrcObject == null || 
        !_remoteHasVideo || 
        currentSrcObject.id != videoStream.id
      );
      
      if (needsRestore) {
        print('🎮 检测到需要恢复远端视频流');
        print('🎮 当前srcObject: ${currentSrcObject?.id}, 目标流: ${videoStream.id}');
        print('🎮 当前_remoteHasVideo: $_remoteHasVideo');
        
        setState(() {
          _remoteRenderer.srcObject = videoStream;
          _remoteHasVideo = true;
          _remoteHasAudio = hasActiveAudio; // 同时更新音频状态
          _screenShareOn = true;
          print('🎮 主控端：手动设置远端渲染器和状态');
        });
        
        // 保存容器信息
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _saveCurrentVideoContainerInfo();
          }
        });
        
        EasyLoading.showToast('屏幕共享已恢复', duration: const Duration(seconds: 2));
        print('✅ 主控端：远端视频流恢复成功');
        
      } else if (videoStream == null) {
        print('🎮 主控端：未找到活跃的远端视频流');
        
        // 🎯 关键修复：只有在非屏幕共享恢复场景下才设置纯音频模式
        // 如果正在恢复屏幕共享，给视频流更多时间，不要急于设置为纯音频
        if (hasActiveAudio && _remoteRenderer.srcObject == null && !_savedScreenShareOn) {
          print('🎮 非屏幕共享场景：没有视频但有音频，设置音频流到渲染器');
          // 找到任何包含音频的流
          for (final stream in streams) {
            if (stream != null && stream.getAudioTracks().isNotEmpty) {
              setState(() {
                _remoteRenderer.srcObject = stream;
                _remoteHasVideo = false; // 确保没有视频
                _remoteHasAudio = true;
                print('🎮 主控端：设置音频流到渲染器（无视频）');
              });
              break;
            }
          }
        } else if (_savedScreenShareOn) {
          print('🎮 屏幕共享恢复场景：视频流暂未检测到，继续等待...');
        }
        
      } else {
        print('✅ 主控端：远端视频流状态正常，无需恢复');
      }
      
    } catch (e) {
      print('❌ 检查远端流状态失败: $e');
      EasyLoading.showToast('检查远端流失败');
    }
  }



  /// 主控端恢复屏幕共享 - 重新发送请求给被控端
  Future<void> _restoreScreenShareForCaller() async {
    try {
      print('🎮 主控端：重新发送屏幕共享请求给被控端...');
      
      if (_savedScreenShareOn) {
        // 检查PeerConnection状态是否健康
        final iceState = _pc!.iceConnectionState;
        if (iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          
          print('📤 主控端：连接稳定，立即发送屏幕共享请求');
          print('🔍 主控端调试: _savedScreenShareOn=$_savedScreenShareOn, 当前_screenShareOn=$_screenShareOn');
          EasyLoading.showToast('正在恢复屏幕共享...', duration: const Duration(seconds: 2));
          
          // 重新发送屏幕共享请求给被控端
          print('🔍 主控端调试: _signaling为null? ${_signaling == null}');
          if (_signaling != null) {
            _signaling!.sendCommand({'type': 'start_screen_share'});
            print('✅ 屏幕共享请求已发送给被控端');
          } else {
            print('❌ 信令连接为空，无法发送屏幕共享请求');
            EasyLoading.showToast('信令连接异常，请手动重新开启屏幕共享');
          }
          
        } else {
          print('⚠️ 连接状态不稳定($iceState)，延迟发送屏幕共享请求');
          // 🚀 优化：减少等待时间到1.2秒，加快不稳定连接的恢复速度
          Future.delayed(const Duration(milliseconds: 1200), () async {
            if (mounted && _savedScreenShareOn && _pc != null) {
              try {
                print('📤 主控端：延迟发送屏幕共享请求');
                print('🔍 主控端延迟调试: _signaling为null? ${_signaling == null}');
                EasyLoading.showToast('正在恢复屏幕共享...', duration: const Duration(seconds: 2));
                if (_signaling != null) {
                  _signaling!.sendCommand({'type': 'start_screen_share'});
                  print('✅ 延迟屏幕共享请求已发送给被控端');
                } else {
                  print('❌ 延迟发送时信令连接为空');
                  EasyLoading.showToast('信令连接异常，请手动重新开启屏幕共享');
                }
              } catch (e) {
                print('❌ 延迟发送屏幕共享请求失败: $e');
                EasyLoading.showToast('请求屏幕共享失败，请手动重新开启');
              }
            }
          });
        }
      } else {
        print('ℹ️ 主控端：之前无屏幕共享，无需恢复');
      }
    } catch (e) {
      print('❌ 主控端恢复屏幕共享失败: $e');
      EasyLoading.showToast('屏幕共享恢复失败，请手动重新开启');
    }
  }

  /// 安全地开启屏幕共享（优先无感恢复，失败时降级）
  Future<void> _startScreenShareSafely() async {
    try {
      print('🔒 安全开启屏幕共享：优先尝试无感恢复');
      
      // 尝试无感恢复（利用可能存在的MediaProjection权限）
      await _restoreScreenShareStreamSilently();
      
    } catch (e) {
      print('⚠️ 无感恢复失败，降级到标准授权模式: $e');
      
      // 无感恢复失败，使用标准的屏幕共享开启流程
      try {
        await _toggleScreenShare();
        print('✅ 标准授权模式开启屏幕共享成功');
      } catch (toggleError) {
        print('❌ 标准授权模式也失败: $toggleError');
        EasyLoading.showError('屏幕共享开启失败，请检查权限设置');
        throw toggleError;
      }
    }
  }

  /// 被控端恢复屏幕共享 - 智能检查并恢复
  Future<void> _restoreScreenShareForJoiner() async {
    try {
      print('📱 被控端：检查屏幕共享恢复状态...');
      
      if (_savedScreenShareOn) {
        // 🔍 优先检查保存的流是否还有效
        if (_savedScreenStream != null) {
          final tracks = _savedScreenStream!.getVideoTracks();
          if (tracks.isNotEmpty && tracks.first.enabled == true) {
            // ✅ 保存的流完好，恢复到当前状态并重新协商
            print('✅ 被控端：保存的屏幕共享流完好，恢复并重新协商SDP');
            
            // 恢复流对象到当前状态
            _screenStream = _savedScreenStream;
            _screenSender = _savedScreenSender; // 这个可能需要重新添加到PeerConnection
            
            setState(() {
              _screenShareOn = true;
            });
            
            // 🔄 关键：重新创建offer让主控端收到视频流
            try {
              // 🎯 确保视频track在流中是活跃的
              final videoTracks = _screenStream!.getVideoTracks();
              if (videoTracks.isNotEmpty) {
                final track = videoTracks.first;
                print('📺 检查视频track状态: enabled=${track.enabled}, muted=${track.muted}');
                
                // 如果track状态有问题，尝试重新启用
                if (track.muted == true || track.enabled != true) {
                  track.enabled = true;
                  print('🔧 重新启用视频track');
                }
                
                // 🎯 关键修复：硬重连后需要重新添加track到新的PeerConnection
                if (_pc != null) {
                  // 检查track是否已经在PeerConnection中
                  final senders = await _pc!.getSenders();
                  bool trackExists = senders.any((sender) => 
                    sender.track?.id == track.id);
                  
                  if (!trackExists) {
                    print('➕ 重新添加屏幕共享track到新的PeerConnection');
                    _screenSender = await _pc!.addTrack(track, _screenStream!);
                  } else {
                    print('✅ Track已存在于PeerConnection中');
                    // 找到对应的sender
                    _screenSender = senders.firstWhere((sender) => 
                      sender.track?.id == track.id);
                  }
                }
              }
              
              // 创建新的offer
              final offer = await _pc!.createOffer();
              if (!kIsWeb && Platform.isIOS) {
                await _pc!.setLocalDescription(_fixSdp(offer));
              } else {
                await _pc!.setLocalDescription(offer);
              }
              
              // 发送SDP
              _signaling?.sendSDP(offer);
              print('📡 被控端：重新发送屏幕共享 offer 给主控端');
              
              // 🎯 额外确认：检查offer中是否包含视频
              final sdpLines = offer.sdp?.split('\n') ?? [];
              final hasVideo = sdpLines.any((line) => line.contains('m=video'));
              print('📺 Offer包含视频: $hasVideo');
              
            } catch (e) {
              print('❌ 被控端重新协商失败: $e');
              throw e; // 让它走智能恢复流程
            }
            
            // 重新发送屏幕分辨率信息
            if (mounted) {
              final mq = MediaQuery.of(context);
              final logicalSize = mq.size;
              final dpr = mq.devicePixelRatio;
              final int width = (logicalSize.width * dpr).toInt();
              final int height = (logicalSize.height * dpr).toInt();
              
              _signaling?.sendCommand({
                'type': 'screen_info',
                'width': width,
                'height': height,
              });
              print('📺 重新发送屏幕分辨率: $width x $height');
            }
            
            EasyLoading.showToast('屏幕共享已自动恢复', duration: const Duration(seconds: 2));
            return;
          }
        }
        
        // 🔄 流或sender有问题，尝试智能恢复
        print('🔄 被控端：尝试智能恢复屏幕共享流');
                    EasyLoading.showToast('正在智能恢复屏幕共享...', duration: const Duration(seconds: 2));
        await _restoreScreenShareStreamSilently();
      } else {
        // 如果之前没有屏幕共享，只是更新状态
        print('ℹ️ 被控端：之前无屏幕共享，仅更新状态');
        setState(() {
          _screenShareOn = false;
        });
      }
      
    } catch (e) {
      print('❌ 被控端恢复失败，降级到重新授权: $e');
      EasyLoading.showToast('⚠️ 恢复失败，正在重新授权...', duration: const Duration(seconds: 2));
      
      // 恢复失败时，降级到重新授权
      await _fallbackToReauthorize();
    }
  }
  
  /// 无感恢复屏幕共享流（智能检查并复用流对象）
  Future<void> _restoreScreenShareStreamSilently() async {
    try {
      print('🔇 开始无感恢复屏幕共享流（智能检查并复用流对象）...');
      
      // 🎯 关键：检查是否有保存的流
      if (_savedScreenStream == null) {
        throw Exception('没有保存的屏幕共享流，需要重新授权');
      }
      
      // 🔍 检查保存的流是否还有效
      final tracks = _savedScreenStream!.getVideoTracks();
      if (tracks.isEmpty) {
        throw Exception('保存的屏幕共享流无效，需要重新授权');
      }
      
              final track = tracks.first;
        if (track.muted == true || track.enabled != true) {
          throw Exception('保存的屏幕共享流已停用，需要重新授权');
        }
      
      // 确保状态正确
      _screenShareOn = false; // 重置状态，准备开启
      
      if (_channel == "cf") {
        // 🎯 直接复用保存的流对象，避免重新授权
        _screenStream = _savedScreenStream;
        print('✅ 复用保存的屏幕共享流，无需重新授权');
        
        // 🔍 检查当前PeerConnection是否已经有这个track
        if (_pc != null) {
          final senders = await _pc!.getSenders();
          bool trackAlreadyAdded = false;
          
          for (final sender in senders) {
            if (sender.track != null && sender.track!.id == track.id) {
              print('🔄 Track已存在，更新sender引用');
              _screenSender = sender;
              trackAlreadyAdded = true;
              break;
            }
          }
          
          // 只有当track不存在时才添加
          if (!trackAlreadyAdded) {
            print('➕ 添加屏幕共享track到PeerConnection');
            _screenSender = await _pc!.addTrack(track, _screenStream!);
          }
          
          // 重新协商
          try {
            final offer = await _pc!.createOffer();
            if (!kIsWeb && Platform.isIOS) {
              await _pc!.setLocalDescription(_fixSdp(offer));
            } else {
              await _pc!.setLocalDescription(offer);
            }
            _signaling?.sendSDP(offer);
            print('📡 复用流的屏幕共享 offer 已发送');
          } catch (e) {
            print('❌ 复用流屏幕共享 renegotiation 失败: $e');
            throw e;
          }
          
          // 发送屏幕分辨率信息
          if (mounted) {
            final mq = MediaQuery.of(context);
            final logicalSize = mq.size;
            final dpr = mq.devicePixelRatio;
            final int width = (logicalSize.width * dpr).toInt();
            final int height = (logicalSize.height * dpr).toInt();
            
            _signaling?.sendCommand({
              'type': 'screen_info',
              'width': width,
              'height': height,
            });
            print('📺 发送恢复的屏幕分辨率: $width x $height');
          }
          
          // 更新状态
          setState(() {
            _screenShareOn = true;
          });
          
          print('✅ 屏幕共享流已通过智能复用无感恢复完成');
          EasyLoading.showToast('屏幕共享已恢复', duration: const Duration(seconds: 2));
        }
      }
      
    } catch (e) {
      print('❌ 智能复用流无感恢复失败: $e');
      throw e; // 抛出异常让上层处理降级逻辑
    }
  }
  
  /// 降级到重新授权模式
  Future<void> _fallbackToReauthorize() async {
    try {
      print('🔄 被控端：降级到重新授权模式');
              EasyLoading.showToast('正在重新授权屏幕共享...', duration: const Duration(seconds: 3));
      
      // 确保状态正确，然后调用标准的开启流程
      setState(() {
        _screenShareOn = false; // 重置为false，这样_toggleScreenShare会开启
      });
      
      // 延迟一下调用，确保状态更新完成
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted && !_screenShareOn) {
          try {
            await _toggleScreenShare();
            print('✅ 被控端屏幕共享重新授权成功');
            EasyLoading.showToast('屏幕共享已重新开启', duration: const Duration(seconds: 2));
          } catch (e) {
            print('❌ 被控端重新授权失败: $e');
            EasyLoading.showToast('❌ 重新授权失败，请手动点击允许', duration: const Duration(seconds: 4));
          }
        }
      });
    } catch (e) {
      print('❌ 降级重新授权失败: $e');
      EasyLoading.showToast('屏幕共享恢复失败，请手动重新开启');
    }
  }


  /// 执行硬重连（自动降级时使用，无需用户确认）
  Future<void> _performHardReconnect() async {
    print('🔄 开始执行硬重连（自动降级）');
    _isrefresh = true;
    setState(() => _canRefresh = false);
    
    // 💾 保存重连前的状态和流
    _savedScreenShareOn = _screenShareOn;
    _savedMicphoneOn = _micphoneOn;
    _savedSpeakerphoneOn = _contributorSpeakerphoneOn;
    // 📄 保存页面读取状态
    _savedShowNodeRects = _showNodeRects;
    
                  // 🎯 关键：保存屏幕共享状态（主控端和被控端都需要）
      if (_savedScreenShareOn) {
        if (_screenStream != null) {
          // 被控端：有本地屏幕共享流
          _savedScreenStream = _screenStream;
          _savedScreenSender = _screenSender;
          print('💾 保存被控端屏幕共享流对象，避免重新授权');
        } else if (widget.isCaller) {
          // 主控端：保存远端屏幕共享状态，不依赖流对象
          print('💾 保存主控端远端屏幕共享状态（无本地流）');
          // 主控端标记需要恢复远端屏幕共享
          print('💾 主控端屏幕共享状态已保存');
        }
      }
    
    print('💾 保存重连前状态: 屏幕共享=$_savedScreenShareOn, 麦克风=$_savedMicphoneOn, 扬声器=$_savedSpeakerphoneOn, 流保存=${_savedScreenStream != null}');
    print('🔍 调试信息: 当前_screenShareOn=$_screenShareOn, _screenStream=${_screenStream != null}, _screenSender=${_screenSender != null}');
    
    try {
      EasyLoading.show(status: '刷新中...');
      
      // 🎯 安全保护：15秒后强制关闭loading，防止一直显示
      Timer(const Duration(seconds: 15), () {
        if (EasyLoading.isShow) {
          print('⚠️ 刷新超时，强制关闭loading');
          EasyLoading.dismiss();
        }
      });

        if (_channel == "sdk") {
          print('📴 正在释放sdk资源');
        } else {
          // 1️⃣ 停掉本地音频流
          if (_localStream != null) {
            _localStream?.getAudioTracks().forEach((t) => t.stop());
            _localStream = null;
          }

        // 2️⃣ 处理屏幕共享流
        if (_screenStream != null) {
          // 🎯 关键修复：被控端有保存的流且需要恢复时，不停止流
          if (!widget.isCaller && _savedScreenStream == _screenStream && _savedScreenShareOn) {
            print('💾 被控端：保留屏幕共享流，不停止track，用于硬重连后恢复');
            // 只清空引用，但不停止track，让保存的流对象保持活跃
            _screenStream = null;
            _screenSender = null;
          } else {
            // 其他情况正常停止
            _screenStream?.getTracks().forEach((t) => t.stop());
            _screenStream = null;
            _screenSender = null;
          }
        }

        // 4️⃣ 关闭现有 PeerConnection
          if (_pc != null) {
            await _pc!.close();
            _pc = null;
          }
        
          setState(() {
            _remoteHasVideo = false;
            _remoteHasAudio = false;
            _remoteScreenHeight = 0.0;
            _remoteScreenWidth = 0.0;
            _currentIceState = null;
          });
      }
      
      // 5️⃣ 重新初始化连接
      print('🔄 正在重新初始化通话...');
        await _startCall();
        print('✅ 重新初始化通话完成');
        
        // 🎯 核心连接已建立，立即关闭loading
        EasyLoading.dismiss();
        EasyLoading.showSuccess('连接已恢复', duration: const Duration(seconds: 2));
      
      // 6️⃣ 重新发送offer（如果需要）
        if (!widget.isCaller && _channel == 'cf') {
        print('📤 加入者硬重连后发送新的 Offer');
          final offer = await _pc!.createOffer();
          await _pc!.setLocalDescription(offer);
          _signaling?.sendSDP(offer);
        }
      
        if (widget.isCaller) {
        // 🚀 优化：减少延迟到200ms，加快命令发送速度
        await Future.delayed(const Duration(milliseconds: 200));
        if (_channel != "sdk") {
            _signaling?.sendCommand({'type': 'refresh_cf'});
          }
        }
      
        if (!widget.isCaller) {
          try {
            await FlutterOverlayWindow.closeOverlay();
            // 🎯 恢复到原始亮度状态
            await BrightnessManager.restoreOriginalState();
            print('✅ 硬重连后关闭黑屏,恢复亮度完成');
          } catch (e) {
            print('⚡ 硬重连后恢复亮度失败，使用默认值: $e');
            // 备用方案
            await BrightnessManager.setBrightness(0.5);
          }
        }
      
      // 🔄 恢复保存的状态，而不是重置为默认值
        setState(() {
        _micphoneOn = true;
        _contributorSpeakerphoneOn = true;
        _screenShareOn = _savedScreenShareOn; // 恢复屏幕共享状态
          _showBlack = false;
          _canRefresh = true;
          _isrefresh = false;
        _icerefresh = false;
      });
      
      print('🔄 恢复重连前状态: 屏幕共享=$_savedScreenShareOn, 麦克风=$_savedMicphoneOn, 扬声器=$_savedSpeakerphoneOn, 页面读取=$_savedShowNodeRects');
      
      // 📄 恢复页面读取功能（如果需要）
      if (_savedShowNodeRects && _signaling != null) {
        print('📄 硬重连后恢复页面读取功能');
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _restorePageReadingAfterReconnect();
          }
        });
      }

      // 📺 恢复屏幕共享功能（如果需要）
      if (_savedScreenShareOn && widget.isCaller) {
        print('📺 重连后恢复屏幕共享...');
        Future.delayed(const Duration(milliseconds: 1500), () async {
          if (mounted && _savedScreenShareOn && _pc != null) {
            print('🔄 主控端：开始执行屏幕共享恢复任务');
            await _restoreScreenShareForCaller();
          }
        });
      }
      
      print('🔄 硬重连核心流程完成');
      
      } catch (e) {
      print('❌ 硬重连失败: $e');
      EasyLoading.showError('刷新失败，请稍后重试');
      } finally {
        // 确保loading被关闭（如果还没有关闭的话）
        if (EasyLoading.isShow) {
          EasyLoading.dismiss();
        }
      }
  }

  /// 刷新连接（执行硬重连）
  Future<void> _refresh() async {
    print('🔄 开始刷新连接');
    
    // 手动刷新和自动刷新都执行硬重连
    if (_isManualRefresh) {
      print('👆 检测到手动刷新，执行硬重连');
    } else {
      print('🔄 自动刷新，执行硬重连');
    }
    
    // 执行硬重连
    print('🔄 执行硬重连');
    await _performHardReconnect();
  }

  //退出房间
  void _onDisconnect() async {
    final result = await showOkCancelAlertDialog(
      context: context,
      title: '温馨提示',
      message: '确认要退出房间？',
      okLabel: '确认',
      cancelLabel: '取消',
    );
    if (result == OkCancelResult.ok) {
      try {
        EasyLoading.show(status: '退出中...');
        _onExitRoom();
        await Future.delayed(const Duration(seconds: 1));
      } finally {
        EasyLoading.dismiss();
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  static const double _kControlBarHeight = 100.0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('房间号：${widget.roomId}'),
          centerTitle: true,
          actions: widget.registrationCode != null
              ? [
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Center(child: Text(widget.registrationCode!)),
                  )
                ]
              : null,
        ),
        body: Stack(
          children: [
            // Web端键盘监听层 - 包装整个内容区域
            if (kIsWeb && widget.isCaller && _keyboardFocusNode != null)
              Focus(
                focusNode: _keyboardFocusNode!,
                autofocus: true,
                onKeyEvent: (node, event) {
                  // 只处理按键按下事件
                  if (event is KeyDownEvent && _remoteOn) {
                    print('🎹 检测到按键事件: ${event.logicalKey}');
                    print('🎹 按键详细信息: keyId=${event.logicalKey.keyId}, debugName=${event.logicalKey.debugName}');
                    print('🎹 修饰键状态: ctrl=${event.logicalKey == LogicalKeyboardKey.controlLeft || event.logicalKey == LogicalKeyboardKey.controlRight}, meta=${event.logicalKey == LogicalKeyboardKey.metaLeft || event.logicalKey == LogicalKeyboardKey.metaRight}');
                    
                    // 检测黏贴操作 (Ctrl+V 或 Cmd+V)
                    final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
                    final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
                    final isVKey = event.logicalKey == LogicalKeyboardKey.keyV;
                    
                    if ((isCtrlPressed || isMetaPressed) && isVKey) {
                      print('🎹 检测到黏贴操作 (${isCtrlPressed ? 'Ctrl' : 'Cmd'}+V)');
                      _handlePasteOperation();
                      return KeyEventResult.handled;
                    }
                    
                    // 使用多种方法检测特殊按键
                    final key = event.logicalKey;
                    final keyId = key.keyId;
                    
                    // 方法1：使用预定义常量比较
                    if (key == LogicalKeyboardKey.backspace) {
                      print('🎹 检测到删除键 (方法1: 常量比较)');
                      _handleKeyboardInput('BACKSPACE');
                      return KeyEventResult.handled;
                    } else if (key == LogicalKeyboardKey.enter) {
                      print('🎹 检测到回车键 (方法1: 常量比较)'); 
                      _handleKeyboardInput('ENTER');
                      return KeyEventResult.handled;
                    }
                    // 方法2：使用keyId数值检测
                    else if (keyId == 4294967304 || keyId == 8) { // Backspace的可能keyId值
                      print('🎹 检测到删除键 (方法2: keyId=$keyId)');
                      _handleKeyboardInput('BACKSPACE');
                      return KeyEventResult.handled;
                    } else if (keyId == 4294967309 || keyId == 13) { // Enter的可能keyId值
                      print('🎹 检测到回车键 (方法2: keyId=$keyId)');
                      _handleKeyboardInput('ENTER');
                      return KeyEventResult.handled;
                    }
                    // 方法3：检查字符和控制键
                    else if (event.character == '\b' || (event.character == null && keyId == 8)) {
                      print('🎹 检测到删除键 (方法3: 字符检测)');
                      _handleKeyboardInput('BACKSPACE');
                      return KeyEventResult.handled;
                    } else if (event.character == '\n' || event.character == '\r' || (event.character == null && keyId == 13)) {
                      print('🎹 检测到回车键 (方法3: 字符检测)');
                      _handleKeyboardInput('ENTER');
                      return KeyEventResult.handled;
                    } else {
                      // 处理普通字符（排除修饰键）
                      final character = event.character;
                      if (character != null && character.isNotEmpty && 
                          character != '\b' && character != '\n' && character != '\r' &&
                          !isCtrlPressed && !isMetaPressed) { // 排除修饰键组合
                        print('🎹 检测到普通字符: "$character"');
                        _handleKeyboardInput(character);
                        return KeyEventResult.handled;
                      } else {
                        print('🎹 未处理的按键: keyId=0x${keyId.toRadixString(16)}, character=${event.character}');
                      }
                    }
                  }
                  return KeyEventResult.ignored;
                },
                                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.transparent,
                        ),
              ),
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: (_channel == "sdk")
                        ? (_remoteUid == null)
                        ? const Text('等待对方加入...',
                        style:
                        TextStyle(color: Colors.black, fontSize: 24))
                        : (!widget.isCaller ||
                        _remoteScreenWidth == 0 ||
                        _remoteScreenHeight == 0)
                        ? const Text('正在语音通话中..',
                        style: TextStyle(
                            color: Colors.black, fontSize: 24))
                        : Listener(
                      key: _videoKey,
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (event) {
                        _onPointerDown(event.position);
                      },
                      onPointerMove: (event) {
                        _onPointerMove(event.position);
                      },
                      onPointerUp: (event) {
                        _onPointerUp(event.position);
                      },
                      child: AspectRatio(
                        aspectRatio: _remoteScreenWidth /
                            _remoteScreenHeight,
                      ),
                    )
                        : (_remoteRenderer.srcObject == null && !_showNodeRects && !_hasAnyAudio())
                        ? const Text('等待对方加入..',
                        style:
                        TextStyle(color: Colors.black, fontSize: 24))
                        : (_remoteRenderer.srcObject == null && _remoteHasVideo)
                        ? const Center(
                            child: Text('网络不稳定，正在恢复...',
                                style: TextStyle(color: Colors.black, fontSize: 24)),
                          )
                        : (!_remoteHasVideo)
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                children: [
                                  // 背景层 - 如果显示节点树则使用黑色背景，否则显示语音通话文本
                                  if (_showNodeRects && _nodeRects.isNotEmpty)
                                    Container(
                                      color: Colors.black,
                                    )
                                  else
                                    const Center(
                                      child: Text('正在语音通话中..',
                                          style: TextStyle(
                                              color: Colors.black, fontSize: 24)),
                                    ),
                                  // 远控开启时，添加透明的点击层
                                  if (_remoteOn && widget.isCaller)
                                    Positioned.fill(
                                      child: Listener(
                                        behavior: HitTestBehavior.translucent,
                                        onPointerDown: (event) {
                                          _onPointerDown(event.position);
                                        },
                                        onPointerMove: (event) {
                                          _onPointerMove(event.position);
                                        },
                                        onPointerUp: (event) {
                                          _onPointerUp(event.position);
                                        },
                                        child: Container(
                                          color: Colors.transparent,
                                        ),
                                      ),
                                    ),
                                  // 节点树显示层 - 在语音通话时也显示
                                  if (_showNodeRects && _nodeRects.isNotEmpty)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        ignoring: true,
                                        child: CustomPaint(
                                          painter: _AccessibilityPainter(
                                            _nodeRects.where((node) {
                                              final rect = node.bounds;
                                              // 极宽松：显示几乎所有节点（语音通话时）
                                              return rect.width >= 1 && // 最小宽度1像素
                                                  rect.height >= 1 && // 最小高度1像素
                                                  !rect.isEmpty &&
                                                  rect.left.isFinite &&
                                                  rect.top.isFinite &&
                                                  rect.right.isFinite &&
                                                  rect.bottom.isFinite;
                                            }).toList(),
                                            remoteSize: Size(
                                              _savedRemoteScreenWidth > 0 ? _savedRemoteScreenWidth : _remoteScreenWidth.toDouble(),
                                              _savedRemoteScreenHeight > 0 ? _savedRemoteScreenHeight : _remoteScreenHeight.toDouble(),
                                            ),
                                            containerSize: Size(
                                              constraints.maxWidth,
                                              constraints.maxHeight,
                                            ),
                                            fit: BoxFit.contain,
                                            statusBarHeight: MediaQuery.of(context).padding.top,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          )
                        : LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Listener(
                              behavior:
                              HitTestBehavior.translucent,
                              onPointerDown: (event) {
                                _onPointerDown(event.position);
                              },
                              onPointerMove: (event) {
                                _onPointerMove(event.position);
                              },
                              onPointerUp: (event) {
                                _onPointerUp(event.position);
                              },
                              child: RTCVideoView(
                                _remoteRenderer,
                                mirror: false,
                                filterQuality: FilterQuality.none,
                                objectFit:
                                RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitContain,
                                key: _videoKey,
                              ),
                            ),
                            // 节点树显示层 - 在RTCVideoView的Stack内部，确保坐标准确
                            if (_showNodeRects && _nodeRects.isNotEmpty)
                                                                  Positioned.fill(
                                      child: IgnorePointer(
                                        ignoring: true,
                                        child: CustomPaint(
                                          painter: _AccessibilityPainter(
                                            _nodeRects.where((node) {
                                              final rect = node.bounds;
                                              // 极宽松：显示几乎所有节点（视频通话时）
                                              return rect.width >= 1 && // 最小宽度1像素
                                                  rect.height >= 1 && // 最小高度1像素
                                                  !rect.isEmpty &&
                                                  rect.left.isFinite &&
                                                  rect.top.isFinite &&
                                                  rect.right.isFinite &&
                                                  rect.bottom.isFinite;
                                            }).toList(),
                                            remoteSize: Size(
                                              // 优先使用保存的分辨率，如果没有则使用当前分辨率
                                              _savedRemoteScreenWidth > 0 ? _savedRemoteScreenWidth : _remoteScreenWidth.toDouble(),
                                              _savedRemoteScreenHeight > 0 ? _savedRemoteScreenHeight : _remoteScreenHeight.toDouble(),
                                            ),
                                            containerSize: Size(
                                              constraints.maxWidth,
                                              constraints.maxHeight,
                                            ),
                                            fit: BoxFit.contain,
                                            statusBarHeight: MediaQuery.of(context).padding.top,
                                          ),
                                        ),
                                      ),
                                    ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                if (!widget.isCaller)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '通话时间：${_formatDuration(_callDuration)}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                // 2️⃣ 底部控制栏
                if (widget.isCaller)
                  SizedBox(
                    height: _kControlBarHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: _buildControlButtons(),
                    ),
                  ),
              ],
            ),
            if (_remoteOn && widget.isCaller)
              Positioned(
                left: _buttonGroupPosition!.dx,
                top: _buttonGroupPosition!.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _buttonGroupPosition =
                          _buttonGroupPosition! + details.delta;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_channel == 'cf') {
                              _signaling?.sendCommand({'type': 'tapBack'});
                            }
                          },
                          child: const Icon(Icons.arrow_back,
                              size: 32, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            if (_channel == 'cf') {
                              _signaling?.sendCommand({'type': 'tapHome'});
                            }
                          },
                          child:
                          const Icon(Icons.home, size: 32, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            if (_channel == 'cf') {
                              _signaling?.sendCommand({'type': 'tapRecent'});
                            }
                          },
                          child: const Icon(Icons.dashboard,
                              size: 32, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                            onTap: () => _changeBlackScreen(),
                            child: Icon(
                                _showBlack
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 32,
                                color: Colors.white)),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () =>_changeShowNodeTree(),
                          child: Icon(_showNodeRects ? Icons.code : Icons.code_off,
                              size: 32, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


  // 点击刷新时的处理
  Future<void> _onRefreshPressed() async {
    if (!_canRefresh) return;
    
    // 显示确认对话框
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认刷新'),
          content: const Text('是否刷新？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    // 用户取消了操作
    if (confirmed != true) return;
    
    // 确认后立即禁用按钮，开始5秒冷却
    setState(() {
      _canRefresh = false;
      _isManualRefresh = true; // 标记为手动刷新
    });
    
    // 显示手动刷新提示
    EasyLoading.showToast('正在刷新，请稍候...', duration: const Duration(seconds: 2));
    
    try {
      await _refresh(); // 执行刷新方法
    } finally {
      // 立即重置手动刷新标记
      if (mounted) {
        setState(() => _isManualRefresh = false);
      }
      
      // 5 秒后恢复按钮可用
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _canRefresh = true);
        }
      });
    }
  }

  Widget _buildControlButtons() {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        IconButton(
          disabledColor: Colors.grey,
          onPressed: _setMicphoneOn,
          icon: Icon(_micphoneOn ? Icons.mic : Icons.mic_off),
          tooltip: '开关自己的麦克风',
        ),
        IconButton(
          onPressed: _canShareScreen ? _changeContributorScreen : null,
          icon: Icon(
              _screenShareOn ? Icons.phone_android : Icons.phonelink_erase),
          tooltip: '开关对方屏幕',
        ),
        IconButton(
          disabledColor: Colors.grey,
          onPressed: _setContributorSpeakerphoneOn,
          icon: Icon(_contributorSpeakerphoneOn
              ? Icons.headset_mic
              : Icons.headset_off),
          tooltip: '开关对方麦克风',
        ),
        IconButton(
          onPressed: _changeIntercept,
          icon: Icon(_interceptOn ? Icons.phone_disabled : Icons.phone_enabled),
          tooltip: '开关拦截对方电话',
        ),
        IconButton(
          onPressed: _changeRemotoe,
          icon: Icon(_remoteOn ? Icons.cloud : Icons.cloud_off_rounded),
          tooltip: '开关远程控制',
        ),
        IconButton(
          onPressed: _canRefresh ? _onRefreshPressed : null,
          icon: const Icon(Icons.refresh),
          tooltip: '刷新',
          disabledColor: Colors.grey,
        ),
        IconButton(
          onPressed: _onDisconnect,
          icon: const Icon(Icons.close_sharp),
          tooltip: '退出房间',
        ),
      ],
    );
  }
}

class _AccessibilityPainter extends CustomPainter {
  final List<_AccessibilityNode> nodes;
  final Size remoteSize;
  final Size containerSize;
  final BoxFit fit;
  final double statusBarHeight;

  _AccessibilityPainter(
      this.nodes, {
        required this.remoteSize,
        required this.containerSize,
        required this.fit,
        required this.statusBarHeight,
      });

  @override
  void paint(Canvas canvas, Size size) {
    // 使用传入的remoteSize，这应该是保存的分辨率或当前分辨率
    final effectiveRemoteSize = remoteSize;
    
    final FittedSizes fittedSizes = applyBoxFit(fit, effectiveRemoteSize, containerSize);
    final Size displaySize = fittedSizes.destination;
    final double scaleX = displaySize.width / effectiveRemoteSize.width;
    final double scaleY = displaySize.height / effectiveRemoteSize.height;
    final double dx = (containerSize.width - displaySize.width) / 2;
    final double dy = (containerSize.height - displaySize.height) / 2;

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final node in nodes) {
      final scaled = Rect.fromLTRB(
        node.bounds.left * scaleX + dx,
        node.bounds.top * scaleY + dy,
        node.bounds.right * scaleX + dx,
        node.bounds.bottom * scaleY + dy,
      );

      canvas.drawRect(scaled, paint);

      // 只有非空标签才绘制文字
      if (node.label.isNotEmpty) {
        // 初始字体大小
        double fontSize = 12;
        TextPainter tp;
        do {
          tp = TextPainter(
            text: TextSpan(
              text: node.label,
              style: TextStyle(color: Colors.red, fontSize: fontSize),
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            maxLines: null,
          );
          tp.layout(maxWidth: scaled.width);
          fontSize -= 0.5;
        } while ((tp.height > scaled.height || tp.width > scaled.width) && fontSize > 6);

        // fallback：如果太小仍然超出，最多一行+省略号
        if (tp.height > scaled.height || tp.width > scaled.width) {
          tp = TextPainter(
            text: TextSpan(
              text: node.label,
              style: const TextStyle(color: Colors.red, fontSize: 6),
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            maxLines: 1,
            ellipsis: '…',
          );
          tp.layout(maxWidth: scaled.width);
        }

        final offset = Offset(
          scaled.left + (scaled.width - tp.width) / 2,
          scaled.top + (scaled.height - tp.height) / 2,
        );
        tp.paint(canvas, offset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
class _AccessibilityNode {
  final Rect bounds;
  final String label;

  _AccessibilityNode({required this.bounds, required this.label});
}