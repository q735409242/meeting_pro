import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

/// 无障碍节点数据结构
class _AccessibilityNode {
  final String className;
  final String text;
  final String resourceId;
  final bool clickable;
  final bool editable;
  final bool focused;
  final double x, y, width, height;

  _AccessibilityNode({
    required this.className,
    required this.text,
    required this.resourceId,
    required this.clickable,
    required this.editable,
    required this.focused,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// 无障碍服务模块 - 负责页面读取、节点树处理等功能
mixin AccessibilityMixin<T extends StatefulWidget> on State<T> {
  // 节点相关变量
  List<_AccessibilityNode> _accessibilityNodes = [];
  String _lastAccessibilityTree = '';
  
  // 需要子类实现的抽象属性
  bool get isCaller;
  String? get channel;
  dynamic get signaling;
  bool get showNodeRects;
  set showNodeRects(bool value);
  bool get isManualRefresh;
  
  /// 切换显示节点树
  void changeShowNodeTree() async {
    if (channel == 'sdk') {
      // SDK模式暂时注释
    } else if (channel == 'cf') {
      if (isCaller) {
        setState(() {
          showNodeRects = !showNodeRects;
        });
        
        if (showNodeRects) {
          signaling?.sendCommand({'type': 'show_view'});
          await EasyLoading.showToast(
            '已开启页面读取',
            duration: const Duration(seconds: 2)
          );
        } else {
          await EasyLoading.showToast(
            '已关闭页面读取',
            duration: const Duration(seconds: 2)
          );
        }
      }
    }
  }
  
  /// 处理无障碍树数据
  void handleAccessibilityTree(String treeJson) {
    if (treeJson.isEmpty) {
      print('⚠️ 收到空的无障碍树数据');
      return;
    }
    
    try {
      _lastAccessibilityTree = treeJson;
      
      // 检查是否包含错误信息
      if (treeJson.startsWith('⚠️') && treeJson.contains('rootInActiveWindow')) {
        print('⚠️ 检测到rootInActiveWindow问题，准备重试...');
        EasyLoading.showToast(
          '对方无障碍服务正在恢复，请稍候...',
          duration: const Duration(seconds: 3)
        );
        
        // 延迟重新发送show_view命令
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && isCaller && showNodeRects) {
            signaling?.sendCommand({'type': 'show_view'});
            print('🔄 重新发送show_view命令');
          }
        });
        return;
      }
      
      // 解析JSON数据
      final dynamic jsonData = jsonDecode(treeJson);
      _accessibilityNodes.clear();
      
      if (jsonData is Map<String, dynamic>) {
        extractNodes(jsonData, _accessibilityNodes);
      } else if (jsonData is List) {
        for (var item in jsonData) {
          if (item is Map<String, dynamic>) {
            extractNodes(item, _accessibilityNodes);
          }
        }
      }
      
      print('📋 解析无障碍节点: ${_accessibilityNodes.length}个');
      printNodeTreeStats();
      
      setState(() {});
    } catch (e) {
      print('❌ 解析无障碍树失败: $e');
      print('🗂️ 原始数据: ${treeJson.length > 200 ? treeJson.substring(0, 200) + '...' : treeJson}');
    }
  }
  
