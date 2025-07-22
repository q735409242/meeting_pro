
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
class GestureChannel {
  static const String _kGestueChannel = 'com.meeting.pro.gestueChannel';

  static const MethodChannel gestueChannel = MethodChannel(_kGestueChannel);

  static void handleMessage(String msg) {
    // 👉 在这里打印，确保每次调用都会进到这个方法
    debugPrint('▶️ Flutter invoke handleMessage on $_kGestueChannel: $msg');
    if (Platform.isIOS) return;
    gestueChannel.invokeMethod('handleMessage',{'message':msg});
  }
  static void remoteControlEnable(bool enable) {
    if (Platform.isIOS) return;
    gestueChannel.invokeMethod('remoteControlEnable',{'status':enable});
  }

}