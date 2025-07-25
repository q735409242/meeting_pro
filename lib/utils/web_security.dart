import 'dart:async';
import 'package:flutter/foundation.dart';
// 条件导入：Web平台使用dart:js_util，其他平台使用stub
import 'web_security_stub.dart' if (dart.library.js_util) 'web_security_web.dart';

/// Web端简化防护 - 禁止右键、调试工具 + 开发者工具检测
class WebSecurity {
  static bool _isInitialized = false;
  static Timer? _devtoolsDetectionTimer;
  static Timer? _loadCheckTimer;
  static bool _pageFullyLoaded = false; // 页面完全加载标记
  static DateTime? _initTime; // 初始化时间
  
  /// 初始化Web防护功能（只在生产环境启用）
  static void initialize() {
    // 非Web平台直接返回
    if (!kIsWeb || _isInitialized) return;
    
    // 记录初始化时间
    _initTime = DateTime.now();
    
    // Web平台才执行后续逻辑
    _initializeWeb();
  }
  
  /// Web平台专用初始化
  static void _initializeWeb() {
    // 检测是否为本地调试环境
    if (_isLocalDebugMode()) {
      print('🔧 本地调试模式，跳过Web防护限制');
      return;
    }
    
    _isInitialized = true;
    print('🛡️ 生产环境，正在初始化Web防护...');
    
    // 1. 禁用右键菜单
    _disableContextMenu();
    
    // 2. 禁用调试工具快捷键
    _disableDebugKeys();
    
    // 3. 智能等待页面完全加载后再启动检测
    _smartWaitForPageLoadAndStartDetection();
    
    print('✅ Web防护已启用（禁止右键 + 调试工具 + 智能检测模式）');
  }
  
