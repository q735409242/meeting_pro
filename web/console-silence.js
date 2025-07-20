/**
 * 云助通Web端控制台静默脚本
 * 完全禁用所有控制台输出，提供清洁的生产环境体验
 */

(function() {
  'use strict';
  
  // 检测是否为开发环境
  const isDev = location.hostname === 'localhost' || 
                location.hostname === '127.0.0.1' ||
                location.protocol === 'file:';
  
  // 生产环境：完全静默所有控制台输出
  if (!isDev) {
    // 保存原始方法（以防需要恢复）
    const originalMethods = {
      log: console.log,
      info: console.info,
      warn: console.warn,
      error: console.error,
      debug: console.debug,
      trace: console.trace,
      group: console.group,
      groupCollapsed: console.groupCollapsed,
      groupEnd: console.groupEnd,
      table: console.table,
      time: console.time,
      timeEnd: console.timeEnd,
      count: console.count,
      assert: console.assert
    };
    
    // 静默函数 - 什么都不做
    const silentFn = function() {};
    
    // 覆盖所有console方法
    console.log = silentFn;
    console.info = silentFn;
    console.warn = silentFn;
    console.error = silentFn;
    console.debug = silentFn;
    console.trace = silentFn;
    console.group = silentFn;
    console.groupCollapsed = silentFn;
    console.groupEnd = silentFn;
    console.table = silentFn;
    console.time = silentFn;
    console.timeEnd = silentFn;
    console.count = silentFn;
    console.assert = silentFn;
    
    // 如果需要在特殊情况下恢复console（调试用）
    window.__restoreConsole = function() {
      Object.assign(console, originalMethods);
    };
    
    // 禁用console的属性定义，防止被覆盖
    Object.defineProperty(window, 'console', {
      value: console,
      writable: false,
      configurable: false
    });
    
    // 静默window.onerror
    window.onerror = function(msg, url, line, col, error) {
      // 静默处理错误，不显示任何信息
      return true; // 阻止默认错误处理
    };
    
    // 静默unhandledrejection
    window.addEventListener('unhandledrejection', function(event) {
      // 静默处理Promise拒绝
      event.preventDefault();
    });
    
    // 静默警告
    window.addEventListener('error', function(event) {
      // 静默处理错误事件
      event.preventDefault();
    });
  }
  
  // 添加全局标识，表示静默模式已启用
  window.__consoleSilenced = !isDev;
  
})(); 