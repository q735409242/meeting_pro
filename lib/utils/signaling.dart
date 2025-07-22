// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';

// 条件导入：Web和移动端使用不同的WebSocket实现
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart' if (dart.library.html) 'package:web_socket_channel/html.dart';

/// 信令封装类（升级版：支持掉线自动重连）
class Signaling {
  final String roomId;
  final bool isCaller;
  late RTCPeerConnection pc;

  /// 收到远端 SDP 后回调
  final Function(RTCSessionDescription) onRemoteSDP;

  /// 收到远端 Candidate 后回调
  final Function(RTCIceCandidate) onRemoteCandidate;

  /// 收到远端自定义命令后回调
  final void Function(Map<String, dynamic> command)? onRemoteCommand;

  /// 断开连接回调
  final void Function()? onDisconnected;

  /// 重新连接成功回调
  final void Function()? onReconnected;

  /// 信令服务器地址列表
  final List<String> _signalingUrls = [
    'wss://stun.yunkefu.pro/signaling',
    'wss://stun.yunkefu.vip/signaling',
    'wss://stun.yunkefu.work/signaling',
  ];
  int _currentUrlIndex = 0;

  WebSocketChannel? _ws;
  StreamSubscription? _wsSubscription;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  Timer? _pingTimer;
  DateTime? _lastPongTime;

  Signaling({
    required this.roomId,
    required this.isCaller,
    required this.pc,
    required this.onRemoteSDP,
    required this.onRemoteCandidate,
    this.onRemoteCommand,
    this.onDisconnected,
    this.onReconnected,
  });

  /// Reorders the SDP to prefer H.264 for video.
  // String _preferH264(String sdp) {
  //   // Find the m=video line and reorder payload IDs.
  //   return sdp.replaceFirstMapped(
  //     RegExp(r'm=video ([0-9]+) RTP/AVP ([0-9 ]+)'),
  //     (m) {
  //       final port = m.group(1);
  //       final payloads = m.group(2)!.split(' ');
  //       // Identify H.264 payloads by inspecting a=rtpmap lines in the SDP.
  //       final h264List = payloads.where((p) =>
  //           sdp.contains(RegExp(r'a=rtpmap:$p H264', caseSensitive: false))
  //       ).toList();
  //       final nonH264 = payloads.where((p) => !h264List.contains(p)).toList();
  //       final reordered = [...h264List, ...nonH264].join(' ');
  //       return 'm=video $port RTP/AVP $reordered';
  //     },
  //   );
  // }

  /// 建立 WebSocket 连接并开始监听
  Future<void> connect() async {
    if (_isConnecting) return;
    _isConnecting = true;

    // print("🔌 信令连接中: $roomId");
    final urlBase = _signalingUrls[_currentUrlIndex];
    final fullUrl = '$urlBase?room=$roomId';
    print("🔌 信令连接中 (尝试地址 #$_currentUrlIndex): $fullUrl");
    try {
      // 使用统一的WebSocketChannel.connect()，支持Web和移动端
      _ws = WebSocketChannel.connect(Uri.parse(fullUrl));
      
      // 等待连接建立，添加超时处理
      await _ws!.ready.timeout(const Duration(seconds: 30));
      _wsSubscription = _ws!.stream.listen(
        (data) async {
          final msg = jsonDecode(data);

          if (msg['type'] == 'pong') {
            _lastPongTime = DateTime.now();
            return;
          } else if (msg['type'] == 'ping') {
            _ws?.sink.add(jsonEncode({'type': 'pong'}));
            return;
          }

          if (msg['sdp'] != null) {
            print("📩 收到 SDP: ${msg['sdp']['type']}");
            final desc = RTCSessionDescription(msg['sdp']['sdp'], msg['sdp']['type']);
            onRemoteSDP(desc);
          } else if (msg['candidate'] != null) {
            print("📩 收到 Candidate");
            final candidate = RTCIceCandidate(
              msg['candidate']['candidate'],
              msg['candidate']['sdpMid'],
              msg['candidate']['sdpMLineIndex'],
            );
            onRemoteCandidate(candidate);
          } else if (msg['command'] != null) {
            // print("📩 收到命令: ${msg['command']}");
            final command = msg['command'];
            onRemoteCommand?.call(command);
          } else {
            print("📩 收到未知消息: $msg");
          }
        },
        onDone: () {
          print('⚡️ 信令连接 onDone，尝试切换备用地址');
          if (_currentUrlIndex + 1 < _signalingUrls.length) {
            _currentUrlIndex++;
            print("🔁 onDone 切换到备用地址 #$_currentUrlIndex 并重连");
            connect();
          } else {
            print("🚫 onDone 已是最后一个地址，调用 _handleDisconnect");
            _currentUrlIndex = 0;
            _handleDisconnect();
          }
        },
        onError: (error) {
          print('❌ 信令连接出错 (地址 #$_currentUrlIndex): $error');
          // 切换到备用地址后重连
          if (_currentUrlIndex + 1 < _signalingUrls.length) {
            _currentUrlIndex++;
            print("🔁 onError 切换到备用地址 #$_currentUrlIndex 并重连");
            connect();
          } else {
            print("🚫 onError 已经是最后一个地址，开始定时重连");
            _currentUrlIndex = 0;
            _handleDisconnect();
          }
        },
        cancelOnError: true,
      );

      print("✅ 信令连接成功 (地址 #$_currentUrlIndex)");
      _startHeartbeat();
      _isConnecting = false;
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();
      onReconnected?.call();
    } catch (e) {
      print('❌ 信令连接异常 (地址 #$_currentUrlIndex): $e');
      _isConnecting = false;
      // 如果还有备用地址，切换后重试
      if (_currentUrlIndex + 1 < _signalingUrls.length) {
        _currentUrlIndex++;
        print("🔁 切换到备用地址 #$_currentUrlIndex 并重试");
        await connect();
      } else {
        // 所有地址都试过了，进入定时重连
        print("🚫 所有信令服务器连接失败，开始定时重连");
        _currentUrlIndex = 0; // 重置到主地址
        _scheduleReconnect();
      }
    }
  }

