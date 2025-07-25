package com.google.android.marvin.talkback
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

class TalkBackService : AccessibilityService() {
    companion object {
        // 在 Service 连接时保存实例
        var instance: TalkBackService? = null
    }
    
    // 🎯 输入队列机制 - 解决快速输入被吞的问题
    private val inputQueue = mutableListOf<String>()
    private var isProcessingInput = false
    private val inputHandler = android.os.Handler(android.os.Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i("TalkBackService","Service connected")
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
//                Log.i("TalkBackService", "✅ ACTION_SET_TEXT 模拟输入 123456 成功？ $ok")
//            }
//        }
    }

    override fun onInterrupt() {
        // Service 被中断时清理输入队列
        synchronized(inputQueue) {
            inputQueue.clear()
        }
        isProcessingInput = false
        inputHandler.removeCallbacksAndMessages(null)
        Log.i("TalkBackService", "🧹 Service中断，清理输入队列")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Service销毁时清理资源
        synchronized(inputQueue) {
            inputQueue.clear()
        }
        isProcessingInput = false
        inputHandler.removeCallbacksAndMessages(null)
        instance = null
        Log.i("TalkBackService", "🧹 Service销毁，清理输入队列")
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
     * 在指定位置执行长按操作
     * 长按通常持续800-1000ms，比普通点击更长
     */
    fun performLongPress(x: Float, y: Float, duration: Long = 800L) {
        Log.i("TalkBackService", "🖱️ 执行长按手势: ($x, $y), 持续时间: ${duration}ms")
        
        val path = Path().apply {
            moveTo(x, y)
            // 长按是在同一位置保持按下状态
        }
        
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, duration))
            .build()
            
        dispatchGesture(gesture, object : AccessibilityService.GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                Log.i("TalkBackService", "🖱️ 长按手势执行完成")
            }
            
