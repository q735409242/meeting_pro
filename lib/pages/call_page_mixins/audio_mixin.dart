import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

/// 音频管理模块 - 负责音频路由、麦克风、扬声器控制等功能
mixin AudioMixin<T extends StatefulWidget> on State<T> {
  // 需要子类实现的抽象属性
  bool get isCaller;
  MediaStream? get localStream;
  String? get channel;
  dynamic get signaling;
  bool get contributorSpeakerphoneOn;
  set contributorSpeakerphoneOn(bool value);
  
  /// 准备音频会话
  Future<void> prepareAudioSession() async {
    print('🎧 IOS准备切换到扬声器模式');

    if (!kIsWeb && Platform.isIOS) {
      // 2. 初始化并配置 AVAudioSession
      await Helper.ensureAudioSession();
      await Helper.setAppleAudioConfiguration(AppleAudioConfiguration(
        appleAudioCategory: AppleAudioCategory.playAndRecord,
        appleAudioMode: AppleAudioMode.voiceChat,
        appleAudioCategoryOptions: {
          AppleAudioCategoryOption.defaultToSpeaker,
          AppleAudioCategoryOption.allowBluetooth,
        },
      ));
      // 配置音频I/O模式为语音聊天，并优先使用扬声器
      await Helper.setAppleAudioIOMode(AppleAudioIOMode.localAndRemote,
          preferSpeakerOutput: true);
      print('✅ iOS AVAudioSession 已配置为 playAndRecord+默认扬声器');
    }
  }
  
  /// 注册音频路由监听器
  Future<void> registerRouteListener() async {
    try {
      if (kIsWeb) {
        print('🌐 Web平台音频路由监听');
        
        navigator.mediaDevices.ondevicechange = (event) async {
          print('🎧 音频设备变化事件');
          await handleAudioRoute();
        };
        
        await handleAudioRoute();
      } else {
        print('📱 移动平台 - 暂时不支持音频路由监听');
      }
    } catch (e) {
      print('❌ 注册音频路由监听器失败: $e');
    }
  }
  
  /// 处理音频路由变化
  Future<void> handleAudioRoute() async {
    try {
      if (!kIsWeb) return;
      
      print('🎧 检查音频设备状态...');
      final devices = await navigator.mediaDevices.enumerateDevices();
      
      bool hasHeadphones = false;
      for (final device in devices) {
        if (device.kind == 'audiooutput') {
          final label = device.label?.toLowerCase() ?? '';
          if (label.contains('headphone') || 
              label.contains('headset') || 
              label.contains('earphone') ||
              label.contains('airpods') ||
              label.contains('bluetooth')) {
            hasHeadphones = true;
            print('🎧 检测到耳机设备: ${device.label}');
            break;
          }
        }
      }
      
      if (hasHeadphones) {
        print('🎧 检测到耳机，关闭扬声器');
        await Helper.setSpeakerphoneOn(false);
      } else {
        print('🔊 未检测到耳机，开启扬声器');
        await Helper.setSpeakerphoneOn(true);
      }
    } catch (e) {
      print('❌ 处理音频路由失败: $e');
    }
  }
  
  /// 切换扬声器状态
  void toggleSpeakerphone() {
    if (channel == 'sdk') {
      // SDK模式暂时注释
    } else if (channel == 'cf') {
      if (!kIsWeb && Platform.isAndroid) {
        Helper.setSpeakerphoneOn(contributorSpeakerphoneOn);
      }
    }
  }
  
  /// 设置麦克风开关
  void setMicrophoneOn(bool enabled) {
    if (channel == 'sdk') {
      // SDK模式暂时注释
    } else if (channel == 'cf') {
      if (localStream == null) return;
      
      if (isCaller) {
        for (var track in localStream!.getAudioTracks()) {
          track.enabled = enabled;
        }
      } else {
        if (!kIsWeb && Platform.isAndroid) {
          for (var track in localStream!.getAudioTracks()) {
            track.enabled = enabled;
          }
        }
      }
    }
  }
  
  /// 关闭对方麦克风
  void onStopSpeakerphone() {
    print('📣 发送关闭对方麦克风请求');
    if (channel == 'sdk') {
      // SDK模式暂时注释
    } else if (channel == 'cf') {
      signaling?.sendCommand({'type': 'stop_speakerphone'});
    }
  }
  
  /// 打开对方麦克风
  void onStartSpeakerphone() {
    print('📣 发送打开对方麦克风请求');
    if (channel == 'sdk') {
      // SDK模式暂时注释
    } else if (channel == 'cf') {
      signaling?.sendCommand({'type': 'start_speakerphone'});
    }
  }
  
  /// 设置对方扬声器状态
  void setContributorSpeakerphoneOn() async {
    final result = await showOkCancelAlertDialog(
      context: context,
      title: '温馨提示',
      message: contributorSpeakerphoneOn ? '确认要关闭对方麦克风？' : '确认要打开对方麦克风？',
      okLabel: '确认',
      cancelLabel: '取消',
    );
    
    if (result == OkCancelResult.ok) {
      setState(() {
        contributorSpeakerphoneOn = !contributorSpeakerphoneOn;
      });
      
      await EasyLoading.showToast(
        contributorSpeakerphoneOn ? '已开启对方麦克风' : '已关闭对方麦克风',
        duration: const Duration(seconds: 2)
      );
      
      if (contributorSpeakerphoneOn) {
        onStartSpeakerphone();
      } else {
        onStopSpeakerphone();
      }
    }
  }
  
  /// 设置本地麦克风状态
  void setMicphoneOn() async {
    // 获取当前麦克风状态
    bool currentMicOn = true;
    if (localStream != null && localStream!.getAudioTracks().isNotEmpty) {
      currentMicOn = localStream!.getAudioTracks().first.enabled;
    }
    
    final result = await showOkCancelAlertDialog(
      context: context,
      title: '温馨提示',
      message: currentMicOn ? '确认要关闭本地麦克风？' : '确认要打开本地麦克风？',
      okLabel: '确认',
      cancelLabel: '取消',
    );
    
    if (result == OkCancelResult.ok) {
      final newMicOn = !currentMicOn;
      setMicrophoneOn(newMicOn);
      
      await EasyLoading.showToast(
        newMicOn ? '已开启本地麦克风' : '已关闭本地麦克风',
        duration: const Duration(seconds: 2)
      );
      
      setState(() {});
    }
  }
  
  /// 检查是否有任何音频流
  bool hasAnyAudio() {
    if (localStream != null) {
      final audioTracks = localStream!.getAudioTracks();
      for (final track in audioTracks) {
        if (track.enabled) {
          return true;
        }
      }
    }
    return false;
  }
  
  /// 清理音频资源
  void disposeAudio() {
    // 移除音频路由监听
    if (kIsWeb) {
      navigator.mediaDevices.ondevicechange = null;
    }
    
    // 停止本地流
    localStream?.getAudioTracks().forEach((t) => t.stop());
  }
} 