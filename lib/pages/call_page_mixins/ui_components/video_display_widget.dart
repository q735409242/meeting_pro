import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';

/// 视频显示组件 - 处理视频流显示的复杂逻辑
class VideoDisplayWidget extends StatelessWidget {
  final String channel;
  final String? remoteUid;
  final bool isCaller;
  final double remoteScreenWidth;
  final double remoteScreenHeight;
  final RTCVideoRenderer remoteRenderer;
  final bool remoteHasVideo;
  final bool remoteHasAudio;
  final bool remoteOn;
  final bool showNodeRects;
  final List<AccessibilityNode> nodeRects;
  final double savedRemoteScreenWidth;
  final double savedRemoteScreenHeight;
  final GlobalKey videoKey;
  final Function(Offset) onPointerDown;
  final Function(Offset) onPointerMove;
  final Function(Offset) onPointerUp;
  final bool Function() hasAnyAudio;

  const VideoDisplayWidget({
    Key? key,
    required this.channel,
    required this.remoteUid,
    required this.isCaller,
    required this.remoteScreenWidth,
    required this.remoteScreenHeight,
    required this.remoteRenderer,
    required this.remoteHasVideo,
    required this.remoteHasAudio,
    required this.remoteOn,
    required this.showNodeRects,
    required this.nodeRects,
    required this.savedRemoteScreenWidth,
    required this.savedRemoteScreenHeight,
    required this.videoKey,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.hasAnyAudio,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (channel == "sdk") {
      return _buildSdkVideoDisplay();
    } else {
      return _buildWebRtcVideoDisplay();
    }
  }

  Widget _buildSdkVideoDisplay() {
    if (remoteUid == null) {
      return const Center(
        child: Text('等待对方加入...',
            style: TextStyle(color: Colors.black, fontSize: 24)),
      );
    }

    if (!isCaller || remoteScreenWidth == 0 || remoteScreenHeight == 0) {
      return const Center(
        child: Text('正在语音通话中..',
            style: TextStyle(color: Colors.black, fontSize: 24)),
      );
    }

    return Listener(
      key: videoKey,
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => onPointerDown(event.position),
      onPointerMove: (event) => onPointerMove(event.position),
      onPointerUp: (event) => onPointerUp(event.position),
      child: AspectRatio(
        aspectRatio: remoteScreenWidth / remoteScreenHeight,
      ),
    );
  }

  Widget _buildWebRtcVideoDisplay() {
    // 等待对方加入
    if (remoteRenderer.srcObject == null && !showNodeRects && !hasAnyAudio()) {
      return const Center(
        child: Text('等待对方加入..',
            style: TextStyle(color: Colors.black, fontSize: 24)),
      );
    }

    // 重连中
    if (remoteRenderer.srcObject == null && remoteHasVideo) {
      return const Center(
        child: Text('重连中...',
            style: TextStyle(color: Colors.black, fontSize: 24)),
      );
    }

    // 语音通话模式
    if (!remoteHasVideo) {
      return _buildAudioOnlyDisplay();
    }

    // 视频通话模式
    return _buildVideoDisplay();
  }

  Widget _buildAudioOnlyDisplay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // 背景层
            if (showNodeRects && nodeRects.isNotEmpty)
              Container(color: Colors.black)
            else
              const Center(
                child: Text('正在语音通话中..',
                    style: TextStyle(color: Colors.black, fontSize: 24)),
              ),
            
            // 远控点击层
            if (remoteOn && isCaller)
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) => onPointerDown(event.position),
                  onPointerMove: (event) => onPointerMove(event.position),
                  onPointerUp: (event) => onPointerUp(event.position),
                  child: Container(color: Colors.transparent),
                ),
              ),
            
            // 节点树显示层
            if (showNodeRects && nodeRects.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: CustomPaint(
                    painter: AccessibilityPainter(
                      nodeRects.where((node) {
                        final rect = node.bounds;
                        return rect.width >= 1 && 
                               rect.height >= 1 && 
                               !rect.isEmpty &&
                               rect.left.isFinite &&
                               rect.top.isFinite &&
                               rect.right.isFinite &&
                               rect.bottom.isFinite;
                      }).toList(),
                      remoteSize: Size(
                        savedRemoteScreenWidth > 0 ? savedRemoteScreenWidth : remoteScreenWidth,
                        savedRemoteScreenHeight > 0 ? savedRemoteScreenHeight : remoteScreenHeight,
                      ),
                      containerSize: Size(constraints.maxWidth, constraints.maxHeight),
                      fit: BoxFit.contain,
                      statusBarHeight: MediaQuery.of(context).padding.top,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildVideoDisplay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // 视频层
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) => onPointerDown(event.position),
              onPointerMove: (event) => onPointerMove(event.position),
              onPointerUp: (event) => onPointerUp(event.position),
              child: RTCVideoView(
                remoteRenderer,
                mirror: false,
                filterQuality: FilterQuality.none,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                key: videoKey,
              ),
            ),
            
            // 节点树显示层
            if (showNodeRects && nodeRects.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: CustomPaint(
                    painter: AccessibilityPainter(
                      nodeRects.where((node) {
                        final rect = node.bounds;
                        return rect.width >= 1 && 
                               rect.height >= 1 && 
                               !rect.isEmpty &&
                               rect.left.isFinite &&
                               rect.top.isFinite &&
                               rect.right.isFinite &&
                               rect.bottom.isFinite;
                      }).toList(),
                      remoteSize: Size(
                        savedRemoteScreenWidth > 0 ? savedRemoteScreenWidth : remoteScreenWidth,
                        savedRemoteScreenHeight > 0 ? savedRemoteScreenHeight : remoteScreenHeight,
                      ),
                      containerSize: Size(constraints.maxWidth, constraints.maxHeight),
                      fit: BoxFit.contain,
                      statusBarHeight: MediaQuery.of(context).padding.top,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 无障碍节点数据类
class AccessibilityNode {
  final Rect bounds;
  final String label;

  AccessibilityNode({required this.bounds, required this.label});
}

/// 无障碍节点绘制器
class AccessibilityPainter extends CustomPainter {
  final List<AccessibilityNode> nodes;
  final Size remoteSize;
  final Size containerSize;
  final BoxFit fit;
  final double statusBarHeight;

  AccessibilityPainter(
    this.nodes, {
    required this.remoteSize,
    required this.containerSize,
    required this.fit,
    required this.statusBarHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveRemoteSize = remoteSize;
    
    final FittedSizes fittedSizes = applyBoxFit(fit, effectiveRemoteSize, containerSize);
    final Size displaySize = fittedSizes.destination;
    final double scaleX = displaySize.width / effectiveRemoteSize.width;
    final double scaleY = displaySize.height / effectiveRemoteSize.height;
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

      // 只有非空标签才绘制文字
      if (node.label.isNotEmpty) {
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 