  void _handleDisconnect() {
    print('⚡️ 信令连接断开');
    _stopHeartbeat();
    _isConnecting = false;
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _ws = null;
    onDisconnected?.call();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) return; // 已经在重连，不要重复定时器

    _reconnectAttempts++;
    final int delay = (_reconnectAttempts * 2).clamp(2, 10); // 重连间隔 2~10秒

    print('🔄 $delay秒后重试连接 (第$_reconnectAttempts次)');
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      _reconnectTimer = null;
      connect();
    });
  }

  /// 发送 SDP 到对端
  void sendSDP(RTCSessionDescription desc) {
    print("📤 原始 SDP: ${desc.type}");
    // 不再修改 SDP，直接发送原始 SDP
    _ws?.sink.add(jsonEncode({
      'sdp': {
        'type': desc.type,
        'sdp': desc.sdp,
      }
    }));
    print("✅ 直接发送原始 SDP");
    // 0️⃣ Prefer H.264 before injecting extensions
    // final sdp0 = desc.sdp!;
    // final sdpWithH264 = _preferH264(sdp0);
    // String modifiedSdp = sdpWithH264.replaceFirst(
    //   RegExp(r'a=mid:video'),
    //   'a=extmap:5 http://www.webrtc.org/experiments/rtp-hdrext/playout-delay\r\n'
    //       'a=mid:video',
    // );
    //
    // // 2️⃣ 构造新的描述对象
    // final RTCSessionDescription modifiedDesc =
    // RTCSessionDescription(modifiedSdp, desc.type);
    //
    // // 3️⃣ 发送注入后的 SDP
    // _ws?.sink.add(jsonEncode({
    //   'sdp': {
    //     'type': modifiedDesc.type,
    //     'sdp': modifiedDesc.sdp,
    //   }
    // }));
    // print("✅ 已注入 playout-delay 并发送 SDP");
  }

  /// 发送 ICE Candidate 到对端
  void sendCandidate(RTCIceCandidate candidate) {
    print("📤 发送 candidate");
    _ws?.sink.add(jsonEncode({
      'candidate': {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      }
    }));
  }

  /// 发送自定义命令到对端
  void sendCommand(Map<String, dynamic> command) {
    // print("📤 发送 Command: $command");
    _ws?.sink.add(jsonEncode({
      'command': command,
    }));
  }

  /// 主动关闭连接
  void close() {
    print('📴 [Signaling] 开始主动关闭信令连接');

    _stopHeartbeat();

    // 1. 取消重连定时器
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // 2. 取消 WebSocket 监听
    _wsSubscription?.cancel();
    _wsSubscription = null;

    // 3. 关闭 WebSocket
    if (_ws != null) {
      try {
        if (_ws!.closeCode == null) { // 只有在还没关闭的情况下再主动关
          print('📴 [Signaling] 正在关闭 WebSocket...');
          _ws!.sink.close(1000, 'Normal Closure'); // 使用合法的 close code
        } else {
          print('ℹ️ [Signaling] WebSocket 已经关闭 (code=${_ws!.closeCode})，无需重复关闭');
        }
      } catch (e, stack) {
        print('⚠️ [Signaling] 关闭 WebSocket 出错: $e\n$stack');
      }
      _ws = null;
    } else {
      print('ℹ️ [Signaling] WebSocket 已为空，无需关闭');
    }

    // 4. 重置连接状态
    _isConnecting = false;

    print('📴 [Signaling] 信令连接已完全关闭');
  }

  void _startHeartbeat() {
    _lastPongTime = DateTime.now();
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_ws == null || _ws!.closeCode != null) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      if (_lastPongTime != null &&
          now.difference(_lastPongTime!).inSeconds > 60) {
        print('⏱️ 心跳超时，未收到 pong，主动断开连接');
        _handleDisconnect();
        return;
      }

      print('🔄 发送 ping');
      _ws?.sink.add(jsonEncode({'type': 'ping'}));
    });
  }

  void _stopHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }
}