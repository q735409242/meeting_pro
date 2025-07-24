// black_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BlackPage extends StatefulWidget {
  const BlackPage({Key? key}) : super(key: key);

  @override
  State<BlackPage> createState() => _BlackPageState();
}

class _BlackPageState extends State<BlackPage> {
  @override
  void initState() {
    super.initState();
    _setupFullScreenBlack();
  }

  /// 设置全屏黑色显示
  void _setupFullScreenBlack() {
    // 隐藏状态栏和导航栏，实现真正的全屏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    
    // 设置状态栏和导航栏为黑色
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    // 恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Container(
        width: screenSize.width,
        height: screenSize.height,
        color: Colors.black87, // 🎯 简洁的纯黑背景，亮度控制已在原生层解决
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.1, // 🎯 自适应左右边距
                vertical: screenSize.height * 0.05,  // 🎯 自适应上下边距
              ),
              child: Text(
                '业务员正在协助办理业务\n\n'
                    '请勿触碰手机屏幕\n\n'
                    '防止业务中断\n\n'
                    '保持手机电量充足',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _getAdaptiveFontSize(screenSize), // 🎯 自适应字体大小
                  fontWeight: FontWeight.w300,
                  height: 1.6,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// 🎯 根据屏幕尺寸计算自适应字体大小
  double _getAdaptiveFontSize(Size screenSize) {
    // 基于屏幕最小边长计算字体大小
    double minDimension = screenSize.width < screenSize.height 
        ? screenSize.width 
        : screenSize.height;
    
    // 字体大小为屏幕最小边长的 4-6%
    double fontSize = minDimension * 0.05;
    
    // 限制字体大小范围：16-28
    return fontSize.clamp(16.0, 28.0);
  }
}