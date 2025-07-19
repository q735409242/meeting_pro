// ignore_for_file: avoid_print

import 'package:flutter/services.dart';

class WakelockService {
  static const MethodChannel _channel = MethodChannel('wakelock_service');

  static Future<void> acquire() async {
    try {
      await _channel.invokeMethod('acquire');
    } catch (e) {
      print('Error acquiring wakelock: $e');
    }
  }

  static Future<void> release() async {
    try {
      await _channel.invokeMethod('release');
    } catch (e) {
      print('Error releasing wakelock: $e');
    }
  }
}