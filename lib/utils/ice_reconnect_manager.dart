import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// ICE重连管理器 - 提供智能的ICE重连策略
class IceReconnectManager {
  final RTCPeerConnection peerConnection;
  final VoidCallback? onReconnectStart;
  final VoidCallback? onReconnectSuccess;
  final Function(String error)? onReconnectFailed;
  final VoidCallback? onGiveUp;

  // 重连状态
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5; // 增加到5次
  
  // Web平台兼容性
  final bool _isWebPlatform = kIsWeb;
  bool _webIceRestartSupported = true; // 假设支持，失败后标记为false
  
  // 定时器
  Timer? _reconnectTimer;
  Timer? _connectionCheckTimer;
  
  // ICE状态监控
  RTCIceConnectionState? _lastStableState;
  DateTime? _lastConnectedTime;
  DateTime? _disconnectedSince;
  
  // 重连策略参数 - 优化为更快速的重连
  static const List<int> _reconnectDelays = [1, 2, 3, 5, 8]; // 快速重试：1s, 2s, 3s, 5s, 8s
  static const Duration _connectionTimeout = Duration(seconds: 8); // 减少到8秒
  static const Duration _maxDisconnectedTime = Duration(minutes: 3); // 延长到3分钟
  static const Duration _iceGatheringTimeout = Duration(seconds: 10); // ICE收集超时

  IceReconnectManager({
    required this.peerConnection,
    this.onReconnectStart,
    this.onReconnectSuccess,
    this.onReconnectFailed,
    this.onGiveUp,
  });

