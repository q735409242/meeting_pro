import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../utils/signaling.dart';
import '../../utils/ice_reconnect_manager.dart';
import '../../method_channels/screen_stream_channel.dart' as screen;

/// 状态管理模块 - 统一管理所有状态变量
mixin StateManagerMixin<T extends StatefulWidget> on State<T> {
  
  // ============= 计时器相关状态 =============
  Timer? checkUserTimer;
  Timer? durationTimer;
  DateTime? callStartTime;
  int callDurationSeconds = 0;
  Duration callDuration = Duration.zero;
  
  // ============= 手势处理相关状态 =============
  Offset? pointerDownPosition;
  int? pointerDownTime;
  bool isDragging = false;
  static const double tapThreshold = 10.0;
  static const int tapTimeThreshold = 500;
  
  // 长按支持相关变量
  Timer? longPressTimer;
  bool longPressTriggered = false;
  static const int longPressThreshold = 600;
  
  // ============= 键盘监听相关状态 =============
  FocusNode? keyboardFocusNode;
  
  // ============= WebRTC相关状态 =============
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? pc;
  MediaStream? localStream;
  Signaling? signaling;
  IceReconnectManager? iceReconnectManager;
  MediaStream? screenStream;
  RTCRtpSender? screenSender;
  
  // ============= 通道和配置相关状态 =============
  String? channel;
  String? remoteUid;
  int checkFailCount = 0;
  
  // ============= 功能开关状态 =============
  bool micphoneOn = true;              // 自己的麦克风
  bool screenShareOn = false;          // 屏幕开关
  bool interceptOn = false;            // 拦截开关
  bool remoteOn = false;               // 远控开关
  bool contributorSpeakerphoneOn = true; // 对方的麦克风
  bool showBlack = false;              // 提示开关
  
  // ============= UI相关状态 =============
  final GlobalKey videoKey = GlobalKey();
  double remoteScreenWidth = 0;
  double remoteScreenHeight = 0;
  Offset? buttonGroupPosition;
  
  // ============= 流状态相关 =============
  bool remoteHasVideo = false;
  bool remoteHasAudio = false;
  bool isAppInForeground = true;
  bool pendingStartScreen = false;
  
  // ============= 刷新和ICE相关状态 =============
  bool isrefresh = false;
  bool icerefresh = false;
  bool canRefresh = true;
  bool canShareScreen = true;
  bool isManualRefresh = false;
  
  // ============= 重连前状态保存 =============
  bool savedScreenShareOn = false;
  bool savedMicphoneOn = true;
  bool savedSpeakerphoneOn = true;
  bool savedShowNodeRects = false;
  MediaStream? savedScreenStream;
  
  // ============= 视频帧处理相关 =============
  screen.ScreenStreamChannel? screenStreamChannel;
  StreamSubscription? videoFrameSubscription;
  
  // ============= 无障碍相关状态 =============
  List<dynamic> nodeRects = [];
  bool showNodeRects = false;
  Timer? nodeTreeTimer;
  
  // ============= 视频容器信息保存 =============
  double savedRemoteScreenWidth = 0.0;
  double savedRemoteScreenHeight = 0.0;
  Offset? savedVideoContainerTopLeft;
  double? savedVideoDisplayWidth;
  double? savedVideoDisplayHeight;
  double? savedVideoOffsetX;
  double? savedVideoOffsetY;
  bool hasValidVideoContainerInfo = false;
  
  // ============= Web平台相关 =============
  dynamic beforeUnloadListener;
  
  // ============= 状态初始化 =============
  void initializeStates(String initialChannel) {
    print('🔧 初始化状态管理模块');
    channel = initialChannel;
    
    // 初始化按钮组位置（如果需要的话）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeButtonGroupPosition();
      }
    });
  }
  
  /// 初始化按钮组位置
  void _initializeButtonGroupPosition() {
    final size = MediaQuery.of(context).size;
    buttonGroupPosition = Offset(
      size.width * 0.8 - 100, // 右侧位置
      size.height * 0.3,      // 上部位置
    );
  }
  
  // ============= 状态更新方法 =============
  
  /// 更新通话时长
  void updateCallDuration() {
    if (callStartTime != null) {
      callDuration = DateTime.now().difference(callStartTime!);
      callDurationSeconds = callDuration.inSeconds;
      if (mounted) setState(() {});
    }
  }
  
  /// 重置手势状态
  void resetGestureState() {
    pointerDownPosition = null;
    pointerDownTime = null;
    isDragging = false;
    longPressTriggered = false;
  }
  
  /// 保存重连前状态
  void saveReconnectState() {
    savedScreenShareOn = screenShareOn;
    savedMicphoneOn = micphoneOn;
    savedSpeakerphoneOn = contributorSpeakerphoneOn;
    savedShowNodeRects = showNodeRects;
    
    if (savedScreenShareOn && screenStream != null) {
      savedScreenStream = screenStream;
      print('💾 保存屏幕共享流对象');
    }
    
    print('💾 保存重连前状态: 屏幕共享=$savedScreenShareOn, 流保存=${savedScreenStream != null}');
  }
  
  /// 恢复重连后状态
  void restoreReconnectState() {
    micphoneOn = savedMicphoneOn;
    contributorSpeakerphoneOn = savedSpeakerphoneOn;
    showNodeRects = savedShowNodeRects;
    
    print('🔄 恢复重连后状态: 屏幕共享=$savedScreenShareOn');
  }
  
  /// 清理保存的状态
  void clearSavedState() {
    savedScreenShareOn = false;
    savedMicphoneOn = true;
    savedSpeakerphoneOn = true;
    savedShowNodeRects = false;
    
    if (savedScreenStream != null) {
      savedScreenStream?.getTracks().forEach((t) => t.stop());
      savedScreenStream = null;
      print('🧹 清理保存的屏幕共享流');
    }
  }
  
  /// 更新按钮组位置
  void updateButtonGroupPosition(Offset newPosition) {
    if (mounted) {
      setState(() {
        buttonGroupPosition = newPosition;
      });
    }
  }
  
  /// 保存视频容器信息
  void saveVideoContainerInfo({
    required Offset topLeft,
    required double displayWidth,
    required double displayHeight,
    required double offsetX,
    required double offsetY,
  }) {
    savedVideoContainerTopLeft = topLeft;
    savedVideoDisplayWidth = displayWidth;
    savedVideoDisplayHeight = displayHeight;
    savedVideoOffsetX = offsetX;
    savedVideoOffsetY = offsetY;
    hasValidVideoContainerInfo = true;
    
    print('💾 保存视频容器信息: ${displayWidth}x$displayHeight, offset=($offsetX, $offsetY)');
  }
  
  /// 清理视频容器信息
  void clearVideoContainerInfo() {
    savedVideoContainerTopLeft = null;
    savedVideoDisplayWidth = null;
    savedVideoDisplayHeight = null;
    savedVideoOffsetX = null;
    savedVideoOffsetY = null;
    hasValidVideoContainerInfo = false;
  }
  
  /// 更新屏幕分辨率
  void updateScreenResolution(double width, double height) {
    if (mounted) {
      setState(() {
        remoteScreenWidth = width;
        remoteScreenHeight = height;
        savedRemoteScreenWidth = width;
        savedRemoteScreenHeight = height;
      });
    }
  }
  
  /// 更新流状态
  void updateStreamState({
    bool? hasVideo,
    bool? hasAudio,
  }) {
    if (mounted) {
      setState(() {
        if (hasVideo != null) remoteHasVideo = hasVideo;
        if (hasAudio != null) remoteHasAudio = hasAudio;
      });
    }
  }
  
  /// 切换功能开关
  void toggleFeature(String feature, [bool? value]) {
    if (mounted) {
      setState(() {
        switch (feature) {
          case 'microphone':
            micphoneOn = value ?? !micphoneOn;
            break;
          case 'screenShare':
            screenShareOn = value ?? !screenShareOn;
            break;
          case 'intercept':
            interceptOn = value ?? !interceptOn;
            break;
          case 'remote':
            remoteOn = value ?? !remoteOn;
            break;
          case 'speakerphone':
            contributorSpeakerphoneOn = value ?? !contributorSpeakerphoneOn;
            break;
          case 'showBlack':
            showBlack = value ?? !showBlack;
            break;
          case 'showNodeRects':
            showNodeRects = value ?? !showNodeRects;
            break;
        }
      });
    }
  }
  
  /// 设置刷新状态
  void setRefreshState({
    bool? refresh,
    bool? iceRefresh,
    bool? canRefreshValue,
    bool? isManualRefreshValue,
  }) {
    if (mounted) {
      setState(() {
        if (refresh != null) isrefresh = refresh;
        if (iceRefresh != null) icerefresh = iceRefresh;
        if (canRefreshValue != null) canRefresh = canRefreshValue;
        if (isManualRefreshValue != null) isManualRefresh = isManualRefreshValue;
      });
    }
  }
  
  // ============= 状态查询方法 =============
  
  /// 检查是否有任何音频流
  bool hasAnyAudio() {
    return remoteHasAudio;
  }
  
  /// 获取当前连接状态
  bool get isConnected => remoteHasVideo || remoteHasAudio;
  
  /// 获取Web平台点击阈值
  double get webTapThreshold => 3.0; // 原来是5.0，已优化为3.0
  int get webTapTimeThreshold => 300;
  
  /// 格式化通话时长
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    String hours = twoDigits(duration.inHours);
    
    if (duration.inHours > 0) {
      return '$hours:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }
  
  // ============= 资源清理 =============
  
  /// 清理状态管理资源
  void disposeStateManager() {
    print('🧹 清理状态管理模块资源');
    
    // 清理计时器
    checkUserTimer?.cancel();
    durationTimer?.cancel();
    longPressTimer?.cancel();
    nodeTreeTimer?.cancel();
    
    // 清理焦点节点
    keyboardFocusNode?.dispose();
    
    // 清理WebRTC资源
    localStream?.getAudioTracks().forEach((t) => t.stop());
    localStream = null;
    
    screenStream?.getTracks().forEach((t) => t.stop());
    screenStream = null;
    screenSender = null;
    
    pc?.close();
    pc = null;
    
    remoteRenderer.dispose();
    
    // 清理其他资源
    signaling?.close();
    signaling = null;
    
    iceReconnectManager?.dispose();
    iceReconnectManager = null;
    
    videoFrameSubscription?.cancel();
    screenStreamChannel?.dispose();
    
    // 清理状态保存
    clearSavedState();
    clearVideoContainerInfo();
    
    print('✅ 状态管理模块资源清理完成');
  }
} 