/// 非Web平台的stub实现
/// 在非Web平台上，JavaScript相关功能不可用

/// JavaScript eval函数的stub实现
dynamic jsEval(String code) {
  // 非Web平台不支持JavaScript
  throw UnsupportedError('JavaScript evaluation is only supported on web platform');
}

/// JavaScript窗口对象的stub实现
dynamic get jsWindow {
  // 非Web平台不支持JavaScript
  throw UnsupportedError('JavaScript window object is only supported on web platform');
} 