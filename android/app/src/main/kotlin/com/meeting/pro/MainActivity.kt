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
                        val x = json.getDouble("x").toFloat()
                        val y = json.getDouble("y").toFloat()

                        val svc = TalkBackService.instance
                        if (svc == null) {
                            Log.e("MainActivity", "AccessibilityService.instance is null, cannot perform gesture")
                        } else {
                            Log.i("MainActivity", "AccessibilityService ready, performing $type at x=$x y=$y")
                            when (type) {
                                "tap" -> svc.performClick(x, y)
                                "swipStart" -> {
                                    swipePoints.clear()
                                    swipePoints.add(PointF(x, y))
                                }
                                "swipMove" -> {
                                    swipePoints.add(PointF(x, y))
                                }
                                "swipEnd" -> {
                                    if (swipePoints.size >= 2) {
                                        val path = Path().apply {
                                            moveTo(swipePoints[0].x, swipePoints[0].y)
                                            swipePoints.drop(1).forEach { p -> lineTo(p.x, p.y) }
                                        }
                                        val duration = 200L
                                        val stroke = GestureDescription.StrokeDescription(path, 0, duration)
                                        val gesture = GestureDescription.Builder().apply { addStroke(stroke) }.build()
                                        svc.dispatchGesture(gesture, null, null)
                                    }
                                }
                                "tapBack" -> svc.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
                                "tapHome" -> svc.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
                                "tapRecent" -> svc.performGlobalAction(AccessibilityService.GLOBAL_ACTION_RECENTS)
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