  /// 处理ICE连接状态变化
  void handleIceConnectionStateChange(RTCIceConnectionState state) {
    final now = DateTime.now();
    
    print('🛰️ ICE状态变化: $state (重连次数: $_reconnectAttempts)');
    
    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        _onConnectionEstablished(now);
        break;
        
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        _onConnectionDisconnected(now);
        break;
        
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        _onConnectionFailed(now);
        break;
        
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
        _startConnectionMonitoring();
        break;
        
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        _cleanup();
        break;
        
      default:
        break;
    }
  }

  /// 连接建立成功
  void _onConnectionEstablished(DateTime now) {
    print('✅ ICE连接已建立');
    _lastStableState = RTCIceConnectionState.RTCIceConnectionStateConnected;
    _lastConnectedTime = now;
    _disconnectedSince = null;
    
    // 重置重连状态（只在确实处于重连状态时触发回调）
    if (_isReconnecting) {
      print('🔄 状态变化处理器触发重连成功回调');
      _isReconnecting = false;
      _reconnectAttempts = 0;
      onReconnectSuccess?.call();
      print('🎉 ICE重连成功');
    }
    
    _stopAllTimers();
  }

  /// 连接断开
  void _onConnectionDisconnected(DateTime now) {
    if (_disconnectedSince == null) {
      _disconnectedSince = now;
      print('⚠️ ICE连接断开，开始监控重连时机');
    }
    
    // 如果断开时间超过阈值，启动重连
    if (!_isReconnecting && _shouldStartReconnect(now)) {
      _startReconnect();
    }
  }

  /// 连接失败
  void _onConnectionFailed(DateTime now) {
    print('❌ ICE连接失败');
    if (!_isReconnecting) {
      _startReconnect();
    }
  }

  /// 是否应该开始重连
  bool _shouldStartReconnect(DateTime now) {
    // 检查是否超过最大重连次数
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      return false;
    }
    
    // 检查断开时间是否超过阈值
    if (_disconnectedSince != null) {
      final disconnectedDuration = now.difference(_disconnectedSince!);
      if (disconnectedDuration > _maxDisconnectedTime) {
        print('⏰ 断开时间过长，放弃重连');
        onGiveUp?.call();
        return false;
      }
    }
    
    return true;
  }

  /// 开始重连
  void _startReconnect() {
    if (_isReconnecting || _reconnectAttempts >= _maxReconnectAttempts) {
      return;
    }
    
    _isReconnecting = true;
    _reconnectAttempts++;
    
    final delay = _reconnectDelays[(_reconnectAttempts - 1).clamp(0, _reconnectDelays.length - 1)];
    
    print('🔄 开始ICE重连 (第$_reconnectAttempts次，$delay秒后执行)');
    onReconnectStart?.call();
    
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      _performReconnect();
    });
  }

  /// 执行重连
  Future<void> _performReconnect() async {
    try {
      print('🔧 执行ICE重启... (第$_reconnectAttempts次, Web平台: $_isWebPlatform)');
      
      // Web平台兼容性检测
      if (_isWebPlatform && !_webIceRestartSupported) {
        print('⚠️ Web平台ICE重启不支持，跳过到硬重连');
        throw Exception('Web平台ICE重启不支持');
      }
      
      final startTime = DateTime.now();
      
      // 检查PeerConnection状态
      final currentState = peerConnection.iceConnectionState;
      print('🔍 当前ICE状态: $currentState');
      
      if (currentState == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        print('❌ PeerConnection已关闭，无法重连');
        throw Exception('PeerConnection已关闭');
      }
      
      // 执行ICE重启
      await peerConnection.restartIce();
      print('✅ ICE重启调用成功，开始监控...');
      
      // 开始更精细的连接监控
      _startEnhancedConnectionMonitoring(startTime);
      
    } catch (e) {
      print('❌ ICE重启失败: $e');
      
      // Web平台第一次失败，标记不支持并立即放弃ICE重启
      if (_isWebPlatform && _webIceRestartSupported) {
        print('⚠️ Web平台ICE重启可能不支持，标记为不可用');
        _webIceRestartSupported = false;
      }
      
      onReconnectFailed?.call('ICE重启失败: $e');
      
      // 根据平台和失败次数决定策略
      if (_shouldContinueReconnect()) {
        _isReconnecting = false;
        _startReconnect();
      } else {
        print('❌ 达到重连条件限制，放弃ICE重连');
        onGiveUp?.call();
      }
    }
  }
  
  /// 判断是否应该继续重连
  bool _shouldContinueReconnect() {
    // Web平台ICE重启不支持，尝试2次就放弃
    if (_isWebPlatform && !_webIceRestartSupported && _reconnectAttempts >= 2) {
      print('⚠️ Web平台ICE重启不支持，放弃继续重连');
      return false;
    }
    
    // 常规重连次数检查
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      return false;
    }
    
    return true;
  }

  /// 开始增强的连接监控
  void _startEnhancedConnectionMonitoring(DateTime startTime) {
    _stopConnectionMonitoring();
    
    // 更短的检查间隔，更精确的监控
    var checkCount = 0;
    const maxChecks = 16; // 8秒 / 0.5秒 = 16次检查
    
    _connectionCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      checkCount++;
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      
      if (!_isReconnecting) {
        timer.cancel();
        return;
      }
      
      // 检查当前ICE状态
      final currentState = peerConnection.iceConnectionState;
      print('🔍 ICE状态检查 ($checkCount/$maxChecks): $currentState (${elapsed}ms)');
      
      // 成功状态检查
      if (currentState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          currentState == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        print('✅ ICE重连成功！状态: $currentState');
        timer.cancel();
        
        // 🎯 关键修复：主动触发成功处理，不依赖状态变化事件
        if (_isReconnecting) {
          print('🔄 监控器主动触发重连成功回调');
          _isReconnecting = false;
          _reconnectAttempts = 0;
          _lastStableState = currentState;
          _lastConnectedTime = DateTime.now();
          _disconnectedSince = null;
          onReconnectSuccess?.call();
          print('🎉 ICE重连成功');
        }
        return;
      }
      
      // 快速失败检查
      if (currentState == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          currentState == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        print('❌ ICE状态显示失败: $currentState');
        timer.cancel();
        if (_isReconnecting) {
          _isReconnecting = false;
          _startReconnect();
        }
        return;
      }
      
      // 超时检查
      if (checkCount >= maxChecks) {
        print('⏰ ICE重连监控超时 (${elapsed}ms)，尝试下一次重连');
        timer.cancel();
        if (_isReconnecting) {
          _isReconnecting = false;
          _startReconnect();
        }
      }
    });
  }
  
  /// 开始连接监控（保留旧版本兼容性）
  void _startConnectionMonitoring() {
    _startEnhancedConnectionMonitoring(DateTime.now());
  }

  /// 停止连接监控
  void _stopConnectionMonitoring() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
  }

  /// 停止所有定时器
  void _stopAllTimers() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopConnectionMonitoring();
  }

  /// 手动触发重连
  Future<void> forceReconnect() async {
    if (_isReconnecting) {
      print('⚠️ 重连正在进行中，跳过手动重连请求');
      return;
    }
    
    print('🔄 手动触发ICE重连');
    _reconnectAttempts = 0; // 重置重连次数
    _startReconnect();
  }

  /// 重置重连状态
  void reset() {
    print('🔄 重置ICE重连管理器');
    _isReconnecting = false;
    _reconnectAttempts = 0;
    _disconnectedSince = null;
    _stopAllTimers();
  }

  /// 清理资源
  void _cleanup() {
    print('🧹 清理ICE重连管理器资源');
    _stopAllTimers();
    _isReconnecting = false;
  }

  /// 销毁管理器
  void dispose() {
    _cleanup();
  }

  /// 获取重连状态信息
  Map<String, dynamic> getStatus() {
    return {
      'isReconnecting': _isReconnecting,
      'reconnectAttempts': _reconnectAttempts,
      'maxAttempts': _maxReconnectAttempts,
      'disconnectedSince': _disconnectedSince?.toIso8601String(),
      'lastConnectedTime': _lastConnectedTime?.toIso8601String(),
    };
  }
} 