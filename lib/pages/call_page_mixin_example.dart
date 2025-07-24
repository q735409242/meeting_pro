// ignore_for_file: non_constant_identifier_names, avoid_print
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

// 导入我们的功能模块
import 'call_page_mixins/gesture_mixin.dart';
import 'call_page_mixins/audio_mixin.dart';

/// 使用mixin模块的简单示例
/// 展示如何在现有代码基础上逐步集成功能模块
class CallPageMixinExample extends StatefulWidget {
  final String roomId;
  final bool isCaller;
  final String? channel;

  const CallPageMixinExample({
    Key? key,
    required this.roomId,
    required this.isCaller,
    this.channel,
  }) : super(key: key);

  @override
  State<CallPageMixinExample> createState() => _CallPageMixinExampleState();
}

/// 示例：先集成手势处理模块
class _CallPageMixinExampleState extends State<CallPageMixinExample> 
    with WidgetsBindingObserver, GestureMixin {
  
  // 基本状态变量
  bool _remoteOn = false;
  late String _channel;
  dynamic _signaling; // 简化处理
  
  // 实现GestureMixin要求的抽象属性
  @override
  bool get isCaller => widget.isCaller;
  
  @override
  bool get remoteOn => _remoteOn;
  
  @override
  String? get channel => _channel;
  
  @override
  dynamic get signaling => _signaling;
  
  @override
  void initState() {
    super.initState();
    _channel = widget.channel ?? 'cf';
    
    // 初始化手势模块
    setupKeyboardListener();
    
    print('📱 CallPage示例初始化完成');
  }
  
  /// 实现触摸事件发送（GestureMixin要求）
  @override
  void onTouch(Offset globalPos, String type) {
    if (!widget.isCaller || !_remoteOn) return;
    
    // 计算相对坐标
    final relativeX = globalPos.dx;
    final relativeY = globalPos.dy;
    
    // 模拟发送触摸命令
    print('📤 模拟发送$type: (${relativeX.toInt()}, ${relativeY.toInt()})');
    
    // 在实际应用中，这里会调用 _signaling?.sendCommand({...})
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Mixin使用示例'),
        backgroundColor: Colors.blue,
      ),
      body: Focus(
        focusNode: keyboardFocusNode,
        onKeyEvent: (node, event) {
          if (!widget.isCaller || event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }
          
          // 处理键盘事件
          return _handleKeyEvent(event);
        },
        child: Stack(
          children: [
            // 主体内容
            Positioned.fill(
              child: GestureDetector(
                onPanStart: (details) {
                  print('🖱️ 手势开始: ${details.globalPosition}');
                  onPointerDown(details.globalPosition);
                },
                onPanUpdate: (details) {
                  onPointerMove(details.globalPosition);
                },
                onPanEnd: (details) {
                  onPointerUp(details.globalPosition);
                },
                onTap: () {
                  print('🖱️ 点击事件');
                },
                child: Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app,
                          size: 100,
                          color: Colors.white,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Mixin功能模块示例',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '✅ 手势处理模块已集成',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '支持：键盘输入、触摸手势、长按检测',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // 状态显示
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔧 已启用的功能模块：',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• GestureMixin - 手势处理 ✅',
                      style: TextStyle(color: Colors.green, fontSize: 14),
                    ),
                    const Text(
                      '• AudioMixin - 音频管理 ⏳ (待集成)',
                      style: TextStyle(color: Colors.orange, fontSize: 14),
                    ),
                    const Text(
                      '• ScreenShareMixin - 屏幕共享 ⏳ (待集成)',
                      style: TextStyle(color: Colors.orange, fontSize: 14),
                    ),
                    const Text(
                      '• WebRTCMixin - WebRTC连接 ⏳ (待集成)',
                      style: TextStyle(color: Colors.orange, fontSize: 14),
                    ),
                    const Text(
                      '• AccessibilityMixin - 无障碍服务 ⏳ (待集成)',
                      style: TextStyle(color: Colors.orange, fontSize: 14),
                    ),
                    const Text(
                      '• IceReconnectMixin - ICE重连 ⏳ (待集成)',
                      style: TextStyle(color: Colors.orange, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            
            // 操作提示
            Positioned(
              bottom: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Text(
                      '🎯 测试说明',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• 在屏幕上拖拽测试手势检测\n'
                      '• 输入键盘字符测试键盘监听\n'
                      '• 长按测试长按检测功能\n'
                      '• Ctrl+V测试黏贴功能',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 处理键盘事件
  KeyEventResult _handleKeyEvent(KeyDownEvent event) {
    // Ctrl/Cmd + V 黏贴
    final isCtrlV = (event.logicalKey == LogicalKeyboardKey.keyV) &&
        (HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed);
    
    if (isCtrlV) {
      print('🎹 检测到黏贴操作');
      handlePasteOperation();
      return KeyEventResult.handled;
    }
    
    // 退格键
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      print('🎹 检测到退格键');
      handleKeyboardInput('BACKSPACE');
      return KeyEventResult.handled;
    }
    
    // 回车键
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      print('🎹 检测到回车键');
      handleKeyboardInput('ENTER');
      return KeyEventResult.handled;
    }
    
    // 普通字符
    final character = event.character;
    if (character != null && character.isNotEmpty) {
      print('🎹 检测到字符输入: $character');
      handleKeyboardInput(character);
      return KeyEventResult.handled;
    }
    
    return KeyEventResult.ignored;
  }
  
  @override
  void dispose() {
    print('🧹 清理示例页面资源...');
    
    // 清理手势模块
    disposeGesture();
    
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// 使用多个mixin模块的高级示例
class CallPageMultiMixinExample extends StatefulWidget {
  final String roomId;
  final bool isCaller;
  final String? channel;

  const CallPageMultiMixinExample({
    Key? key,
    required this.roomId,
    required this.isCaller,
    this.channel,
  }) : super(key: key);

  @override
  State<CallPageMultiMixinExample> createState() => _CallPageMultiMixinExampleState();
}

/// 示例：集成手势处理 + 音频管理模块
class _CallPageMultiMixinExampleState extends State<CallPageMultiMixinExample> 
    with WidgetsBindingObserver, GestureMixin, AudioMixin {
  
  // 基本状态变量
  bool _remoteOn = false;
  late String _channel;
  dynamic _signaling;
  MediaStream? _localStream;
  bool _contributorSpeakerphoneOn = true;
  
  // 实现GestureMixin要求的抽象属性
  @override
  bool get isCaller => widget.isCaller;
  
  @override
  bool get remoteOn => _remoteOn;
  
  @override
  String? get channel => _channel;
  
  @override
  dynamic get signaling => _signaling;
  
  // 实现AudioMixin要求的抽象属性
  @override
  MediaStream? get localStream => _localStream;
  
  @override
  bool get contributorSpeakerphoneOn => _contributorSpeakerphoneOn;
  
  @override
  set contributorSpeakerphoneOn(bool value) {
    _contributorSpeakerphoneOn = value;
  }
  
  @override
  void initState() {
    super.initState();
    _channel = widget.channel ?? 'cf';
    
    // 初始化模块
    _initializeModules();
    
    print('📱 多模块示例初始化完成');
  }
  
  void _initializeModules() async {
    // 初始化手势模块
    setupKeyboardListener();
    
    // 初始化音频模块
    await prepareAudioSession();
    await registerRouteListener();
  }
  
  /// 实现触摸事件发送（GestureMixin要求）
  @override
  void onTouch(Offset globalPos, String type) {
    if (!widget.isCaller || !_remoteOn) return;
    
    print('📤 多模块发送$type: (${globalPos.dx.toInt()}, ${globalPos.dy.toInt()})');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('多模块集成示例'),
        backgroundColor: Colors.green,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 100,
              color: Colors.green,
            ),
            SizedBox(height: 20),
            Text(
              '多模块集成成功！',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '✅ 手势处理模块\n✅ 音频管理模块',
              style: TextStyle(
                color: Colors.green,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    print('🧹 清理多模块示例资源...');
    
    // 清理各个模块
    disposeGesture();
    disposeAudio();
    
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
} 