import 'package:flutter/material.dart';

/// 浮动按钮组组件 - 可拖拽的远控按钮组
class FloatingButtonGroupWidget extends StatelessWidget {
  final Offset position;
  final Function(Offset) onPositionChanged;
  final VoidCallback onBackTapped;
  final VoidCallback onHomeTapped;
  final VoidCallback onRecentTapped;
  final VoidCallback onBlackScreenToggle;
  final VoidCallback onNodeTreeToggle;
  final bool showBlack;
  final bool showNodeRects;
  final String channel;

  const FloatingButtonGroupWidget({
    Key? key,
    required this.position,
    required this.onPositionChanged,
    required this.onBackTapped,
    required this.onHomeTapped,
    required this.onRecentTapped,
    required this.onBlackScreenToggle,
    required this.onNodeTreeToggle,
    required this.showBlack,
    required this.showNodeRects,
    required this.channel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          onPositionChanged(position + details.delta);
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
              // 返回按钮
              GestureDetector(
                onTap: onBackTapped,
                child: const Icon(Icons.arrow_back,
                    size: 32, color: Colors.white),
              ),
              const SizedBox(width: 12),
              
              // 主页按钮
              GestureDetector(
                onTap: onHomeTapped,
                child: const Icon(Icons.home, size: 32, color: Colors.white),
              ),
              const SizedBox(width: 12),
              
              // 最近任务按钮
              GestureDetector(
                onTap: onRecentTapped,
                child: const Icon(Icons.dashboard,
                    size: 32, color: Colors.white),
              ),
              const SizedBox(width: 12),
              
              // 黑屏切换按钮
              GestureDetector(
                onTap: onBlackScreenToggle,
                child: Icon(
                    showBlack
                        ? Icons.visibility_off
                        : Icons.visibility,
                    size: 32,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              
              // 节点树切换按钮
              GestureDetector(
                onTap: onNodeTreeToggle,
                child: Icon(showNodeRects ? Icons.code : Icons.code_off,
                    size: 32, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 