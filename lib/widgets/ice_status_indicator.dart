import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// ICE连接状态指示器
class IceStatusIndicator extends StatefulWidget {
  final RTCIceConnectionState? iceState;
  final bool isReconnecting;
  final int reconnectAttempts;
  final VoidCallback? onTap;

  const IceStatusIndicator({
    Key? key,
    this.iceState,
    this.isReconnecting = false,
    this.reconnectAttempts = 0,
    this.onTap,
  }) : super(key: key);

  @override
  State<IceStatusIndicator> createState() => _IceStatusIndicatorState();
}

class _IceStatusIndicatorState extends State<IceStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    if (widget.isReconnecting) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(IceStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isReconnecting != oldWidget.isReconnecting) {
      if (widget.isReconnecting) {
        _animationController.repeat();
      } else {
        _animationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _getBorderColor(), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isReconnecting)
              SizedBox(
                width: 12,
                height: 12,
                child: RotationTransition(
                  turns: _animationController,
                  child: const Icon(
                    Icons.refresh,
                    size: 12,
                    color: Colors.orange,
                  ),
                ),
              )
            else
              Icon(
                _getStatusIcon(),
                size: 12,
                color: _getIconColor(),
              ),
            const SizedBox(width: 4),
            Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: 10,
                color: _getTextColor(),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (widget.isReconnecting) {
      return Colors.orange.withOpacity(0.1);
    }
    
    switch (widget.iceState) {
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        return Colors.green.withOpacity(0.1);
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        return Colors.red.withOpacity(0.1);
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        return Colors.orange.withOpacity(0.1);
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
        return Colors.blue.withOpacity(0.1);
      default:
        return Colors.grey.withOpacity(0.1);
    }
  }

  Color _getBorderColor() {
    if (widget.isReconnecting) {
      return Colors.orange.withOpacity(0.3);
    }
    
    switch (widget.iceState) {
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        return Colors.green.withOpacity(0.3);
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        return Colors.red.withOpacity(0.3);
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        return Colors.orange.withOpacity(0.3);
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
        return Colors.blue.withOpacity(0.3);
      default:
        return Colors.grey.withOpacity(0.3);
    }
  }

  IconData _getStatusIcon() {
    switch (widget.iceState) {
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        return Icons.wifi;
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        return Icons.wifi_off;
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        return Icons.signal_wifi_statusbar_connected_no_internet_4;
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
        return Icons.wifi_find;
      default:
        return Icons.help_outline;
    }
  }

  Color _getIconColor() {
    if (widget.isReconnecting) {
      return Colors.orange;
    }
    
    switch (widget.iceState) {
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        return Colors.green;
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        return Colors.red;
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        return Colors.orange;
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getTextColor() {
    return _getIconColor();
  }

  String _getStatusText() {
    if (widget.isReconnecting) {
      return '重连中${widget.reconnectAttempts > 0 ? "(${widget.reconnectAttempts})" : ""}';
    }
    
    switch (widget.iceState) {
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
        return '已连接';
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        return '连接完成';
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        return '连接失败';
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        return '连接断开';
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
        return '连接中';
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        return '已关闭';
      case RTCIceConnectionState.RTCIceConnectionStateNew:
        return '新建';
      default:
        return '未知';
    }
  }
} 