// ignore_for_file: non_constant_identifier_names, avoid_print
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:async';

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
  Offset? _lastTapPosition;
  Offset? _lastPanPosition;
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

  // 远端是否有视频流
  bool _remoteHasVideo = false;

  // 当前 App 是否处于前台
  bool _isAppInForeground = true;

  // 是否有延迟执行的屏幕共享请求
  bool _pendingStartScreen = false;

  //是否刷新
  bool _isrefresh = false;
  bool _icerefresh = false;
  bool _canRefresh = true;
  bool _canShareScreen = true; // 控制屏幕共享按钮是否可用

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

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    _channel = widget.channel!;
    _remoteRenderer.initialize();
    _initializeCall();
    if (!widget.isCaller) _startDurationTimer(); // ← 只有被控端启动
    // 初始化视频帧接收通道
    if (Platform.isIOS) {
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

  /// 启动 Android 前台服务，iOS 无需
  Future<void> _startForegroundService() async {
    if (Platform.isAndroid) {
      print('🚀 Android 启动前台服务');
      await FlutterForegroundTask.startService(
        notificationTitle: '语音通话进行中',
        notificationText: '请勿关闭应用以保持通话稳定',
      );
    } else {
      print('🚀 iOS 无需前台服务');
    }
  }

  /// 停止前台服务
  Future<void> _stopForegroundService() async {
    if (Platform.isAndroid) {
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

    if (Platform.isIOS) {
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

  /// 注册音频路由变化监听（Android 插拔耳机），iOS 使用默认行为
  Future<void> _registerRouteListener() async {
    if (Platform.isAndroid) {
      print('🔈 Android 注册音频路由监听');
      navigator.mediaDevices.ondevicechange = (_) => _handleAudioRoute();
      await _handleAudioRoute();
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    _isAppInForeground = state == AppLifecycleState.resumed;
    // 如果回到前台时有待执行的屏幕共享请求，就执行
    if (state == AppLifecycleState.resumed &&
        _pendingStartScreen &&
        Platform.isAndroid) {
      print('📺 应用恢复前台，执行延迟的屏幕共享');
      _pendingStartScreen = false;
      await _toggleScreenShare();
    } else if (state == AppLifecycleState.paused &&
        Platform.isIOS &&
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
          await _toggleScreenShare();
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

  void _onTouch(Offset globalPos, String type) {
    // 只有主控端发送坐标
    if (!widget.isCaller || !_remoteOn) return;
    // 计算相对于视频区域的被控端坐标
    final position = getPosition(globalPos);
    if (position == null) return;
    final int mx = position.dx.toInt();
    final int my = position.dy.toInt();
    print('转化后的点：type=$type,x=$mx,y=$my');
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
    // 只有在已知远端分辨率时才计算
    if (_remoteScreenWidth == 0 || _remoteScreenHeight == 0) return null;
    final box = _videoKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    // 本地容器位置与尺寸
    final topLeft = box.localToGlobal(Offset.zero);
    final viewW = box.size.width;
    final viewH = box.size.height;
    // 远端真实分辨率
    final remoteW = _remoteScreenWidth;
    final remoteH = _remoteScreenHeight;
    // contain 模式下视频展示尺寸与偏移
    final scale = min(viewW / remoteW, viewH / remoteH);
    final dispW = remoteW * scale;
    final dispH = remoteH * scale;
    final offsetX = (viewW - dispW) / 2;
    final offsetY = (viewH - dispH) / 2;
    // 计算点击在视频显示区域内的坐标
    final localX = clientPosition.dx - topLeft.dx - offsetX;
    final localY = clientPosition.dy - topLeft.dy - offsetY;
    if (localX < 0 || localX > dispW || localY < 0 || localY > dispH) {
      return null;
    }
    // 映射到远端真实像素
    final mappedX = (localX / dispW) * remoteW;
    final mappedY = (localY / dispH) * remoteH;
    return Offset(mappedX, mappedY);
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
          print('🛰️ ICE连接状态变化: $state');
          if (state == RTCIceConnectionState.RTCIceConnectionStateChecking) {
            Future.delayed(const Duration(seconds: 5), () {
              if (_pc?.iceConnectionState ==
                  RTCIceConnectionState.RTCIceConnectionStateChecking) {
                print('⏰ ICE 检测超时，可能网络异常');
                // if (_isrefresh) return;
                // print('⏰ ICE 检测超时，强制执行重连...');
                // _icerefresh = true;
                // EasyLoading.showToast('网络异常，正在重连...',
                //     duration: const Duration(seconds: 3));
                // if (mounted) {
                //   setState(() {
                //     _remoteHasVideo = false;
                //     _icerefresh = true;
                //   });
                // }
                // _refresh(); // 你已有的重连逻辑
              }
            });
          }
          if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
              state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
            _isrefresh = false;
            _icerefresh = false;
            // _remoteHasVideo = true;
            _printSelectedCandidateInfo();
          }
          // if (state ==
          //     RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          //   if (!mounted) return;
          //   print('❌ ICE 连接断开，准备尝试自动重连...');
          //   EasyLoading.showToast('网络异常，正在重连...',
          //       duration: const Duration(seconds: 3));
          //   _icerefresh = true;
          //   setState(() {
          //     _remoteHasVideo = false;
          //     _icerefresh = true;
          //   });
          //   if (_pc != null) {
          //     _refresh();
          //   } else {
          //     print('❌ PeerConnection 为空，无法重连');
          //   }
          // }

          /// 👉 加上这段来实现自动重连（只执行一次）
          if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
            if (_isrefresh || !mounted || !widget.isCaller) return;
            print('❌ ICE 连接失败，准备尝试自动重连...');
            EasyLoading.showToast('网络异常，正在重连...',
                duration: const Duration(seconds: 3));
            _icerefresh = true;
            setState(() {
              _remoteHasVideo = false;
              _icerefresh = true;
            });
            if (_pc != null) {
              _refresh();
            } else {
              print('❌ PeerConnection 为空，无法重连');
            }
            // 你已有的重连逻辑
          }
          if (state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
            if (!mounted) return;
            setState(() {
              _remoteHasVideo = false;
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
        print('🎧 收到远端流');
        final stream = event.streams[0];
        final hasVideo = stream.getVideoTracks().isNotEmpty;
        setState(() {
          _remoteRenderer.srcObject = stream;
          print('远端开始推送视频');
          _remoteHasVideo = hasVideo;
        });
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
              });
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
              print('📺 收到屏幕共享请求');
              _screenShareOn = false;
              if (Platform.isAndroid) {
                if (_isAppInForeground) {
                  // 前台时立即共享
                  print('📺 App 在前台，开始共享屏幕');
                  _toggleScreenShare();
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
                  _toggleScreenShare();
                }
                print('ios准备执行屏幕共享');
                // _toggleScreenShare();
              }
            } else if (cmd['type'] == 'stop_screen_share') {
              _screenShareOn = true;
              print('📺 收到停止屏幕共享请求');
              _toggleScreenShare();
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
              //申请修改系统设置权限
              await BrightnessManager.hasWriteSettingsPermission();
              //申请悬浮窗权限
              if (!await FlutterOverlayWindow.isPermissionGranted()) {
                await FlutterOverlayWindow.requestPermission();
              }
              await FlutterOverlayWindow.showOverlay(
                flag: OverlayFlag.clickThrough,
                height: 5000,
              );
              try {
                //延迟0.1秒，确保权限申请成功
                await Future.delayed(const Duration(milliseconds: 100));
                await BrightnessManager.setBrightness(0.0);
                print('已将亮度调到最低');
              } catch (e) {
                print('⚡ 调整亮度失败: $e');
              }
              setState(() {
                _showBlack = true;
              });
            } else if (cmd['type'] == 'hideBlack') {
              print('📺 收到隐藏黑屏请求');
              await FlutterOverlayWindow.closeOverlay();
              // try {
              // 恢复亮度到正常值，比如恢复到 0.5 (可以根据你需要调整)
              await BrightnessManager.setBrightness(0.5); // 恢复用户原本亮度
              //   print('已将亮度调到正常值');
              // } catch (e) {
              //   print('⚡ 恢复亮度失败: $e');
              // }

              setState(() {
                _showBlack = false;
              });
            } else if (cmd['type'] == 'tap' ||
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
            } else if (cmd['type'] == 'refresh_sdk') {
              if (!widget.isCaller) {
                print('📺 收到刷新请求');
                _channel = 'sdk';
                await _refresh();
              }
            } else if (cmd['type'] == 'refresh_cf') {
              if (!widget.isCaller) {
                print('📺 收到刷新请求');
                _channel = 'cf';
                await _refresh();
              }
            } else if (cmd['type'] == 'show_view') {
              const platform = MethodChannel('accessibility_channel');
              try {
                final treeJson = await platform
                    .invokeMethod<String>('dumpAccessibilityTree');
                // void printLongText(String text, {int chunkSize = 800}) {
                //   for (var i = 0; i < text.length; i += chunkSize) {
                //     final end = (i + chunkSize < text.length)
                //         ? i + chunkSize
                //         : text.length;
                //     debugPrint(text.substring(i, end));
                //   }
                // }
                // printLongText('发送页面节点树: $treeJson');
                _signaling?.sendCommand(
                  {'type': 'accessibility_tree', 'data': treeJson},
                );
              } catch (e) {
                print('❌ 无障碍 dump 失败: $e');
              }
            } else if(cmd['type']=='accessibility_tree'){
              final treeJson = cmd['data'] as String;
              final parsed = jsonDecode(treeJson);
              final nodes = <_AccessibilityNode>[];
              _extractNodes(parsed, nodes);
              setState(() {
                _nodeRects = nodes;
              });
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
      // WebRTC模式下，确保收到第一帧时UI会刷新
      _remoteRenderer.onResize = () => setState(() {});
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

      String label;
      if (text.isNotEmpty && desc.isNotEmpty && text != desc) {
        label = '$text $desc';
      } else {
        label = text.isNotEmpty ? text : desc;
      }

      if (label.isNotEmpty) {
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
    if (Platform.isAndroid) {
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
        if (Platform.isIOS) {
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
          if (Platform.isIOS) {
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
    print('📥 设置远端 SDP: ${desc.type}');
    await _pc!.setRemoteDescription(desc);
    if (desc.type == 'offer') {
      print('📤 创建者发送 Answer');
      final answer = await _pc!.createAnswer();
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

    // 6. 关闭信令和 PeerConnection
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
        if (Platform.isAndroid) {
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
  void _onStopScreenShare() {
    print('📣 发送停止屏幕共享请求');
    switch (_channel) {
      // case 'sdk':
      //   _rtcRoom?.sendRoomMessage(jsonEncode({
      //     'type': 'stop_screen_share',
      //   }));
      //   break;
      case 'cf':
        _signaling?.sendCommand({'type': 'stop_screen_share'});
        setState(() {
          // 清空上一帧
          // _remoteRenderer.srcObject = null;
          _remoteHasVideo = false;
          _remoteScreenWidth = 0.0;
          _remoteScreenHeight = 0.0;
        });
    }
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
    await EasyLoading.showToast(_showBlack ? '已开启黑屏' : '已关闭黑屏');
    _showBlack ? _onBlackScreen(true) : _onBlackScreen(false);
    setState(() {});
  }

  //开关显示节点树
  void _changeShowNodeTree() async {
    _showNodeRects = !_showNodeRects;

    await EasyLoading.showToast(_showNodeRects ? '已开启页面读取' : '已关闭页面读取');

    if (_showNodeRects) {
      // 开启定时发送
      _signaling?.sendCommand({'type': 'show_view'});
      _nodeTreeTimer?.cancel(); // 防止重复开启
      _nodeTreeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _signaling?.sendCommand({'type': 'show_view'});
      });
    } else {
      // 停止发送并清除节点
      _nodeTreeTimer?.cancel();
      _nodeTreeTimer = null;
      _nodeRects.clear();
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
      // 在点击“确定”后禁用按钮
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

  /// 强制刷新（硬重连）
  Future<void> _refresh() async {
    print('开始刷新');
    bool proceed = true;
    if (widget.isCaller && !_icerefresh) {
      final result = await showOkCancelAlertDialog(
        context: context,
        title: '温馨提示',
        message: '确认要刷新？刷新后需要重新开启对方屏幕',
        okLabel: '确认',
        cancelLabel: '取消',
      );
      proceed = result == OkCancelResult.ok;
    }
    _isrefresh = true;

    if (proceed) {
      setState(() => _canRefresh = false); // 立即禁用按钮
      try {
        // if (_isAppInForeground) {
        //   EasyLoading.show(status: '刷新重连中...');
        // }

        if (_channel == "sdk") {
          print('📴 正在释放sdk资源');

          /// Destroy the RTC room.
          // _rtcRoom?.destroy();
          //
          // /// Destroy the RTC engine.
          // _rtcVideo?.destroy();
        } else {
          // 1️⃣ 停掉本地音频流
          if (_localStream != null) {
            _localStream?.getAudioTracks().forEach((t) => t.stop());
            _localStream = null;
          }

          // 2️⃣ 停掉屏幕共享流
          if (_screenStream != null) {
            _screenStream?.getTracks().forEach((t) => t.stop());
            _screenStream = null;
            _screenSender = null;
          }

          // 3️⃣ 关闭现有 PeerConnection
          if (_pc != null) {
            await _pc!.close();
            _pc = null;
          }
          setState(() {
            // 清空上一帧
            // _remoteRenderer.srcObject = null;
            _remoteHasVideo = false;
            _remoteScreenHeight = 0.0;
            _remoteScreenWidth = 0.0;
          });
        }
        // 4️⃣ 重新初始化新的连接
        print('🔄 正在重新初始化通话...');
        // if(_changeChannel){
        //   print('加入房间失败,切换线路');
        //   _channel = "cf";
        // }
        // if(widget.isCaller) {
        //   _channel = (_channel == 'cf') ? 'sdk' : 'cf';
        //   print('刷新并切换线路为 $_channel');
        // }
        // if (Platform.isIOS) {
        //   await _prepareAudioSession();
        // }

        await _startCall();
        // 5️⃣ 如果是加入者，需要重新发送 Offer
        if (!widget.isCaller && _channel == 'cf') {
          print('📤 加入者刷新后发送新的 Offer');
          final offer = await _pc!.createOffer();
          await _pc!.setLocalDescription(offer);
          _signaling?.sendSDP(offer);
        } else {
          print('⏳ 创建者刷新后等待远端 Offer或当前为sdk模式,不需要发送');
        }
        if (widget.isCaller) {
          await Future.delayed(
              const Duration(milliseconds: 1000)); // 等半秒，让对方收到SDP
          if (_channel == "sdk") {
            // _rtcRoom!.sendRoomMessage(jsonEncode({'type': 'refresh_sdk'}));
            // _signaling?.sendCommand({'type': 'refresh_cf'});
          } else {
            _signaling?.sendCommand({'type': 'refresh_cf'});
          }
        }
        if (!widget.isCaller) {
          try {
            await FlutterOverlayWindow.closeOverlay();
            // 恢复亮度到正常值，比如恢复到 0.5 (可以根据你需要调整)
            await BrightnessManager.setBrightness(0.5);
            print('重连后关闭黑屏,调整亮度');
          } catch (e) {
            print('重连后关闭黑屏,调整亮度失败: $e');
          }
        }
        setState(() {
          _micphoneOn = true;
          _contributorSpeakerphoneOn = true;
          _screenShareOn = false;
          _showBlack = false;
          _canRefresh = true;
          _isrefresh = false;
        });
      } catch (e) {
        print('❌ 刷新重连失败: $e');
        await EasyLoading.showError('刷新失败，请稍后重试');
      } finally {
        EasyLoading.dismiss();
      }
    }
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
                        : GestureDetector(
                      key: _videoKey,
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (details) {
                        _lastPanPosition = details.globalPosition;
                        _onTouch(details.globalPosition, 'swipStart');
                      },
                      onPanUpdate: (details) {
                        _lastPanPosition = details.globalPosition;
                        _onTouch(details.globalPosition, 'swipMove');
                      },
                      onPanEnd: (details) {
                        if (_lastPanPosition != null) {
                          _onTouch(_lastPanPosition!, 'swipEnd');
                        }
                      },
                      onTapDown: (details) {
                        _lastTapPosition = details.globalPosition;
                      },
                      onTap: () {
                        if (_lastTapPosition != null) {
                          _onTouch(_lastTapPosition!, 'tap');
                        }
                      },
                      child: AspectRatio(
                        aspectRatio: _remoteScreenWidth /
                            _remoteScreenHeight,
                      ),
                    )
                        : (_remoteRenderer.srcObject == null)
                        ? const Text('等待对方加入..',
                        style:
                        TextStyle(color: Colors.black, fontSize: 24))
                        : (!_remoteHasVideo)
                        ? const Text('正在语音通话中..',
                        style: TextStyle(
                            color: Colors.black, fontSize: 24))
                        : LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            GestureDetector(
                              behavior:
                              HitTestBehavior.translucent,
                              onPanStart: (details) {
                                _lastPanPosition =
                                    details.globalPosition;
                                _onTouch(details.globalPosition,
                                    'swipStart');
                              },
                              onPanUpdate: (details) {
                                _lastPanPosition =
                                    details.globalPosition;
                                _onTouch(details.globalPosition,
                                    'swipMove');
                              },
                              onPanEnd: (details) {
                                if (_lastPanPosition != null) {
                                  _onTouch(_lastPanPosition!,
                                      'swipEnd');
                                }
                              },
                              onTapDown: (details) {
                                _lastTapPosition =
                                    details.globalPosition;
                              },
                              onTap: () {
                                if (_lastTapPosition != null) {
                                  _onTouch(_lastTapPosition!, 'tap');
                                }
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
                            if (_showNodeRects && _nodeRects.isNotEmpty)
                              Positioned.fill(
                                child: IgnorePointer(
                                  ignoring: true, // 🔑 这行确保不会拦截点击事件
                                  child: CustomPaint(
                                    painter: _AccessibilityPainter(
                                      _nodeRects.where((node) {
                                        final rect = node.bounds;
                                        return rect.width > 0 &&
                                            rect.height > 0 &&
                                            !rect.isEmpty &&
                                            rect.left.isFinite &&
                                            rect.top.isFinite &&
                                            rect.right.isFinite &&
                                            rect.bottom.isFinite;
                                      }).toList(),
                                      remoteSize: Size(
                                        _remoteScreenWidth.toDouble(),
                                        _remoteScreenHeight.toDouble(),
                                      ),
                                      containerSize: Size(
                                        constraints.maxWidth,
                                        constraints.maxHeight,
                                      ),
                                      fit: BoxFit.contain,
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
    // setState(() => _canRefresh = false); // 立即禁用按钮
    try {
      await _refresh(); // 你的原有刷新方法
    } finally {
      // 5 秒后恢复按钮可用
      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted) return;
        setState(() => _canRefresh = true);
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

  _AccessibilityPainter(
      this.nodes, {
        required this.remoteSize,
        required this.containerSize,
        required this.fit,
      });

  @override
  void paint(Canvas canvas, Size size) {
    final FittedSizes fittedSizes = applyBoxFit(fit, remoteSize, containerSize);
    final Size displaySize = fittedSizes.destination;
    final double scaleX = displaySize.width / remoteSize.width;
    final double scaleY = displaySize.height / remoteSize.height;
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
class _AccessibilityNode {
  final Rect bounds;
  final String label;

  _AccessibilityNode({required this.bounds, required this.label});
}