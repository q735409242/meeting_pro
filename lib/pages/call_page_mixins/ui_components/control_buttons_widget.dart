import 'package:flutter/material.dart';

/// 控制按钮组件 - 底部控制栏的所有按钮
class ControlButtonsWidget extends StatelessWidget {
  final bool micphoneOn;
  final bool screenShareOn;
  final bool contributorSpeakerphoneOn;
  final bool interceptOn;
  final bool remoteOn;
  final bool canRefresh;
  final bool canShareScreen;
  final VoidCallback onMicphoneToggle;
  final VoidCallback onScreenShareToggle;
  final VoidCallback onSpeakerphoneToggle;
  final VoidCallback onInterceptToggle;
  final VoidCallback onRemoteToggle;
  final VoidCallback onRefresh;
  final VoidCallback onDisconnect;

  const ControlButtonsWidget({
    Key? key,
    required this.micphoneOn,
    required this.screenShareOn,
    required this.contributorSpeakerphoneOn,
    required this.interceptOn,
    required this.remoteOn,
    required this.canRefresh,
    required this.canShareScreen,
    required this.onMicphoneToggle,
    required this.onScreenShareToggle,
    required this.onSpeakerphoneToggle,
    required this.onInterceptToggle,
    required this.onRemoteToggle,
    required this.onRefresh,
    required this.onDisconnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100.0, // _kControlBarHeight
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Wrap(
          alignment: WrapAlignment.center,
          children: [
            IconButton(
              disabledColor: Colors.grey,
              onPressed: onMicphoneToggle,
              icon: Icon(micphoneOn ? Icons.mic : Icons.mic_off),
              tooltip: '开关自己的麦克风',
            ),
            IconButton(
              onPressed: canShareScreen ? onScreenShareToggle : null,
              icon: Icon(
                  screenShareOn ? Icons.phone_android : Icons.phonelink_erase),
              tooltip: '开关对方屏幕',
            ),
            IconButton(
              disabledColor: Colors.grey,
              onPressed: onSpeakerphoneToggle,
              icon: Icon(contributorSpeakerphoneOn
                  ? Icons.headset_mic
                  : Icons.headset_off),
              tooltip: '开关对方麦克风',
            ),
            IconButton(
              onPressed: onInterceptToggle,
              icon: Icon(interceptOn ? Icons.phone_disabled : Icons.phone_enabled),
              tooltip: '开关拦截对方电话',
            ),
            IconButton(
              onPressed: onRemoteToggle,
              icon: Icon(remoteOn ? Icons.cloud : Icons.cloud_off_rounded),
              tooltip: '开关远程控制',
            ),
            IconButton(
              onPressed: canRefresh ? onRefresh : null,
              icon: const Icon(Icons.refresh),
              tooltip: '刷新',
              disabledColor: Colors.grey,
            ),
            IconButton(
              onPressed: onDisconnect,
              icon: const Icon(Icons.close_sharp),
              tooltip: '退出房间',
            ),
          ],
        ),
      ),
    );
  }
} 