// ignore_for_file: avoid_print

import 'dart:async';
// import 'dart:typed_data';
import 'package:flutter/services.dart';

/// A channel to receive screen stream data from iOS native side
class ScreenStreamChannel {
  static const EventChannel _channel = EventChannel('screen_stream_channel');
  
  /// Stream controller for processed video frames
  final _videoFrameController = StreamController<VideoFrame>.broadcast();
  
  /// Public stream of video frames that can be subscribed to
  Stream<VideoFrame> get videoFrameStream => _videoFrameController.stream;
  
  /// Singleton instance
  static final ScreenStreamChannel _instance = ScreenStreamChannel._internal();
  
  /// Factory constructor
  factory ScreenStreamChannel() => _instance;
  
  /// Internal constructor
  ScreenStreamChannel._internal() {
    _initChannel();
  }
  
  /// Initialize channel and start listening for frames
  void _initChannel() {
    _channel.receiveBroadcastStream().listen(_onFrameReceived, onError: _onError);
  }
  
  /// Process incoming frame data from native side
  void _onFrameReceived(dynamic event) {
    if (event is Map) {
      try {
        final width = event['width'] as int;
        final height = event['height'] as int;
        final bytesPerRow = event['bytesPerRow'] as int;
        final buffer = (event['buffer'] as Uint8List);
        
        final frame = VideoFrame(
          width: width,
          height: height,
          bytesPerRow: bytesPerRow,
          buffer: buffer,
        );
        
        _videoFrameController.add(frame);
      } catch (e) {
        print('Error processing video frame: $e');
      }
    }
  }
  
  /// Handle stream errors
  void _onError(dynamic error) {
    print('Screen stream error: $error');
  }
  
  /// Dispose resources
  void dispose() {
    _videoFrameController.close();
  }
}

/// Class representing a video frame
class VideoFrame {
  final int width;
  final int height;
  final int bytesPerRow;
  final Uint8List buffer;
  
  VideoFrame({
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.buffer,
  });
} 