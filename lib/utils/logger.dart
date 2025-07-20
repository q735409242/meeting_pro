import 'package:flutter/foundation.dart';

/// 智能条件日志工具 - 开发环境有日志，生产环境静默
class Logger {
  // 开发环境检测
  static bool get _isDevelopment => kDebugMode;
  
  // Web平台检测
  static bool get _isWeb => kIsWeb;
  
  /// 判断是否应该打印日志
  static bool get _shouldLog {
    if (_isWeb) {
      // Web端：开发环境(kDebugMode)有日志，生产环境静默
      return _isDevelopment;
    } else {
      // 移动端：开发环境才打印
      return _isDevelopment;
    }
  }
  
  /// 手动设置Web端日志开关（调试用，覆盖默认行为）
  static bool? _forceWebLogging;
  static void enableWebLogging(bool enable) {
    _forceWebLogging = enable;
  }
  
  /// 最终日志判断（包含强制设置）
  static bool get _finalShouldLog {
    if (_isWeb && _forceWebLogging != null) {
      return _forceWebLogging!;
    }
    return _shouldLog;
  }
  
  /// 普通日志
  static void log(String message) {
    if (_finalShouldLog) {
      if (kDebugMode) {
        print(message);
      }
    }
  }
  
  /// 信息日志
  static void info(String message) {
    if (_finalShouldLog) {
      if (kDebugMode) {
        print('ℹ️ $message');
      }
    }
  }
  
  /// 成功日志
  static void success(String message) {
    if (_finalShouldLog) {
      if (kDebugMode) {
        print('✅ $message');
      }
    }
  }
  
  /// 警告日志
  static void warning(String message) {
    if (_finalShouldLog) {
      if (kDebugMode) {
        print('⚠️ $message');
      }
    }
  }
  
  /// 错误日志
  static void error(String message) {
    if (_finalShouldLog) {
      if (kDebugMode) {
        print('❌ $message');
      }
    }
  }
  
  /// 调试日志
  static void debug(String message) {
    if (_finalShouldLog) {
      if (kDebugMode) {
        print('🔍 $message');
      }
    }
  }
  
  /// 网络日志
  static void network(String message) {
    if (_finalShouldLog) {
      if (kDebugMode) {
        print('🌐 $message');
      }
    }
  }
  
  /// 手势日志
  static void gesture(String message) {
    if (_finalShouldLog) {
      if (kDebugMode) {
        print('🖱️ $message');
      }
    }
  }
  
  /// 音频日志
  static void audio(String message) {
    if (_finalShouldLog) {
      if (kDebugMode) {
        print('🔈 $message');
      }
    }
  }
  
  /// 视频日志
  static void video(String message) {
    if (_finalShouldLog) {
      if (kDebugMode) {
        print('📺 $message');
      }
    }
  }
  
  /// 信令日志
  static void signaling(String message) {
    if (_finalShouldLog) {
      if (kDebugMode) {
        print('📡 $message');
      }
    }
  }
} 