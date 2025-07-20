package com.yuliao
import android.util.Log
import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject
import android.graphics.Rect
import android.os.Build
import android.os.Bundle

class MyAccessibilityService : AccessibilityService() {
    companion object {
        // 在 Service 连接时保存实例
        var instance: MyAccessibilityService? = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i("MyAccessibilityService","Service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 不用处理系统事件
//        if (event?.eventType == AccessibilityEvent.TYPE_VIEW_FOCUSED) {
//            val node = event.source ?: return
//            // 只有当节点可以编辑时才输入
//            if (node.isEditable) {
//                // 兼容方案：使用 ACTION_SET_TEXT（Android 5.0+）
//                val args = Bundle().apply {
//                    putCharSequence(
//                        AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
//                        "123456"
//                    )
//                }
//                val ok = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
//                Log.i("MyAccessibilityService", "✅ ACTION_SET_TEXT 模拟输入 123456 成功？ $ok")
//            }
//        }
    }

    override fun onInterrupt() {
        // Service 被中断（不常用）
    }

    /**
     * 在 (x,y) 点模拟一次点击。
     * 注意：坐标要用屏幕坐标，单位是像素。
     */
    fun performClick(x: Float, y: Float) {
        val path = Path().apply {
            moveTo(x, y)
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
            .build()
        dispatchGesture(gesture, null, null)
    }

    /**
     * 如果要模拟滑动，可以传一系列点：
     */
    fun performSwipe(startX: Float, startY: Float, endX: Float, endY: Float, duration: Long = 300L) {
        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(endX, endY)
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, duration))
            .build()
        dispatchGesture(gesture, null, null)
    }

    /**
     * 返回当前界面的节点树（以 JSON 形式）- 安全版本
     */
    fun dumpNodeTree(): String {
        return try {
            val root = rootInActiveWindow ?: return "⚠️ 无 rootInActiveWindow"
            
            // 添加安全检查和限制（已优化）
            val startTime = System.currentTimeMillis()
            val maxProcessingTime = 5000L // 最大处理时间5秒（增加）
            val maxDepth = 15 // 最大递归深度15层（增加）
            val maxNodes = 1000 // 最大节点数量1000个（增加）
            
            val nodeCount = IntArray(1) // 使用数组传递引用
            nodeCount[0] = 0
            
            val result = buildNodeJsonSafe(root, 0, maxDepth, maxNodes, nodeCount, startTime, maxProcessingTime)
            Log.i("MyAccessibilityService", "成功生成节点树，总节点数量: ${nodeCount[0]}, JSON大小: ${result.toString().length} 字符")
            result.toString(0) // 不格式化，减少内存占用
        } catch (e: Exception) {
            Log.e("MyAccessibilityService", "生成节点树失败: ${e.message}", e)
            "⚠️ 节点树生成失败: ${e.message}"
        }
    }

    // 安全的递归构建节点信息
    private fun buildNodeJsonSafe(
        node: AccessibilityNodeInfo,
        currentDepth: Int,
        maxDepth: Int,
        maxNodes: Int,
        nodeCount: IntArray,
        startTime: Long,
        maxProcessingTime: Long
    ): JSONObject {
        val obj = JSONObject()
        
        // 检查超时
        if (System.currentTimeMillis() - startTime > maxProcessingTime) {
            obj.put("error", "处理超时")
            return obj
        }
        
        // 检查节点数量限制
        if (nodeCount[0] >= maxNodes) {
            obj.put("error", "节点数量超限")
            return obj
        }
        
        nodeCount[0]++
        
        try {
            // 安全获取节点信息
            val text = node.text?.toString()?.take(100) ?: "" // 限制文本长度
            val desc = node.contentDescription?.toString()?.take(100) ?: "" // 限制描述长度
            
            obj.put("text", text)
            obj.put("contentDescription", desc)
            obj.put("editable", node.isEditable)
            obj.put("clickable", node.isClickable)
            obj.put("enabled", node.isEnabled)

            val rect = Rect()
            node.getBoundsInScreen(rect)
            obj.put("bounds", rect.flattenToString())

            // 只有在深度允许的节点才继续递归（进一步优化）
            if (currentDepth < maxDepth && node.childCount > 0) { // 移除子节点数量限制
                val children = JSONArray()
                for (i in 0 until node.childCount) { // 处理所有子节点
                    try {
                        val child = node.getChild(i)
                        if (child != null) {
                            children.put(buildNodeJsonSafe(child, currentDepth + 1, maxDepth, maxNodes, nodeCount, startTime, maxProcessingTime))
                            child.recycle() // 重要：释放节点引用
                        }
                    } catch (e: Exception) {
                        Log.w("MyAccessibilityService", "处理子节点失败: ${e.message}")
                        // 继续处理其他子节点
                    }
                }
                obj.put("children", children)
            }
        } catch (e: Exception) {
            Log.w("MyAccessibilityService", "处理节点信息失败: ${e.message}")
            obj.put("error", "节点信息获取失败")
        }
        
        return obj
    }
}