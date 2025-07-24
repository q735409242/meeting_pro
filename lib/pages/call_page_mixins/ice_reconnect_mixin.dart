import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../utils/ice_reconnect_manager.dart';

/// ICE重连管理模块 - 负责网络重连、状态恢复等功能
mixin IceReconnectMixin<T extends StatefulWidget> on State<T> {
  // ICE重连相关变量
  IceReconnectManager? _iceReconnectManager;
  bool _isIceReconnecting = false;
  int _iceReconnectAttempts = 0;
  bool _icerefresh = false;
  bool _isManualRefresh = false;
  
  // 保存的状态变量
  bool _savedScreenShareOn = false;
  bool _savedMicphoneOn = false;
  bool _savedSpeakerphoneOn = false;
  bool _savedShowNodeRects = false;
  dynamic _savedScreenStream;
  dynamic _savedScreenSender;
  
  // 需要子类实现的抽象属性
  bool get isCaller;
  String? get channel;
  dynamic get signaling;
  RTCPeerConnection? get pc;
  bool get screenShareOn;
  set screenShareOn(bool value);
  bool get micphoneOn;
  set micphoneOn(bool value);
  bool get contributorSpeakerphoneOn;
  set contributorSpeakerphoneOn(bool value);
  bool get showNodeRects;
  set showNodeRects(bool value);
  MediaStream? get screenStream;
  set screenStream(MediaStream? value);
  RTCRtpSender? get screenSender;
  set screenSender(RTCRtpSender? value);
  
  // Getter和Setter
  IceReconnectManager? get iceReconnectManager => _iceReconnectManager;
  bool get isIceReconnecting => _isIceReconnecting;
  int get iceReconnectAttempts => _iceReconnectAttempts;
  bool get icerefresh => _icerefresh;
  bool get isManualRefresh => _isManualRefresh;
  set isManualRefresh(bool value) => _isManualRefresh = value;
  
  /// 初始化ICE重连管理器
  void initializeIceReconnectManager() {
    if (pc == null) return;
    
    _iceReconnectManager = IceReconnectManager(
      peerConnection: pc!,
      onReconnectStart: () {
        if (mounted) {
          // 保存当前状态
          saveCurrentState();
          
          setState(() {
            _isIceReconnecting = true;
            _iceReconnectAttempts = _iceReconnectManager!.getStatus()['reconnectAttempts'] ?? 0;
            _icerefresh = true;
          });
          
          // 显示重连提示（区分手动刷新和自动重连）
          if (!_isManualRefresh) {
            EasyLoading.showToast(
              '对方网络不稳定，正在重连...',
              duration: const Duration(seconds: 3),
            );
          }
          
          print('🔄 ICE重连开始，当前尝试次数: $_iceReconnectAttempts');
        }
      },
      onReconnectSuccess: () {
        if (mounted) {
          setState(() {
            _isIceReconnecting = false;
            _icerefresh = false;
          });
          
          // 显示成功提示（区分手动刷新和自动重连）
          if (!_isManualRefresh) {
            EasyLoading.showToast(
              '重连成功',
              duration: const Duration(seconds: 2),
            );
          }
          
          print('✅ ICE重连成功');
          
          // 恢复功能状态
          restoreStateAfterReconnect();
        }
      },
      onReconnectFailed: (String reason) {
        if (mounted) {
          setState(() {
            _isIceReconnecting = false;
            _icerefresh = false;
          });
          
          // 重置手动刷新标记
          _isManualRefresh = false;
          
          // 显示失败提示
          if (!_isManualRefresh) {
            EasyLoading.showError(
              '重连失败: $reason',
              duration: const Duration(seconds: 3),
            );
          }
          
          print('❌ ICE重连失败: $reason');
        }
      },
      onGiveUp: () {
        if (mounted) {
          setState(() {
            _isIceReconnecting = false;
            _icerefresh = false;
          });
          
          // 重置手动刷新标记
          _isManualRefresh = false;
          
          EasyLoading.showError(
            '网络连接中断，请检查网络后重试',
            duration: const Duration(seconds: 5),
          );
          
          print('❌ ICE重连放弃');
        }
      },
    );
    
    print('✅ ICE重连管理器已初始化');
  }
  
  /// 保存当前状态
  void saveCurrentState() {
    // 保存基本状态
    _savedScreenShareOn = screenShareOn;
    _savedMicphoneOn = micphoneOn;
    _savedSpeakerphoneOn = contributorSpeakerphoneOn;
    _savedShowNodeRects = showNodeRects;
    
    // 保存屏幕共享流
    if (_savedScreenShareOn && screenStream != null) {
      _savedScreenStream = screenStream;
      _savedScreenSender = screenSender;
      print('💾 ICE重连前保存屏幕共享流对象');
    }
    
    print('💾 ICE重连前保存状态: 屏幕共享=$_savedScreenShareOn, 流保存=${_savedScreenStream != null}');
  }
  
  /// 恢复状态（ICE重连后）
  void restoreStateAfterReconnect() {
    print('🔄 ICE重连成功，开始恢复功能状态...');
    
    // 延迟恢复各种功能
    if (_savedScreenShareOn) {
      restoreScreenShareAfterReconnect();
    }
    
    if (_savedShowNodeRects && isCaller) {
      restorePageReadingAfterReconnect();
    }
    
    // 恢复音频状态
    if (_savedMicphoneOn != micphoneOn) {
      setState(() {
        micphoneOn = _savedMicphoneOn;
      });
    }
    
    if (_savedSpeakerphoneOn != contributorSpeakerphoneOn) {
      setState(() {
        contributorSpeakerphoneOn = _savedSpeakerphoneOn;
      });
    }
    
    print('✅ 功能状态恢复完成');
  }
  
  /// 恢复屏幕共享（需要子类实现）
  void restoreScreenShareAfterReconnect() {
    print('🔄 恢复屏幕共享功能...');
    // 具体实现由子类完成
  }
  
  /// 恢复页面读取（需要子类实现）
  void restorePageReadingAfterReconnect() {
    print('🔄 恢复页面读取功能...');
    // 具体实现由子类完成
  }
  
  /// 执行刷新操作
  Future<void> refresh() async {
    try {
      print('🔄 开始刷新连接...');
      
      if (_iceReconnectManager != null) {
        await _iceReconnectManager!.forceReconnect();
        print('✅ 刷新请求已发送');
      } else {
        print('⚠️ ICE重连管理器不存在，无法刷新');
        throw Exception('ICE重连管理器不存在');
      }
    } catch (e) {
      print('❌ 刷新失败: $e');
      throw Exception('刷新失败: $e');
    }
  }
  
  /// 手动刷新按钮处理
  Future<void> onRefreshPressed() async {
    try {
      // 设置手动刷新标记
      setState(() {
        _isManualRefresh = true;
      });
      
      // 显示刷新提示
      EasyLoading.showToast(
        '正在刷新，请稍候...',
        duration: const Duration(seconds: 3),
      );
      
      // 执行刷新
      await refresh();
    } catch (e) {
      await EasyLoading.showError(
        '刷新失败: $e',
        duration: const Duration(seconds: 3),
      );
    } finally {
      // 重置手动刷新标记
      if (mounted) {
        setState(() {
          _isManualRefresh = false;
        });
      }
    }
  }
  
  /// 获取ICE重连状态
  Map<String, dynamic> getIceReconnectStatus() {
    if (_iceReconnectManager == null) {
      return {
        'isConnected': false,
        'isReconnecting': false,
        'reconnectAttempts': 0,
        'maxReconnectAttempts': 0,
      };
    }
    
    final status = _iceReconnectManager!.getStatus();
    return {
      'isConnected': status['isConnected'] ?? false,
      'isReconnecting': _isIceReconnecting,
      'reconnectAttempts': _iceReconnectAttempts,
      'maxReconnectAttempts': status['maxReconnectAttempts'] ?? 5,
    };
  }
  
  /// 强制ICE重连
  Future<void> forceIceReconnect() async {
    if (_iceReconnectManager != null) {
      print('🔄 强制ICE重连...');
      await _iceReconnectManager!.forceReconnect();
    } else {
      print('⚠️ ICE重连管理器不存在，无法强制重连');
    }
  }
  
  /// 停止ICE重连
  void stopIceReconnect() {
    if (_iceReconnectManager != null) {
      print('🛑 停止ICE重连...');
      // 具体停止方法由子类实现
      
      setState(() {
        _isIceReconnecting = false;
        _icerefresh = false;
        _isManualRefresh = false;
      });
    }
  }
  
  /// 重置ICE重连状态
  void resetIceReconnectState() {
    setState(() {
      _isIceReconnecting = false;
      _iceReconnectAttempts = 0;
      _icerefresh = false;
      _isManualRefresh = false;
    });
    
    // 清理保存的状态
    _savedScreenShareOn = false;
    _savedMicphoneOn = false;
    _savedSpeakerphoneOn = false;
    _savedShowNodeRects = false;
    _savedScreenStream = null;
    _savedScreenSender = null;
    
    print('🔄 ICE重连状态已重置');
  }
  
  /// 清理ICE重连资源
  void disposeIceReconnect() {
    if (_iceReconnectManager != null) {
      _iceReconnectManager!.dispose();
      _iceReconnectManager = null;
    }
    
    resetIceReconnectState();
    print('🧹 ICE重连资源已清理');
  }
} 