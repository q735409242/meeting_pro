import 'package:flutter/foundation.dart';

/// 条件日志工具 - Web端默认静默
class Logger {
  // Web端是否启用日志 - 默认false（静默）
  static bool _isWebLoggingEnabled = false;
  
  // 开发环境检测
  static bool get _isDevelopment => kDebugMode;
  
  // Web平台检测
  static bool get _isWeb => kIsWeb;
  
  /// 设置Web端日志开关（仅调试时使用）
  static void enableWebLogging(bool enable) {
    _isWebLoggingEnabled = enable;
  }
  
  /// 判断是否应该打印日志
  static bool get _shouldLog {
    if (_isWeb) {
      // Web端：只有明确开启才打印
      return _isWebLoggingEnabled;
    } else {
      // 移动端：开发环境才打印
      return _isDevelopment;
    }
  }
  
  /// 普通日志
  static void log(String message) {
    if (_shouldLog) {
      if (kDebugMode) {
        print(message);
      }
    }
  }
  
  /// 信息日志
  static void info(String message) {
    if (_shouldLog) {
      if (kDebugMode) {
        print('ℹ️ $message');
      }
    }
  }
  
  /// 成功日志
  static void success(String message) {
    if (_shouldLog) {
      if (kDebugMode) {
        print('✅ $message');
      }
    }
  }
  
  /// 警告日志
  static void warning(String message) {
    if (_shouldLog) {
      if (kDebugMode) {
        print('⚠️ $message');
      }
    }
  }
  
  /// 错误日志
  static void error(String message) {
    if (_shouldLog) {
      if (kDebugMode) {
        print('❌ $message');
      }
    }
  }
  
  /// 调试日志
  static void debug(String message) {
    if (_shouldLog) {
      if (kDebugMode) {
        print('🔍 $message');
      }
    }
  }
  
  /// 网络日志
  static void network(String message) {
    if (_shouldLog) {
      if (kDebugMode) {
        print('🌐 $message');
      }
    }
  }
  
  /// 手势日志
  static void gesture(String message) {
    if (_shouldLog) {
      if (kDebugMode) {
        print('🖱️ $message');
      }
    }
  }
  
  /// 音频日志
  static void audio(String message) {
    if (_shouldLog) {
      if (kDebugMode) {
        print('🔈 $message');
      }
    }
  }
  
  /// 视频日志
  static void video(String message) {
    if (_shouldLog) {
      if (kDebugMode) {
        print('📺 $message');
      }
    }
  }
  
  /// 信令日志
  static void signaling(String message) {
    if (_shouldLog) {
      if (kDebugMode) {
        print('📡 $message');
      }
    }
  }
} 