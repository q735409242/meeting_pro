package com.example.my_phone_blocker;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.telecom.TelecomManager;
import android.telephony.PhoneStateListener;
import android.telephony.TelephonyManager;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * MyPhoneBlockerPlugin
 *
 * Android V2 embedding 实现，按需注册电话状态监听，拦截来电并挂断
 */
public class MyPhoneBlockerPlugin implements
        FlutterPlugin,
        MethodCallHandler,
        ActivityAware {

  private MethodChannel channel;
  private Context context;
  private TelephonyManager telephonyManager;
  private PhoneStateListener phoneStateListener;
  private boolean interceptEnable = false;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    // 保存 Context 并设置 MethodChannel
    context = binding.getApplicationContext();
    channel = new MethodChannel(binding.getBinaryMessenger(), "my_phone_blocker");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "hangupCall":
        Boolean enable = call.argument("interceptEnable");
        interceptEnable = (enable != null && enable);
        if (interceptEnable) {
          // 检查权限后再注册监听
          if (ActivityCompat.checkSelfPermission(
                  context,
                  Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED) {
            startListening();
            result.success(true);
          } else {
            result.error("NO_PERMISSION", "READ_PHONE_STATE 未授权，无法拦截", null);
          }
        } else {
          // 关闭拦截
          stopListening();
          result.success(true);
        }
        break;
      default:
        result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    stopListening();
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    // 如果需要 Activity，可通过 binding.getActivity() 获取
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() { }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) { }

  @Override
  public void onDetachedFromActivity() { }

  /**
   * 注册电话状态监听
   */
  private void startListening() {
    if (telephonyManager == null) {
      telephonyManager = (TelephonyManager)
              context.getSystemService(Context.TELEPHONY_SERVICE);
      phoneStateListener = new PhoneStateListener() {
        @Override
        public void onCallStateChanged(int state, String phoneNumber) {
          super.onCallStateChanged(state, phoneNumber);
          // 来电响铃时挂断
          if (interceptEnable && state == TelephonyManager.CALL_STATE_RINGING) {
            TelecomManager tm = (TelecomManager)
                    context.getSystemService(Context.TELECOM_SERVICE);
            if (tm != null && ActivityCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ANSWER_PHONE_CALLS) == PackageManager.PERMISSION_GRANTED) {
              tm.endCall();
            }
          }
        }
      };
    }
    telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE);
  }

  /**
   * 注销电话状态监听
   */
  private void stopListening() {
    if (telephonyManager != null && phoneStateListener != null) {
      telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE);
    }
  }
}
