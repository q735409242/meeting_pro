import 'package:flutter/material.dart';

/// 通话时长显示组件
class CallDurationWidget extends StatelessWidget {
  final Duration callDuration;
  final bool isCaller;

  const CallDurationWidget({
    Key? key,
    required this.callDuration,
    required this.isCaller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 只有被控端显示通话时长
    if (isCaller) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '通话时间：${_formatDuration(callDuration)}',
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black54,
        ),
      ),
    );
  }

  /// 格式化通话时长
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    String hours = twoDigits(duration.inHours);
    
    if (duration.inHours > 0) {
      return '$hours:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }
} 