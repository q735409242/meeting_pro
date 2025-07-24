import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '../../method_channels/screen_stream_channel.dart' as screen;

/// 屏幕共享模块 - 负责屏幕共享控制和状态管理等功能
mixin ScreenShareMixin<T extends StatefulWidget> on State<T> {
  // 需要子类实现的抽象属性
  bool get isCaller;
  String? get channel;
  dynamic get signaling;
  RTCPeerConnection? get pc;
  MediaStream? get screenStream;
  set screenStream(MediaStream? value);
  RTCRtpSender? get screenSender;
  set screenSender(RTCRtpSender? value);
  bool get screenShareOn;
  set screenShareOn(bool value);
  
  /// 切换屏幕共享
  Future<void> toggleScreenShare() async {
    if (channel == 'sdk') {
      // SDK模式暂时注释
    } else if (channel == 'cf') {
      if (screenShareOn) {
        await stopScreenShare();
      } else {
        await startScreenShareSafely();
      }
    }
  }
  
  /// 安全启动屏幕共享
  Future<void> startScreenShareSafely() async {
    try {
      print('🖥️ 开始启动屏幕共享...');
      
      if (kIsWeb) {
        await startScreenShareForWeb();
      } else if (Platform.isAndroid) {
        await startScreenShareForAndroid();
      } else if (Platform.isIOS) {
        await startScreenShareForIOS();
      }
      
      if (screenStream != null) {
        setState(() {
          screenShareOn = true;
        });
        print('✅ 屏幕共享启动成功');
      }
    } catch (e) {
      print('❌ 屏幕共享启动失败: $e');
      await EasyLoading.showError('屏幕共享启动失败: $e');
    }
  }
  
  /// Web端屏幕共享
  Future<void> startScreenShareForWeb() async {
    try {
      print('🌐 Web端屏幕共享启动');
      
      screenStream = await navigator.mediaDevices.getDisplayMedia({
        'video': {'frameRate': 30},
        'audio': true,
      });
      
      if (screenStream != null && pc != null) {
        final videoTrack = screenStream!.getVideoTracks().first;
        screenSender = await pc!.addTrack(videoTrack, screenStream!);
        
        // 监听屏幕共享结束事件
        videoTrack.onEnded = () {
          print('🖥️ 用户停止了屏幕共享');
          stopScreenShare();
        };
      }
    } catch (e) {
      throw Exception('Web端屏幕共享失败: $e');
    }
  }
  
  /// Android端屏幕共享
  Future<void> startScreenShareForAndroid() async {
    try {
      print('🤖 Android端屏幕共享启动');
      
      // Android端使用getUserMedia获取屏幕流
      screenStream = await navigator.mediaDevices.getUserMedia({
        'video': {
          'mandatory': {
            'chromeMediaSource': 'screen',
          }
        }
      });
      
      if (screenStream != null && pc != null) {
        final videoTrack = screenStream!.getVideoTracks().first;
        screenSender = await pc!.addTrack(videoTrack, screenStream!);
      }
    } catch (e) {
      throw Exception('Android端屏幕共享失败: $e');
    }
  }
  
  /// iOS端屏幕共享
  Future<void> startScreenShareForIOS() async {
    try {
      print('🍎 iOS端屏幕共享启动');
      
      // iOS使用ReplayKit进行屏幕录制
      screenStream = await navigator.mediaDevices.getUserMedia({
        'video': {
          'deviceId': 'broadcast',
          'frameRate': 30,
        }
      });
      
      if (screenStream != null && pc != null) {
        final videoTrack = screenStream!.getVideoTracks().first;
        screenSender = await pc!.addTrack(videoTrack, screenStream!);
      }
    } catch (e) {
      throw Exception('iOS端屏幕共享失败: $e');
    }
  }
  
  /// 停止屏幕共享
  Future<void> stopScreenShare() async {
    try {
      print('🖥️ 停止屏幕共享...');
      
      // 停止屏幕流
      if (screenStream != null) {
        screenStream!.getTracks().forEach((track) {
          track.stop();
        });
        screenStream = null;
      }
      
      // 移除发送器
      if (screenSender != null && pc != null) {
        await pc!.removeTrack(screenSender!);
        screenSender = null;
      }
      
      // 停止平台特定的屏幕录制 - 暂时禁用
      // if (!kIsWeb && Platform.isAndroid) {
      //   await screen.ScreenStreamChannel.stopScreenCapture();
      // }
      
      setState(() {
        screenShareOn = false;
      });
      
      print('✅ 屏幕共享已停止');
    } catch (e) {
      print('❌ 停止屏幕共享失败: $e');
    }
  }
  
  /// 请求屏幕共享
  void onRequestScreenShare() {
    if (channel == 'sdk') {
      // SDK模式暂时注释
    } else if (channel == 'cf') {
      print('📺 发送屏幕共享请求');
      signaling?.sendCommand({'type': 'request_screen_share'});
    }
  }
  
  /// 停止对方屏幕共享
  void onStopScreenShare() async {
    final result = await showOkCancelAlertDialog(
      context: context,
      title: '温馨提示',
      message: '确认要停止对方的屏幕共享？',
      okLabel: '确认',
      cancelLabel: '取消',
    );
    
    if (result == OkCancelResult.ok) {
      if (channel == 'sdk') {
        // SDK模式暂时注释
      } else if (channel == 'cf') {
        print('📺 发送停止屏幕共享请求');
        signaling?.sendCommand({'type': 'stop_screen_share'});
      }
      
      await EasyLoading.showToast(
        '已发送停止屏幕共享请求',
        duration: const Duration(seconds: 2)
      );
    }
  }
  
  /// 恢复屏幕共享（用于ICE重连后）
  Future<void> restoreScreenShareAfterIceReconnect() async {
    if (!screenShareOn) return;
    
    try {
      print('🔄 ICE重连后恢复屏幕共享...');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (isCaller) {
        await restoreScreenShareForCaller();
      } else {
        await restoreScreenShareForJoiner();
      }
      
      print('✅ 屏幕共享恢复成功');
    } catch (e) {
      print('❌ 屏幕共享恢复失败: $e');
      setState(() {
        screenShareOn = false;
      });
    }
  }
  
  /// 主叫方恢复屏幕共享
  Future<void> restoreScreenShareForCaller() async {
    if (screenStream == null) {
      print('⚠️ 屏幕流不存在，重新启动屏幕共享');
      await startScreenShareSafely();
      return;
    }
    
    try {
      final videoTrack = screenStream!.getVideoTracks().first;
      if (pc != null) {
        screenSender = await pc!.addTrack(videoTrack, screenStream!);
        print('✅ 主叫方屏幕共享轨道已重新添加');
      }
    } catch (e) {
      print('❌ 主叫方屏幕共享恢复失败: $e');
      await fallbackToReauthorize();
    }
  }
  
  /// 被叫方恢复屏幕共享
  Future<void> restoreScreenShareForJoiner() async {
    try {
      print('🔄 被叫方静默恢复屏幕共享流...');
      await restoreScreenShareStreamSilently();
    } catch (e) {
      print('❌ 被叫方屏幕共享恢复失败: $e');
      await fallbackToReauthorize();
    }
  }
  
  /// 静默恢复屏幕共享流
  Future<void> restoreScreenShareStreamSilently() async {
    try {
      MediaStream? newScreenStream;
      
      if (kIsWeb) {
        newScreenStream = await navigator.mediaDevices.getDisplayMedia({
          'video': {'frameRate': 30},
          'audio': false,
        });
             } else if (Platform.isAndroid) {
         newScreenStream = await navigator.mediaDevices.getUserMedia({
           'video': {
             'mandatory': {
               'chromeMediaSource': 'screen',
             }
           }
         });
      } else if (Platform.isIOS) {
        newScreenStream = await navigator.mediaDevices.getUserMedia({
          'video': {
            'deviceId': 'broadcast',
            'frameRate': 30,
          }
        });
      }
      
      if (newScreenStream != null && pc != null) {
        // 停止旧流
        screenStream?.getTracks().forEach((t) => t.stop());
        
        // 设置新流
        screenStream = newScreenStream;
        final videoTrack = screenStream!.getVideoTracks().first;
        screenSender = await pc!.addTrack(videoTrack, screenStream!);
        
        // Web端监听结束事件
        if (kIsWeb) {
          videoTrack.onEnded = () {
            print('🖥️ 用户停止了屏幕共享');
            stopScreenShare();
          };
        }
        
        print('✅ 屏幕共享流已静默恢复');
      } else {
        throw Exception('无法获取屏幕共享流');
      }
    } catch (e) {
      throw Exception('静默恢复屏幕共享流失败: $e');
    }
  }
  
  /// 回退到重新授权
  Future<void> fallbackToReauthorize() async {
    print('🔄 回退到重新授权屏幕共享...');
    
    try {
      // 清理现有状态
      if (screenStream != null) {
        screenStream!.getTracks().forEach((t) => t.stop());
        screenStream = null;
      }
      
      if (screenSender != null && pc != null) {
        await pc!.removeTrack(screenSender!);
        screenSender = null;
      }
      
      setState(() {
        screenShareOn = false;
      });
      
      // 等待一段时间后重新启动
      await Future.delayed(const Duration(seconds: 1));
      await startScreenShareSafely();
      
    } catch (e) {
      print('❌ 重新授权屏幕共享失败: $e');
    }
  }
  
  /// 清理屏幕共享资源
  void disposeScreenShare() {
    if (screenStream != null) {
      screenStream!.getTracks().forEach((track) {
        track.stop();
      });
      screenStream = null;
    }
    
    // 暂时禁用Android特定的停止方法
    // if (!kIsWeb && Platform.isAndroid) {
    //   screen.ScreenStreamChannel.stopScreenCapture();
    // }
  }
} 