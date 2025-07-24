import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../method_channels/gestue_channel.dart';

/// 手势处理模块 - 负责键盘输入、触摸手势、长按等功能
mixin GestureMixin<T extends StatefulWidget> on State<T> {
  // 手势处理相关变量
  Offset? _pointerDownPosition;
  int? _pointerDownTime;
  bool _isDragging = false;
  static const double _tapThreshold = 10.0;
  static const int _tapTimeThreshold = 500;
  
  // Web平台的点击阈值
  static double get _webTapThreshold => kIsWeb ? 3.0 : _tapThreshold;
  static int get _webTapTimeThreshold => kIsWeb ? 300 : _tapTimeThreshold;
  
  // 长按支持相关变量
  Timer? _longPressTimer;
  bool _isLongPressing = false;
  bool _longPressTriggered = false;
  static const int _longPressThreshold = 600;
  
  // 键盘监听相关
  FocusNode? _keyboardFocusNode;
  
  // 公开访问键盘焦点节点
  FocusNode? get keyboardFocusNode => _keyboardFocusNode;
  
  // 需要子类实现的抽象属性
  bool get isCaller;
  bool get remoteOn;
  String? get channel;
  dynamic get signaling;
  
  /// 设置键盘监听器
  void setupKeyboardListener() {
    if (kIsWeb && isCaller) {
      _keyboardFocusNode = FocusNode();
      _keyboardFocusNode!.requestFocus();
      print('🎹 Web端键盘监听器已设置');
    }
  }
  
  /// 处理键盘输入
  void handleKeyboardInput(String text) {
    if (!isCaller || !remoteOn) return;
    
    String displayText = text;
    if (text == 'BACKSPACE') {
      displayText = '退格键';
    } else if (text == 'ENTER') {
      displayText = '回车键';
    } else if (text.startsWith('PASTE:')) {
      displayText = '黏贴内容';
    }
    
    print('🎹 Web端键盘输入: "$displayText"');
    
    if (channel == 'cf') {
      signaling?.sendCommand({
        'type': 'key_input',
        'text': text,
      });
      print('🎹 已发送键盘输入命令: "$displayText"');
    }
  }
  
  /// 处理黏贴操作
  void handlePasteOperation() async {
    try {
      print('🎹 开始获取剪切板内容...');
      
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final pasteText = clipboardData?.text;
      
      if (pasteText != null && pasteText.isNotEmpty) {
        print('🎹 获取到剪切板内容: "${pasteText.length > 50 ? pasteText.substring(0, 50) + '...' : pasteText}"');
        handleKeyboardInput('PASTE:$pasteText');
      } else {
        print('🎹 剪切板为空或无文本内容');
      }
    } catch (e) {
      print('🎹 获取剪切板内容失败: $e');
    }
  }
  
  /// 处理pointer down事件
  void onPointerDown(Offset globalPos) {
    _pointerDownPosition = globalPos;
    _pointerDownTime = DateTime.now().millisecondsSinceEpoch;
    _isDragging = false;
    _longPressTriggered = false;
    
    if (!isCaller || !remoteOn) {
      return;
    }
    
    startLongPressTimer(globalPos);
    
    if (!kIsWeb) {
      onTouch(globalPos, 'swipStart');
    }
    
    print('🖱️ 按下: (${globalPos.dx.toInt()}, ${globalPos.dy.toInt()}) - 长按检测已启动');
  }
  
  /// 处理pointer move事件
  void onPointerMove(Offset globalPos) {
    if (!isCaller || !remoteOn || _pointerDownPosition == null) return;
    
    final distance = (globalPos - _pointerDownPosition!).distance;
    
    if (distance > _webTapThreshold) {
      cancelLongPressTimer();
      
      if (!_isDragging) {
        _isDragging = true;
        print('🖱️ 检测到拖拽开始，距离: ${distance.toStringAsFixed(1)}px - 长按检测已取消');
        onTouch(_pointerDownPosition!, 'swipStart');
      }
      
      onTouch(globalPos, 'swipMove');
    } else if (distance > 1.0) {
      print('🖱️ 微小移动，距离: ${distance.toStringAsFixed(1)}px (阈值: ${_webTapThreshold}px) - 长按检测继续');
    }
  }
  
  /// 处理pointer up事件
  void onPointerUp(Offset globalPos) {
    if (_pointerDownPosition == null) {
      return;
    }
    
    cancelLongPressTimer();
    
    if (!isCaller || !remoteOn) {
      clearPointerData();
      return;
    }
    
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final duration = currentTime - (_pointerDownTime ?? currentTime);
    final distance = (globalPos - _pointerDownPosition!).distance;
    
    if (_longPressTriggered) {
      print('🖱️ 长按结束: (${globalPos.dx.toInt()}, ${globalPos.dy.toInt()})');
      onTouch(globalPos, 'longPressEnd');
    } else if (_isDragging || distance > _webTapThreshold || duration > _webTapTimeThreshold) {
      print('🖱️ 滑动结束: (${globalPos.dx.toInt()}, ${globalPos.dy.toInt()}) 距离:${distance.toInt()}px');
      onTouch(globalPos, 'swipEnd');
    } else {
      print('🖱️ 点击: (${globalPos.dx.toInt()}, ${globalPos.dy.toInt()})');
      onTouch(globalPos, 'tap');
    }
    
    clearPointerData();
  }
  
  /// 清理指针数据
  void clearPointerData() {
    _pointerDownPosition = null;
    _pointerDownTime = null;
    _isDragging = false;
    _isLongPressing = false;
    _longPressTriggered = false;
    cancelLongPressTimer();
  }
  
  /// 启动长按检测定时器
  void startLongPressTimer(Offset position) {
    cancelLongPressTimer();
    
    _longPressTimer = Timer(Duration(milliseconds: _longPressThreshold), () {
      if (_pointerDownPosition != null && !_isDragging && !_longPressTriggered) {
        _longPressTriggered = true;
        _isLongPressing = true;
        print('🖱️ 长按触发: (${position.dx.toInt()}, ${position.dy.toInt()}) - ${_longPressThreshold}ms');
        onTouch(position, 'longPress');
      }
    });
  }
  
  /// 取消长按检测定时器
  void cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }
  
  /// 发送触摸事件（需要子类实现具体的坐标转换和发送逻辑）
  void onTouch(Offset globalPos, String type);
  
  /// 处理远程触摸事件
  void handleRemoteTouch(double rx, double ry, String type) {
    print('收到远端$type: $rx, $ry');
    print('📲 触发点击: $rx, $ry');
    GestureChannel.handleMessage(jsonEncode({
      'type': type,
      'x': rx,
      'y': ry,
    }));
  }
  
  /// 清理资源
  void disposeGesture() {
    _keyboardFocusNode?.dispose();
    cancelLongPressTimer();
  }
} 