  /// 智能等待页面加载完成后启动检测
  static void _smartWaitForPageLoadAndStartDetection() {
    if (!kIsWeb) return;
    
    print('📱 开始智能检测页面加载状态...');
    
    // 设置页面加载检测逻辑
    try {
      jsEval('''
        // 智能页面加载检测
        window._pageLoadStatus = {
          domReady: false,
          windowLoaded: false,
          flutterReady: false,
          assetsLoaded: false,
          fullyReady: false
        };
        
        // 检测DOM加载完成
        if (document.readyState === 'complete') {
          window._pageLoadStatus.domReady = true;
          window._pageLoadStatus.windowLoaded = true;
        } else if (document.readyState === 'interactive') {
          window._pageLoadStatus.domReady = true;
        }
        
        // 监听DOM加载完成
        document.addEventListener('DOMContentLoaded', function() {
          window._pageLoadStatus.domReady = true;
          console.log('📱 DOM加载完成');
        });
        
        // 监听窗口加载完成
        window.addEventListener('load', function() {
          window._pageLoadStatus.windowLoaded = true;
          console.log('📱 窗口加载完成');
        });
        
        // 监听Flutter初始化（如果有的话）
        window.addEventListener('flutter-initialized', function() {
          window._pageLoadStatus.flutterReady = true;
          console.log('📱 Flutter初始化完成');
        });
          
        // 检测资源加载完成
        var checkAssetsLoaded = function() {
          var images = document.querySelectorAll('img');
          var scripts = document.querySelectorAll('script');
          var links = document.querySelectorAll('link[rel="stylesheet"]');
          
          var allLoaded = true;
          
          // 检查图片
          for (var i = 0; i < images.length; i++) {
            if (!images[i].complete) {
              allLoaded = false;
              break;
            }
          }
          
          if (allLoaded) {
            window._pageLoadStatus.assetsLoaded = true;
            console.log('📱 资源加载完成');
          }
          
          return allLoaded;
        };
        
        // 定期检查资源加载状态
        var assetCheckInterval = setInterval(function() {
          if (checkAssetsLoaded()) {
            clearInterval(assetCheckInterval);
          }
        }, 500);
          
        // 综合判断页面是否完全准备好
        window._checkPageFullyReady = function() {
          var status = window._pageLoadStatus;
          
          // 必须满足的基本条件
          if (!status.domReady || !status.windowLoaded) {
            return false;
          }
          
          // 可选条件（Flutter可能不存在）
          var flutterCondition = status.flutterReady || 
                                (typeof flutter === 'undefined' && 
                                 document.querySelector('flutter-view, flt-scene-host, flt-semantics-host') !== null);
          
          // 资源加载条件（允许部分失败）
          var assetsCondition = status.assetsLoaded || 
                               (Date.now() - window._initStartTime) > 8000; // 8秒后强制认为资源加载完成
          
          if (flutterCondition && assetsCondition) {
            if (!status.fullyReady) {
              status.fullyReady = true;
              console.log('✅ 页面完全准备就绪');
              window._appFullyReady = true;
            }
          return true;
          }
          
          return false;
        };
        
        // 记录初始化开始时间
        window._initStartTime = Date.now();
        
        // 立即检查一次
        window._checkPageFullyReady();
      ''');
    } catch (e) {
      print('⚠️ 智能页面加载检测设置失败: $e');
    }
    
    // 开始定期检查页面加载状态
    _loadCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkPageLoadStatus();
    });
    
    // 设置最大等待时间（10秒兜底）
    Timer(const Duration(seconds: 10), () {
      if (!_pageFullyLoaded) {
        print('⏰ 达到最大等待时间，强制启动检测');
        _pageFullyLoaded = true;
        _loadCheckTimer?.cancel();
        _loadCheckTimer = null;
        _startDevtoolsDetection();
      }
    });
  }
  
  /// 检查页面加载状态
  static void _checkPageLoadStatus() {
    if (!kIsWeb || _pageFullyLoaded) return;
    
    try {
      final result = jsEval('window._checkPageFullyReady && window._checkPageFullyReady()');
      final isReady = result.toString() == 'true';
      
      if (isReady) {
        _pageFullyLoaded = true;
        _loadCheckTimer?.cancel();
        _loadCheckTimer = null;
        
        print('🎯 智能检测：页面完全加载完成，启动开发者工具检测');
        _startDevtoolsDetection();
      }
    } catch (e) {
      print('⚠️ 页面加载状态检查失败: $e');
    }
  }
  
  /// 检测是否为本地调试模式
  static bool _isLocalDebugMode() {
    if (!kIsWeb) return true;
    
    try {
      // 使用动态调用避免编译时检查
      final location = _getWebLocation();
      final currentUrl = location['href'] as String;
      
      // 检测本地开发环境
      return currentUrl.contains('localhost') || 
             currentUrl.contains('127.0.0.1') ||
             currentUrl.contains('http://[::1]') ||
             currentUrl.startsWith('file://') ||
             kDebugMode;
    } catch (e) {
      return true; // 出错时默认为调试模式
    }
  }
  
  /// 获取Web location对象（动态调用）
  static Map<String, dynamic> _getWebLocation() {
    if (!kIsWeb) return {};
    
    try {
      // 动态获取window.location
      final result = jsEval('window.location.href');
      return {'href': result.toString()};
    } catch (e) {
      return {'href': ''};
    }
  }
  
  /// 禁用右键菜单
  static void _disableContextMenu() {
    if (!kIsWeb) return;
    
    try {
      // 使用eval执行JavaScript代码
      jsEval('''
        // 禁用右键菜单
      document.addEventListener('contextmenu', function(e) {
          e.preventDefault();
          return false;
        }, true);
        
        // 禁用选择文本
        document.addEventListener('selectstart', function(e) {
          e.preventDefault();
          return false;
        }, true);
        
        // 禁用拖拽
        document.addEventListener('dragstart', function(e) {
          e.preventDefault();
          return false;
        }, true);
      ''');
    } catch (e) {
      print('⚠️ 禁用右键菜单失败: $e');
    }
  }
  
  /// 禁用调试工具快捷键
  static void _disableDebugKeys() {
    if (!kIsWeb) return;
    
    try {
      jsEval('''
        document.addEventListener('keydown', function(e) {
          const key = e.key;
          const ctrlKey = e.ctrlKey;
          const shiftKey = e.shiftKey;
          const altKey = e.altKey;
          const metaKey = e.metaKey;
          
          // 禁用常见调试快捷键
          if (
            // F12 - 开发者工具
            key === 'F12' ||
            // Ctrl+Shift+I - 开发者工具
            (ctrlKey && shiftKey && key === 'I') ||
            // Ctrl+Shift+J - 控制台
            (ctrlKey && shiftKey && key === 'J') ||
            // Ctrl+Shift+C - 元素检查器
            (ctrlKey && shiftKey && key === 'C') ||
            // Ctrl+U - 查看源代码
            (ctrlKey && key === 'u') ||
            // Ctrl+S - 保存页面
            (ctrlKey && key === 's') ||
            // F5 - 刷新页面
            key === 'F5' ||
            // Ctrl+R - 刷新页面
            (ctrlKey && key === 'r') ||
            // Alt+F4 - 关闭窗口
            (altKey && key === 'F4') ||
            // Ctrl+Shift+Delete - 清除数据
            (ctrlKey && shiftKey && key === 'Delete')
          ) {
            e.preventDefault();
            e.stopPropagation();
            // 静默禁止，不触发无限debug
          }
        }, true);
        
        // 监听按键组合
        document.addEventListener('keyup', function(e) {
          // 额外的反调试检测
          if (e.key === 'F12') {
          e.preventDefault();
            e.stopPropagation();
            // 静默禁止，不触发无限debug
          }
        }, true);
      ''');
    } catch (e) {
      print('⚠️ 禁用调试快捷键失败: $e');
    }
  }
  
  /// 启动开发者工具检测（激进模式）
  static void _startDevtoolsDetection() {
    if (!kIsWeb) return;
    
    print('🔍 启动激进的开发者工具检测（无窗口尺寸检测）...');
    
    // 每1秒检测一次开发者工具
    _devtoolsDetectionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _detectDevtools();
    });
    
    // 安装激进的检测机制（不包含窗口尺寸检测）
    _installDevtoolsDetectors();
        }
        
  /// 安装激进的开发者工具检测器（不包含窗口尺寸检测）
  static void _installDevtoolsDetectors() {
    if (!kIsWeb) return;
    
    try {
      jsEval('''
        // 全局无限debug函数
        window._triggerInfiniteDebug = function(reason) {
          console.clear();
          
          // 显示具体的触发原因
          var triggerReason = reason || '未知原因';
          console.log('%c🚨 检测到开发者工具 - ' + triggerReason + ' 🚨', 'color: red; font-size: 20px; font-weight: bold;');
          
          // 启动无限debugger循环
          setInterval(function() {
            debugger;
          }, 10);
          
          setInterval(function() {
            debugger;
          }, 20);
          
          setInterval(function() {
            debugger;
          }, 30);
          
          // 立即执行断点
          debugger;
          debugger;  
          debugger;
          
          // 控制台干扰
          console.clear();
          console.log('%c🚨 系统安全保护激活 🚨', 'color: red; font-size: 20px; font-weight: bold;');
          console.log('%c触发原因: ' + triggerReason, 'color: red; font-size: 16px;');
          console.log('%c请关闭开发者工具！', 'color: red; font-size: 16px;');
          
          // 页面标题闪烁警告
          setInterval(function() {
            document.title = '🚨 检测到开发者工具 - ' + triggerReason + ' 🚨';
            setTimeout(function() {
              document.title = '⚠️ 系统安全保护中... ⚠️';
            }, 500);
          }, 1000);
        };
        
        // 激进检测：调试器断点检测
        setInterval(function() {
          try {
            const start = performance.now();
            debugger; // 如果有调试器，这里会暂停
            const end = performance.now();
            
            // 如果时间差异过大，说明遇到了断点
            if (end - start > 1000) {
              console.log('🚨 检测到调试器断点！时间差异: ' + (end - start) + 'ms');
              window._triggerInfiniteDebug('调试器断点检测触发，时间差异' + Math.round(end - start) + 'ms');
            }
          } catch (e) {
            // 异常处理
          }
        }, 500);
        
      ''');
    } catch (e) {
      print('⚠️ 安装开发者工具检测器失败: $e');
    }
  }
  
  /// 检测开发者工具（激进模式，无窗口尺寸检测）
  static void _detectDevtools() {
    if (!kIsWeb) return;
    
    // 检查页面是否完全加载
    if (!_pageFullyLoaded) {
      return;
    }
    
    try {
      // 使用激进的JavaScript检测开发者工具（移除窗口尺寸检测）
      final result = jsEval('''
        (function() {
          // 方法1: Firebug检测
          if (window.console && window.console.firebug) {
            console.log('🚨 检测到Firebug调试工具！');
            window._triggerInfiniteDebug('Firebug调试工具检测');
            return true;
          }
          
          // 方法2: 检测控制台是否打开（通过toString方法）
          var devtools = false;
          
          var element = new Image();
          element.__defineGetter__('id', function() {
            devtools = true;
          });
          
          console.dir(element);
          console.clear();
          
          if (devtools) {
            console.log('🚨 检测到控制台打开（toString方法）！');
            window._triggerInfiniteDebug('控制台toString方法检测');
            return true;
          }
          
          // 方法3: 检测调试工具特征
          if (window.chrome && window.chrome.runtime && window.chrome.runtime.onConnect) {
            console.log('🚨 检测到Chrome扩展调试特征！');
            window._triggerInfiniteDebug('Chrome扩展调试特征检测');
            return true;
          }
          
          // 方法4: 检测DevTools特殊变量
          if (window.devtools && window.devtools.open) {
            console.log('🚨 检测到DevTools特殊变量！');
            window._triggerInfiniteDebug('DevTools特殊变量检测');
            return true;
          }
          
          return false;
        })()
      ''');
      
      // 简单的字符串检查来判断结果
      final isDevtoolsOpen = result.toString() == 'true';
      
      if (isDevtoolsOpen) {
        print('🚨 主检测循环检测到开发者工具！');
        // 这里不再调用_triggerInfiniteDebug，因为具体的检测方法已经调用了
      }
    } catch (e) {
      // 检测过程中的错误也可能表示有调试行为
      print('⚠️ 开发者工具检测异常: $e');
      try {
        jsEval('window._triggerInfiniteDebug && window._triggerInfiniteDebug("检测异常: ' + e.toString() + '")');
      } catch (e2) {
        print('🚨 触发异常Debug失败: $e2');
      }
    }
  }
  
  /// 触发无限debug（严重级别）
  static void _triggerInfiniteDebug() {
    if (!kIsWeb) return;
    
    print('🚨 无限Debug模式启动！');
    
    try {
      jsEval('window._triggerInfiniteDebug && window._triggerInfiniteDebug()');
    } catch (e) {
      print('🚨 触发无限Debug失败: $e');
    }
  }
  
  /// 停止所有检测
  static void dispose() {
    _devtoolsDetectionTimer?.cancel();
    _devtoolsDetectionTimer = null;
    _loadCheckTimer?.cancel();
    _loadCheckTimer = null;
    _isInitialized = false;
    _pageFullyLoaded = false;
    _initTime = null;
  }
}