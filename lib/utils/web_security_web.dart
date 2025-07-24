/// Web平台的JavaScript实现
/// 使用dart:js_util来执行JavaScript代码

import 'dart:js_util' as js_util;

/// JavaScript eval函数的Web实现
dynamic jsEval(String code) {
  try {
    // 使用dart:js_util来执行JavaScript代码
    return js_util.callMethod(js_util.globalThis, 'eval', [code]);
  } catch (e) {
    print('JavaScript执行错误: $e');
    return null;
  }
}

/// JavaScript窗口对象的Web实现
dynamic get jsWindow {
  try {
    // 返回全局window对象
    return js_util.globalThis;
  } catch (e) {
    print('获取window对象错误: $e');
    return null;
  }
} 