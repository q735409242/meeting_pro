import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 键盘监听器组件 - Web端键盘事件监听层
class KeyboardListenerWidget extends StatelessWidget {
  final FocusNode? keyboardFocusNode;
  final bool remoteOn;
  final Function(String) onKeyboardInput;
  final VoidCallback onPasteOperation;
  final Widget child;

  const KeyboardListenerWidget({
    Key? key,
    required this.keyboardFocusNode,
    required this.remoteOn,
    required this.onKeyboardInput,
    required this.onPasteOperation,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 只在Web平台且有焦点节点时显示
    if (!kIsWeb || keyboardFocusNode == null) {
      return child;
    }

    return Focus(
      focusNode: keyboardFocusNode!,
      autofocus: true,
      onKeyEvent: (node, event) {
        // 只处理按键按下事件，且在远控开启时
        if (!event.runtimeType.toString().contains('KeyDownEvent') || !remoteOn) {
          return KeyEventResult.ignored;
        }

        print('🎹 检测到按键事件: ${event.logicalKey}');
        print('🎹 按键详细信息: keyId=${event.logicalKey.keyId}, debugName=${event.logicalKey.debugName}');
        print('🎹 修饰键状态: ctrl=${event.logicalKey == LogicalKeyboardKey.controlLeft || event.logicalKey == LogicalKeyboardKey.controlRight}, meta=${event.logicalKey == LogicalKeyboardKey.metaLeft || event.logicalKey == LogicalKeyboardKey.metaRight}');

        // 检测黏贴操作 (Ctrl+V 或 Cmd+V)
        final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
        final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
        final isVKey = event.logicalKey == LogicalKeyboardKey.keyV;

        if ((isCtrlPressed || isMetaPressed) && isVKey) {
          print('🎹 检测到黏贴操作 (${isCtrlPressed ? 'Ctrl' : 'Cmd'}+V)');
          onPasteOperation();
          return KeyEventResult.handled;
        }

        // 使用多种方法检测特殊按键
        final key = event.logicalKey;
        final keyId = key.keyId;

        // 方法1：使用预定义常量比较
        if (key == LogicalKeyboardKey.backspace) {
          print('🎹 检测到删除键 (方法1: 常量比较)');
          onKeyboardInput('BACKSPACE');
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.enter) {
          print('🎹 检测到回车键 (方法1: 常量比较)');
          onKeyboardInput('ENTER');
          return KeyEventResult.handled;
        }
        // 方法2：使用keyId数值检测
        else if (keyId == 4294967304 || keyId == 8) {
          // Backspace的可能keyId值
          print('🎹 检测到删除键 (方法2: keyId=$keyId)');
          onKeyboardInput('BACKSPACE');
          return KeyEventResult.handled;
        } else if (keyId == 4294967309 || keyId == 13) {
          // Enter的可能keyId值
          print('🎹 检测到回车键 (方法2: keyId=$keyId)');
          onKeyboardInput('ENTER');
          return KeyEventResult.handled;
        }
        // 方法3：检查字符和控制键
        else if (event.character == '\b' || (event.character == null && keyId == 8)) {
          print('🎹 检测到删除键 (方法3: 字符检测)');
          onKeyboardInput('BACKSPACE');
          return KeyEventResult.handled;
        } else if (event.character == '\n' || event.character == '\r' || (event.character == null && keyId == 13)) {
          print('🎹 检测到回车键 (方法3: 字符检测)');
          onKeyboardInput('ENTER');
          return KeyEventResult.handled;
        } else {
          // 处理普通字符（排除修饰键）
          final character = event.character;
          if (character != null && 
              character.isNotEmpty && 
              character != '\b' && 
              character != '\n' && 
              character != '\r' &&
              !isCtrlPressed && 
              !isMetaPressed) {
            // 排除修饰键组合
            print('🎹 检测到普通字符: "$character"');
            onKeyboardInput(character);
            return KeyEventResult.handled;
          } else {
            print('🎹 未处理的按键: keyId=0x${keyId.toRadixString(16)}, character=${event.character}');
          }
        }

        return KeyEventResult.ignored;
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
        child: child,
      ),
    );
  }
} 