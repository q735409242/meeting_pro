package com.meeting.pro

import android.util.Log
import android.os.PowerManager
import android.content.Context
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.PointF
import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import org.json.JSONObject
import com.google.android.marvin.talkback.TalkBackService

class MainActivity : FlutterActivity() {
    private val gestureChannel = "com.meeting.pro.gestueChannel"
    private val wakelockChannel = "wakelock_service"
    private val brightnessChannel = "brightness_channel" // ✅ 新增亮度控制通道

            private val swipePoints = mutableListOf<PointF>()
        
        // 计算滑动路径的总距离
        private fun calculatePathDistance(points: List<PointF>): Float {
            if (points.size < 2) return 0f
            var totalDistance = 0f
            for (i in 1 until points.size) {
                val dx = points[i].x - points[i-1].x
                val dy = points[i].y - points[i-1].y
                totalDistance += kotlin.math.sqrt(dx * dx + dy * dy)
            }
            return totalDistance
        }

    // wakelock 相关
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // =============== 无障碍节点树通道 ===============
        val accessibilityChannel = "accessibility_channel"
        Log.i("MainActivity", ">>> Setting up accessibility channel $accessibilityChannel")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, accessibilityChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "dumpAccessibilityTree" -> {
                        val svc = TalkBackService.instance
                        if (svc != null) {
                            val tree = svc.dumpNodeTree()
                            result.success(tree)
                        } else {
                            result.error("NO_SERVICE", "AccessibilityService not running", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // =============== 手势控制通道 ===============
        Log.i("MainActivity", ">>> Setting up gesture channel $gestureChannel")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, gestureChannel)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "handleMessage" -> {
                        Log.i("MainActivity", "handleMessage received")
                        val msg = call.argument<String>("message") ?: ""
                        val json = JSONObject(msg)
                        val type = json.getString("type")

                        val svc = TalkBackService.instance
                        if (svc == null) {
                            Log.e("MainActivity", "AccessibilityService.instance is null, cannot perform gesture")
                        } else {
                            when (type) {
                                "tap" -> {
                                    val x = json.getDouble("x").toFloat()
                                    val y = json.getDouble("y").toFloat()
                                    Log.i("MainActivity", "AccessibilityService ready, performing $type at x=$x y=$y")
                                    svc.performClick(x, y)
                                }
                                "swipStart" -> {
                                    val x = json.getDouble("x").toFloat()
                                    val y = json.getDouble("y").toFloat()
                                    Log.i("MainActivity", "🖱️ 开始滑动: ($x, $y)")
                                    swipePoints.clear()
                                    swipePoints.add(PointF(x, y))
                                }
                                "swipMove" -> {
                                    val x = json.getDouble("x").toFloat()
                                    val y = json.getDouble("y").toFloat()
                                    swipePoints.add(PointF(x, y))
                                    
                                    // 智能路径点管理：长距离滑动允许更多点，短距离滑动保持精简
                                    val maxPoints = if (swipePoints.size > 2) {
                                        val currentDistance = calculatePathDistance(swipePoints)
                                        when {
                                            currentDistance > 800 -> 100  // 长距离滑动允许100个点
                                            currentDistance > 400 -> 75   // 中距离滑动允许75个点  
                                            else -> 50                    // 短距离滑动保持50个点
                                        }
                                    } else 50
                                    
                                    // 当点数超过限制时，智能删除中间点而不是开头点
                                    if (swipePoints.size > maxPoints) {
                                        // 删除中间的点，保留开始和最近的点
                                        val toRemove = swipePoints.size - maxPoints
                                        repeat(toRemove) {
                                            // 删除中间部分的点，保持起点和终点区域的精度
                                            val removeIndex = swipePoints.size / 3
                                            if (removeIndex > 0 && removeIndex < swipePoints.size - 1) {
                                                swipePoints.removeAt(removeIndex)
                                            }
                                        }
                                    }
                                }
                                "swipEnd" -> {
                                    val x = json.getDouble("x").toFloat()
                                    val y = json.getDouble("y").toFloat()
                                    swipePoints.add(PointF(x, y))
                                    Log.i("MainActivity", "🖱️ 结束滑动: ($x, $y), 路径点数: ${swipePoints.size}")
                                    
                                    if (swipePoints.size >= 2) {
                                        val path = Path().apply {
                                            moveTo(swipePoints[0].x, swipePoints[0].y)
                                            swipePoints.drop(1).forEach { p -> lineTo(p.x, p.y) }
                                        }
                                        
                                        // 优化长距离滑动的时长计算
                                        val totalDistance = calculatePathDistance(swipePoints)
                                        val duration = when {
                                            totalDistance <= 100 -> 150L      // 很短距离：150ms
                                            totalDistance <= 300 -> 250L      // 短距离：250ms  
                                            totalDistance <= 600 -> 400L      // 中距离：400ms
                                            totalDistance <= 1000 -> 600L     // 长距离：600ms
                                            totalDistance <= 1500 -> 800L     // 很长距离：800ms
                                            else -> 1000L                     // 超长距离：1000ms
                                        }
                                        
                                        Log.i("MainActivity", "🖱️ 滑动距离: ${totalDistance.toInt()}px, 时长: ${duration}ms, 点数: ${swipePoints.size}")
                                        
                                        val stroke = GestureDescription.StrokeDescription(path, 0, duration)
                                        val gesture = GestureDescription.Builder().apply { addStroke(stroke) }.build()
                                        svc.dispatchGesture(gesture, null, null)
                                    }
                                }
                                "tapBack" -> {
                                    Log.i("MainActivity", "AccessibilityService ready, performing $type")
                                    svc.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
                                }
                                "tapHome" -> {
                                    Log.i("MainActivity", "AccessibilityService ready, performing $type")
                                    svc.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
                                }
                                "tapRecent" -> {
                                    Log.i("MainActivity", "AccessibilityService ready, performing $type")
                                    svc.performGlobalAction(AccessibilityService.GLOBAL_ACTION_RECENTS)
                                }
                                "longPress" -> {
                                    val x = json.getDouble("x").toFloat()
                                    val y = json.getDouble("y").toFloat()
                                    Log.i("MainActivity", "🖱️ 长按开始: ($x, $y)")
                                    svc.performLongPress(x, y)
                                }
                                "longPressEnd" -> {
                                    val x = json.getDouble("x").toFloat()
                                    val y = json.getDouble("y").toFloat()
                                    Log.i("MainActivity", "🖱️ 长按结束: ($x, $y)")
                                    // 长按结束通常不需要特殊处理，但可以记录日志
                                }
                                "key_input" -> {
                                    val inputText = json.getString("text")
                                    Log.i("MainActivity", "Keyboard input received: $inputText")
                                    svc.inputText(inputText)
                                }

                                else -> Log.w("MainActivity", "Unknown gesture type: $type")
                            }
                        }
                        result.success(null)
                    }
                    "remoteControlEnable" -> {
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // =============== Wakelock 控制通道 ===============
        Log.i("MainActivity", ">>> Setting up wakelock channel $wakelockChannel")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, wakelockChannel)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "acquire" -> {
                        acquireWakeLock()
                        result.success(null)
                    }
                    "release" -> {
                        releaseWakeLock()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // =============== 亮度控制通道 ===============
        Log.i("MainActivity", ">>> Setting up brightness channel $brightnessChannel")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, brightnessChannel)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "setAutoBrightnessEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        try {
                            Settings.System.putInt(
                                contentResolver,
                                Settings.System.SCREEN_BRIGHTNESS_MODE,
                                if (enabled) Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC else Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
                            )
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("AUTO_BRIGHTNESS_ERROR", e.message, null)
                        }
                    }
                    "hasWriteSettingsPermission" -> {
                        val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Settings.System.canWrite(this)
                        } else {
                            true
                        }
                        result.success(hasPermission)
                    }
                    "openWriteSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS)
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
                        }
                        result.success(null)
                    }
                    "isAutoBrightnessEnabled" -> {
                        val isEnabled = try {
                            Settings.System.getInt(
                                contentResolver,
                                Settings.System.SCREEN_BRIGHTNESS_MODE
                            ) == Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
                        } catch (e: Exception) {
                            false
                        }
                        result.success(isEnabled)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ==================== wakelock 操作 ====================
    private fun acquireWakeLock() {
        if (wakeLock == null) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_DIM_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                                    "MeetingProApp::WakeLockTag"
            )
        }
        if (wakeLock?.isHeld == false) {
            wakeLock?.acquire()
            Log.i("MainActivity", "WakeLock acquired")
        }
    }

    private fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
            wakeLock = null
            Log.i("MainActivity", "WakeLock released")
        }
    }
}