import 'package:flutter/material.dart';

// CallPage功能模块导出文件
export 'gesture_mixin.dart';
export 'audio_mixin.dart';
export 'screen_share_mixin.dart';
export 'webrtc_mixin.dart';
export 'accessibility_mixin.dart';
export 'ice_reconnect_mixin.dart';

/// 综合mixin - 包含所有CallPage功能模块
/// 
/// 使用方式：
/// ```dart
/// class _CallPageState extends State<CallPage> 
///     with WidgetsBindingObserver, 
///          GestureMixin, AudioMixin, ScreenShareMixin,
///          WebRTCMixin, AccessibilityMixin, IceReconnectMixin {
///   // 实现抽象属性和方法
/// }
/// ```
mixin CallPageMixin<T extends StatefulWidget> on State<T> {
  
  /// 初始化所有模块（需要子类具体实现各个模块的初始化）
  void initializeAllMixins() {
    print('📋 初始化所有CallPage功能模块...');
    // 具体的模块初始化将在子类中实现
  }
  
  /// 清理所有模块资源（需要子类具体实现各个模块的清理）
  void disposeAllMixins() {
    print('🧹 清理所有CallPage功能模块...');
    // 具体的模块清理将在子类中实现
  }
} 