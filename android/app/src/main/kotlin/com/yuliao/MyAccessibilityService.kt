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
     * 返回当前界面的节点树（以 JSON 形式）
     */
    fun dumpNodeTree(): String {
        val root = rootInActiveWindow ?: return "⚠️ 无 rootInActiveWindow"
        return buildNodeJson(root).toString(2) // 缩进2的JSON字符串
    }

    // 递归构建节点信息
    private fun buildNodeJson(node: AccessibilityNodeInfo): JSONObject {
        val obj = JSONObject()
//        obj.put("className", node.className)
        obj.put("text", node.text)
        obj.put("contentDescription", node.contentDescription)
        obj.put("editable", node.isEditable)
//        obj.put("clickable", node.isClickable)
//        obj.put("enabled", node.isEnabled)
//        obj.put("focused", node.isFocused)
//        obj.put("scrollable", node.isScrollable)

        val rect = Rect()
        node.getBoundsInScreen(rect)
        obj.put("bounds", rect.flattenToString())

        val children = JSONArray()
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let {
                children.put(buildNodeJson(it))
            }
        }
        obj.put("children", children)
        return obj
    }
}