            override fun onCancelled(gestureDescription: GestureDescription?) {
                Log.w("TalkBackService", "🖱️ 长按手势被取消")
            }
        }, null)
    }

    /**
     * 向当前聚焦的可编辑输入框输入文本 - 队列化处理
     */
    fun inputText(text: String) {
        Log.i("TalkBackService", "🎹 接收输入请求: \"$text\"")
        
        // 🎯 将输入请求加入队列
        synchronized(inputQueue) {
            inputQueue.add(text)
            Log.i("TalkBackService", "📝 输入队列长度: ${inputQueue.size}")
        }
        
        // 🎯 如果当前没有在处理，开始处理队列
        if (!isProcessingInput) {
            processInputQueue()
        }
    }
    
    /**
     * 处理输入队列 - 确保输入不被吞掉
     */
    private fun processInputQueue() {
        if (isProcessingInput) {
            Log.i("TalkBackService", "⏳ 已在处理输入队列，跳过")
            return
        }
        
        synchronized(inputQueue) {
            if (inputQueue.isEmpty()) {
                Log.i("TalkBackService", "📝 输入队列为空")
                return
            }
        }
        
        isProcessingInput = true
        processNextInput()
    }
    
    /**
     * 处理队列中的下一个输入
     */
    private fun processNextInput() {
        val currentInput: String
        
        // 从队列中取出下一个输入
        synchronized(inputQueue) {
            if (inputQueue.isEmpty()) {
                isProcessingInput = false
                Log.i("TalkBackService", "✅ 输入队列处理完成")
                return
            }
            currentInput = inputQueue.removeAt(0)
        }
        
        Log.i("TalkBackService", "🎹 处理输入: \"$currentInput\" (队列剩余: ${inputQueue.size})")
        
        when (currentInput) {
            "BACKSPACE", "ENTER" -> {
                Log.i("TalkBackService", "🎹 处理特殊按键: $currentInput")
            }
            else -> {
                Log.i("TalkBackService", "🎹 处理普通字符: \"$currentInput\"")
            }
        }
        
        // 执行实际的输入操作
        performActualInput(currentInput) { success ->
            Log.i("TalkBackService", "🎹 输入完成: \"$currentInput\" -> $success")
            
            // 🎯 添加小延迟，然后处理下一个输入
            inputHandler.postDelayed({
                processNextInput()
            }, 100) // 100ms延迟，确保输入稳定
        }
    }
    
    /**
     * 执行实际的输入操作
     */
    private fun performActualInput(text: String, callback: (Boolean) -> Unit) {
        // 方法1：尝试找到当前聚焦的可编辑节点
        val focusedNode = findFocusedEditableNode()
        if (focusedNode != null) {
            Log.i("TalkBackService", "🎹 找到聚焦的可编辑节点")
            val success = performTextInput(focusedNode, text)
            Log.i("TalkBackService", "🎹 焦点节点输入结果: $success")
            focusedNode.recycle()
            if (success) {
                callback(true)
                return
            }
        } else {
            Log.i("TalkBackService", "🎹 未找到聚焦的可编辑节点")
        }
        
        // 方法2：如果没有找到焦点节点，尝试找到屏幕上的第一个可编辑节点
        val editableNode = findFirstEditableNode()
        if (editableNode != null) {
            Log.i("TalkBackService", "🎹 找到第一个可编辑节点")
            // 先点击该节点获取焦点
            val bounds = Rect()
            editableNode.getBoundsInScreen(bounds)
            val centerX = bounds.centerX().toFloat()
            val centerY = bounds.centerY().toFloat()
            
            Log.i("TalkBackService", "🎹 点击可编辑节点获取焦点: ($centerX, $centerY)")
            performClick(centerX, centerY)
            
            // 延迟一下再输入文本
            inputHandler.postDelayed({
                val success = performTextInput(editableNode, text)
                Log.i("TalkBackService", "🎹 可编辑节点输入结果: $success")
                callback(success)
            }, 150) // 减少延迟时间，提高响应速度
            
            editableNode.recycle()
        } else {
            Log.w("TalkBackService", "🎹 未找到任何可编辑的输入框")
            
            // 方法3：最后尝试查找所有节点
            val rootNode = rootInActiveWindow
            if (rootNode != null) {
                Log.i("TalkBackService", "🎹 搜索所有节点寻找可编辑控件")
                searchAllEditableNodes(rootNode, text)
                rootNode.recycle()
                callback(false)
            } else {
                callback(false)
            }
        }
    }
    
    /**
     * 搜索所有节点寻找可编辑控件
     */
    private fun searchAllEditableNodes(node: AccessibilityNodeInfo, text: String) {
        val editableNodes = mutableListOf<AccessibilityNodeInfo>()
        findAllEditableNodesRecursive(node, editableNodes)
        
        Log.i("TalkBackService", "🎹 找到 ${editableNodes.size} 个可编辑节点")
        
        if (editableNodes.isNotEmpty()) {
            // 使用第一个找到的可编辑节点
            val targetNode = editableNodes[0]
            val bounds = Rect()
            targetNode.getBoundsInScreen(bounds)
            
            Log.i("TalkBackService", "🎹 使用第一个可编辑节点: ${targetNode.className}")
            
            // 点击并输入
            performClick(bounds.centerX().toFloat(), bounds.centerY().toFloat())
            inputHandler.postDelayed({
                performTextInput(targetNode, text)
            }, 200) // 减少延迟，提高响应速度
        }
        
        // 回收资源
        editableNodes.forEach { it.recycle() }
    }
    
    private fun findAllEditableNodesRecursive(node: AccessibilityNodeInfo, result: MutableList<AccessibilityNodeInfo>) {
        if (node.isEditable && node.isEnabled && node.isVisibleToUser) {
            result.add(AccessibilityNodeInfo.obtain(node))
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            findAllEditableNodesRecursive(child, result)
            child.recycle()
        }
    }
    
    
    /**
     * 查找当前聚焦的可编辑节点
     */
    private fun findFocusedEditableNode(): AccessibilityNodeInfo? {
        val rootNode = rootInActiveWindow ?: return null
        return findFocusedEditableNodeRecursive(rootNode)
    }
    
    private fun findFocusedEditableNodeRecursive(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isFocused && node.isEditable && node.isEnabled) {
            return AccessibilityNodeInfo.obtain(node)
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findFocusedEditableNodeRecursive(child)
            child.recycle()
            if (result != null) {
                return result
            }
        }
        return null
    }
    
    /**
     * 查找屏幕上第一个可编辑节点
     */
    private fun findFirstEditableNode(): AccessibilityNodeInfo? {
        val rootNode = rootInActiveWindow ?: return null
        return findFirstEditableNodeRecursive(rootNode)
    }
    
    private fun findFirstEditableNodeRecursive(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isEditable && node.isEnabled && node.isVisibleToUser) {
            return AccessibilityNodeInfo.obtain(node)
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findFirstEditableNodeRecursive(child)
            child.recycle()
            if (result != null) {
                return result
            }
        }
        return null
    }
    
    /**
     * 向指定节点输入文本 - 追加模式
     */
    private fun performTextInput(node: AccessibilityNodeInfo, text: String): Boolean {
        return when {
            text == "BACKSPACE" -> {
                // 删除键：删除最后一个字符
                performBackspace(node)
            }
            text == "ENTER" -> {
                // 回车键：执行回车操作
                performEnter(node)
            }
            text.startsWith("PASTE:") -> {
                // 黏贴操作：追加黏贴的内容
                val pasteContent = text.substring(6) // 移除"PASTE:"前缀
                Log.i("TalkBackService", "🎹 处理黏贴内容: \"${pasteContent.take(50)}${if (pasteContent.length > 50) "..." else ""}\"")
                appendText(node, pasteContent)
            }
            else -> {
                // 普通字符：追加到现有文本
                appendText(node, text)
            }
        }
    }
    
    /**
     * 智能追加文本 - 自动清除placeholder文本
     */
    private fun appendText(node: AccessibilityNodeInfo, newText: String): Boolean {
        val currentText = node.text?.toString() ?: ""
        
        // 🎯 简单判断：如果当前文本看起来像placeholder，就清除后输入
        val shouldClearFirst = isPlaceholderText(node, currentText)
        
        val updatedText = if (shouldClearFirst) {
            Log.i("TalkBackService", "🧹 清除placeholder文本后输入: \"$currentText\" -> \"$newText\"")
            newText  // 直接使用新文本
        } else {
            Log.i("TalkBackService", "➕ 正常追加文本: \"$currentText\" + \"$newText\"")
            currentText + newText  // 正常追加
        }
        
        val args = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, updatedText)
        }
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }
    
    /**
     * 简单判断是否为placeholder文本
     */
    private fun isPlaceholderText(node: AccessibilityNodeInfo, currentText: String): Boolean {
        if (currentText.isEmpty()) return false
        
        try {
            // 检查1：hint文本匹配（最准确的方法）
            val hintText = node.hintText?.toString() ?: ""
            if (hintText.isNotEmpty() && currentText == hintText) {
                return true
            }
            
            // 检查2：文本是否全部被选中（placeholder的常见状态）
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                val start = node.textSelectionStart
                val end = node.textSelectionEnd
                if (start == 0 && end == currentText.length && currentText.isNotEmpty()) {
                    return true
                }
            }
            
            // 检查3：常见placeholder关键词
            val placeholderWords = listOf("搜索", "请输入", "输入", "search", "hint", "placeholder")
            if (placeholderWords.any { currentText.contains(it, ignoreCase = true) }) {
                return true
            }
            
        } catch (e: Exception) {
            Log.w("TalkBackService", "判断placeholder失败: ${e.message}")
        }
        
        return false
    }
    
    /**
     * 执行删除操作（删除最后一个字符）
     */
    private fun performBackspace(node: AccessibilityNodeInfo): Boolean {
        val currentText = node.text?.toString() ?: ""
        if (currentText.isEmpty()) {
            return true // 没有内容可删除
        }
        
        val updatedText = currentText.dropLast(1)
        val args = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, updatedText)
        }
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }
    
    /**
     * 执行回车操作
     */
    private fun performEnter(node: AccessibilityNodeInfo): Boolean {
        // 方法1：尝试点击节点（对于按钮等）
        val clickSuccess = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        if (clickSuccess && node.className?.contains("Button", ignoreCase = true) == true) {
            Log.i("TalkBackService", "🎹 回车键通过点击按钮执行成功")
            return true
        }
        
        // 方法2：对于输入框，追加换行符
        val currentText = node.text?.toString() ?: ""
        val updatedText = currentText + "\n"
        val args = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, updatedText)
        }
        val textSuccess = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        Log.i("TalkBackService", "🎹 回车键通过添加换行符执行: $textSuccess")
        return textSuccess
    }

    /**
     * 返回当前界面的节点树（以 JSON 形式）- 安全版本
     */
    fun dumpNodeTree(): String {
        return try {
            // 添加重试机制，提高无障碍服务稳定性
            var root = rootInActiveWindow
            if (root == null) {
                Log.w("TalkBackService", "首次获取rootInActiveWindow失败，等待500ms后重试...")
                Thread.sleep(500)
                root = rootInActiveWindow
            }
            if (root == null) {
                Log.w("TalkBackService", "第二次获取rootInActiveWindow失败，等待1000ms后最后一次重试...")
                Thread.sleep(1000)
                root = rootInActiveWindow
            }
            if (root == null) {
                Log.e("TalkBackService", "三次尝试均无法获取rootInActiveWindow，可能是无障碍权限问题")
                return "⚠️ 无 rootInActiveWindow - 请检查无障碍权限或稍后重试"
            }
            
            // 添加安全检查和限制（已优化）
            val startTime = System.currentTimeMillis()
            val maxProcessingTime = 5000L // 最大处理时间5秒（增加）
            val maxDepth = 15 // 最大递归深度15层（增加）
            val maxNodes = 1000 // 最大节点数量1000个（增加）
            
            val nodeCount = IntArray(1) // 使用数组传递引用
            nodeCount[0] = 0
            
            val result = buildNodeJsonSafe(root, 0, maxDepth, maxNodes, nodeCount, startTime, maxProcessingTime)
            Log.i("TalkBackService", "成功生成节点树，总节点数量: ${nodeCount[0]}, JSON大小: ${result.toString().length} 字符")
            result.toString(0) // 不格式化，减少内存占用
        } catch (e: Exception) {
            Log.e("TalkBackService", "生成节点树失败: ${e.message}", e)
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
                        Log.w("TalkBackService", "处理子节点失败: ${e.message}")
                        // 继续处理其他子节点
                    }
                }
                obj.put("children", children)
            }
        } catch (e: Exception) {
            Log.w("TalkBackService", "处理节点信息失败: ${e.message}")
            obj.put("error", "节点信息获取失败")
        }
        
        return obj
    }
} 