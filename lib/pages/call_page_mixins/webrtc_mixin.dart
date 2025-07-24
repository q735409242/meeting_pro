import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

/// WebRTC连接管理模块 - 负责P2P连接、SDP、ICE处理等功能
mixin WebRTCMixin<T extends StatefulWidget> on State<T> {
  // 需要子类实现的抽象属性
  bool get isCaller;
  String? get channel;
  dynamic get signaling;
  RTCPeerConnection? get pc;
  set pc(RTCPeerConnection? value);
  MediaStream? get localStream;
  set localStream(MediaStream? value);
  RTCVideoRenderer get remoteRenderer;
  bool get isConnected;
  set isConnected(bool value);
  
  /// WebRTC配置
  Map<String, dynamic> get rtcConfiguration => {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'iceCandidatePoolSize': 10,
  };
  
  /// 媒体约束
  Map<String, dynamic> get mediaConstraints => {
    'audio': true,
    'video': {
      'width': 1280,
      'height': 720,
      'frameRate': 30,
    }
  };
  
  /// 创建PeerConnection（需要子类实现具体创建逻辑）
  Future<void> createPeerConnection() async {
    print('🔗 创建PeerConnection...');
    // 具体实现由子类完成
    await registerPeerConnectionListeners();
    print('✅ PeerConnection创建成功');
  }
  
  /// 注册PeerConnection监听器
  Future<void> registerPeerConnectionListeners() async {
    if (pc == null) return;
    
    // ICE候选者监听
    pc!.onIceCandidate = (RTCIceCandidate candidate) {
      print('🧊 本地ICE候选者: ${candidate.candidate}');
      if (channel == 'cf') {
        signaling?.sendIceCandidate(candidate);
      }
    };
    
    // ICE连接状态监听
    pc!.onIceConnectionState = (RTCIceConnectionState state) {
      print('🧊 ICE连接状态变化: $state');
      handleIceConnectionStateChange(state);
    };
    
    // 连接状态监听
    pc!.onConnectionState = (RTCPeerConnectionState state) {
      print('🔗 连接状态变化: $state');
      handleConnectionStateChange(state);
    };
    
    // 远程流监听
    pc!.onAddStream = (MediaStream stream) {
      print('📺 接收到远程流: ${stream.id}');
      handleRemoteStream(stream);
    };
    
    // 数据通道监听
    pc!.onDataChannel = (RTCDataChannel dataChannel) {
      print('📡 接收到数据通道: ${dataChannel.label}');
    };
    
    print('✅ PeerConnection监听器已注册');
  }
  
  /// 处理ICE连接状态变化
  void handleIceConnectionStateChange(RTCIceConnectionState state) {
    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
        print('✅ ICE连接已建立');
        setState(() {
          isConnected = true;
        });
        break;
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        print('⚠️ ICE连接断开');
        setState(() {
          isConnected = false;
        });
        break;
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        print('❌ ICE连接失败');
        setState(() {
          isConnected = false;
        });
        break;
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        print('🔒 ICE连接已关闭');
        setState(() {
          isConnected = false;
        });
        break;
      default:
        print('🧊 ICE状态: $state');
        break;
    }
  }
  
  /// 处理连接状态变化
  void handleConnectionStateChange(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        print('✅ PeerConnection已连接');
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        print('⚠️ PeerConnection断开');
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        print('❌ PeerConnection失败');
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        print('🔒 PeerConnection已关闭');
        break;
      default:
        print('🔗 连接状态: $state');
        break;
    }
  }
  
  /// 处理远程流
  void handleRemoteStream(MediaStream stream) {
    try {
      remoteRenderer.srcObject = stream;
      setState(() {});
      print('✅ 远程流已设置到渲染器');
    } catch (e) {
      print('❌ 设置远程流失败: $e');
    }
  }
  
  /// 获取本地媒体流
  Future<void> getUserMedia() async {
    try {
      print('🎥 获取本地媒体流...');
      
      localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      
      if (localStream != null) {
        print('✅ 本地媒体流获取成功');
        print('🎤 音频轨道数: ${localStream!.getAudioTracks().length}');
        print('🎥 视频轨道数: ${localStream!.getVideoTracks().length}');
      }
    } catch (e) {
      print('❌ 获取本地媒体流失败: $e');
      throw Exception('获取本地媒体流失败: $e');
    }
  }
  
  /// 添加本地流到PeerConnection
  Future<void> addLocalStreamToPeerConnection() async {
    if (pc == null || localStream == null) {
      print('⚠️ PeerConnection或本地流为空，跳过添加流');
      return;
    }
    
    try {
      print('📤 添加本地流到PeerConnection...');
      await pc!.addStream(localStream!);
      print('✅ 本地流已添加到PeerConnection');
    } catch (e) {
      print('❌ 添加本地流失败: $e');
    }
  }
  
  /// 创建Offer
  Future<RTCSessionDescription?> createOffer() async {
    if (pc == null) {
      print('❌ PeerConnection为空，无法创建Offer');
      return null;
    }
    
    try {
      print('📝 创建SDP Offer...');
      
      final offer = await pc!.createOffer();
      await pc!.setLocalDescription(offer);
      
      print('✅ SDP Offer创建成功');
      print('📝 Offer类型: ${offer.type}');
      
      return offer;
    } catch (e) {
      print('❌ 创建Offer失败: $e');
      return null;
    }
  }
  
  /// 创建Answer
  Future<RTCSessionDescription?> createAnswer() async {
    if (pc == null) {
      print('❌ PeerConnection为空，无法创建Answer');
      return null;
    }
    
    try {
      print('📝 创建SDP Answer...');
      
      final answer = await pc!.createAnswer();
      await pc!.setLocalDescription(answer);
      
      print('✅ SDP Answer创建成功');
      print('📝 Answer类型: ${answer.type}');
      
      return answer;
    } catch (e) {
      print('❌ 创建Answer失败: $e');
      return null;
    }
  }
  
  /// 处理远程SDP
  Future<void> onRemoteSDP(RTCSessionDescription desc) async {
    if (pc == null) {
      print('❌ PeerConnection为空，无法处理远程SDP');
      return;
    }
    
    try {
      print('📨 收到远程SDP: ${desc.type}');
      
      await pc!.setRemoteDescription(desc);
      print('✅ 远程SDP设置成功');
      
      // 如果是接收到offer，需要创建answer
      if (desc.type == 'offer') {
        print('📝 收到Offer，准备创建Answer...');
        final answer = await createAnswer();
        
        if (answer != null && channel == 'cf') {
          signaling?.sendSDP(answer);
          print('📤 Answer已发送');
        }
      }
    } catch (e) {
      print('❌ 处理远程SDP失败: $e');
      await EasyLoading.showError('处理远程SDP失败: $e');
    }
  }
  
  /// 处理远程ICE候选者
  Future<void> onRemoteCandidate(RTCIceCandidate cand) async {
    if (pc == null) {
      print('❌ PeerConnection为空，无法添加ICE候选者');
      return;
    }
    
    try {
      print('🧊 收到远程ICE候选者: ${cand.candidate}');
      
      await pc!.addCandidate(cand);
      print('✅ ICE候选者已添加');
    } catch (e) {
      print('❌ 添加ICE候选者失败: $e');
    }
  }
  
  /// 检查并恢复远程流
  Future<void> checkAndRestoreRemoteStream() async {
    try {
      print('🔍 检查远程流状态...');
      
      if (pc != null) {
        final senders = await pc!.getSenders();
        final receivers = await pc!.getReceivers();
        
        print('📤 发送器数量: ${senders.length}');
        print('📥 接收器数量: ${receivers.length}');
        
        // 检查是否有活跃的接收器
        bool hasActiveReceiver = false;
        for (final receiver in receivers) {
          if (receiver.track != null) {
            hasActiveReceiver = true;
            print('📡 发现活跃接收器: ${receiver.track!.id}');
            
                         // 尝试恢复远程流（具体实现由子类完成）
             if (remoteRenderer.srcObject == null) {
               print('⚠️ 远程渲染器没有流对象，需要恢复');
             }
          }
        }
        
        if (!hasActiveReceiver) {
          print('⚠️ 未发现活跃的远程流接收器');
        }
      }
    } catch (e) {
      print('❌ 检查远程流失败: $e');
    }
  }
  
  /// 执行硬重连
  Future<void> performHardReconnect() async {
    try {
      print('🔄 执行硬重连...');
      
      // 清理现有连接
      await disposeWebRTC();
      
      // 等待一段时间
      await Future.delayed(const Duration(seconds: 2));
      
      // 重新创建连接
      await createPeerConnection();
      await getUserMedia();
      await addLocalStreamToPeerConnection();
      
      print('✅ 硬重连完成');
    } catch (e) {
      print('❌ 硬重连失败: $e');
      throw Exception('硬重连失败: $e');
    }
  }
  
  /// 清理WebRTC资源
  Future<void> disposeWebRTC() async {
    try {
      print('🧹 清理WebRTC资源...');
      
      // 停止本地流
      if (localStream != null) {
        localStream!.getTracks().forEach((track) {
          track.stop();
        });
        localStream = null;
      }
      
      // 清理远程渲染器
      if (remoteRenderer.srcObject != null) {
        remoteRenderer.srcObject!.getTracks().forEach((track) {
          track.stop();
        });
        remoteRenderer.srcObject = null;
      }
      
      // 关闭PeerConnection
      if (pc != null) {
        await pc!.close();
        pc = null;
      }
      
      setState(() {
        isConnected = false;
      });
      
      print('✅ WebRTC资源清理完成');
    } catch (e) {
      print('❌ 清理WebRTC资源失败: $e');
    }
  }
} 