  /// 处理无障碍树错误
  void handleAccessibilityTreeError(String error) {
    print('❌ 无障碍树错误: $error');
    
    // 检查是否是rootInActiveWindow或无障碍相关错误
    if (error.contains('rootInActiveWindow') || error.contains('无障碍')) {
      EasyLoading.showToast(
        '对方无障碍服务正在恢复，请稍候...',
        duration: const Duration(seconds: 3)
      );
      
      // 延迟重新发送show_view命令
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && isCaller && showNodeRects) {
          signaling?.sendCommand({'type': 'show_view'});
          print('🔄 错误恢复重新发送show_view命令');
        }
      });
    } else {
      EasyLoading.showError(
        '页面读取错误: $error',
        duration: const Duration(seconds: 3)
      );
    }
  }
  
  /// 恢复页面读取功能（ICE重连后）
  void restorePageReadingAfterReconnect() {
    if (!isCaller || !showNodeRects) return;
    
    print('🔄 ICE重连后恢复页面读取功能...');
    
    // 延迟3秒后恢复，确保Android端服务就绪
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      
      print('🔄 开始恢复页面读取...');
      
      // 再次延迟500ms发送第一次请求，给Android服务更多时间
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && isCaller && showNodeRects) {
          signaling?.sendCommand({'type': 'show_view'});
          print('🔄 ICE重连后发送show_view命令');
        }
      });
    });
  }
  
  /// 提取节点信息
  void extractNodes(dynamic node, List<_AccessibilityNode> list) {
    if (node is! Map<String, dynamic>) return;
    
    try {
      // 提取基本信息
      final className = node['className']?.toString() ?? '';
      final text = node['text']?.toString() ?? '';
      final resourceId = node['resourceId']?.toString() ?? '';
      final clickable = node['clickable'] == true;
      final editable = node['editable'] == true;
      final focused = node['focused'] == true;
      
      // 提取位置信息
      final bounds = node['bounds'];
      double x = 0, y = 0, width = 0, height = 0;
      
      if (bounds is Map<String, dynamic>) {
        x = (bounds['left'] ?? 0).toDouble();
        y = (bounds['top'] ?? 0).toDouble();
        width = ((bounds['right'] ?? 0) - x).toDouble();
        height = ((bounds['bottom'] ?? 0) - y).toDouble();
      }
      
      // 创建节点对象
      if (className.isNotEmpty || text.isNotEmpty || resourceId.isNotEmpty) {
        final accessibilityNode = _AccessibilityNode(
          className: className,
          text: text,
          resourceId: resourceId,
          clickable: clickable,
          editable: editable,
          focused: focused,
          x: x,
          y: y,
          width: width,
          height: height,
        );
        
        list.add(accessibilityNode);
      }
      
      // 递归处理子节点
      final children = node['children'];
      if (children is List) {
        for (var child in children) {
          extractNodes(child, list);
        }
      }
    } catch (e) {
      print('❌ 提取节点信息失败: $e');
    }
  }
  
  /// 打印节点树统计信息
  void printNodeTreeStats() {
    if (_accessibilityNodes.isEmpty) {
      print('📊 节点树统计: 无节点');
      return;
    }
    
    int clickableCount = 0;
    int editableCount = 0;
    int focusedCount = 0;
    int textNodeCount = 0;
    
    for (final node in _accessibilityNodes) {
      if (node.clickable) clickableCount++;
      if (node.editable) editableCount++;
      if (node.focused) focusedCount++;
      if (node.text.isNotEmpty) textNodeCount++;
    }
    
    print('📊 节点树统计:');
    print('   总节点数: ${_accessibilityNodes.length}');
    print('   可点击: $clickableCount');
    print('   可编辑: $editableCount');
    print('   已聚焦: $focusedCount');
    print('   含文本: $textNodeCount');
  }
  
  /// 获取当前节点列表
  List<_AccessibilityNode> get accessibilityNodes => _accessibilityNodes;
  
  /// 获取最后的无障碍树数据
  String get lastAccessibilityTree => _lastAccessibilityTree;
  
  /// 获取可点击节点
  List<_AccessibilityNode> getClickableNodes() {
    return _accessibilityNodes.where((node) => node.clickable).toList();
  }
  
  /// 获取可编辑节点
  List<_AccessibilityNode> getEditableNodes() {
    return _accessibilityNodes.where((node) => node.editable).toList();
  }
  
  /// 获取聚焦节点
  List<_AccessibilityNode> getFocusedNodes() {
    return _accessibilityNodes.where((node) => node.focused).toList();
  }
  
  /// 根据文本查找节点
  List<_AccessibilityNode> findNodesByText(String text) {
    return _accessibilityNodes
        .where((node) => node.text.contains(text))
        .toList();
  }
  
  /// 根据资源ID查找节点
  List<_AccessibilityNode> findNodesByResourceId(String resourceId) {
    return _accessibilityNodes
        .where((node) => node.resourceId.contains(resourceId))
        .toList();
  }
  
  /// 根据类名查找节点
  List<_AccessibilityNode> findNodesByClassName(String className) {
    return _accessibilityNodes
        .where((node) => node.className.contains(className))
        .toList();
  }
  
  /// 清理无障碍资源
  void disposeAccessibility() {
    _accessibilityNodes.clear();
    _lastAccessibilityTree = '';
  }
} 