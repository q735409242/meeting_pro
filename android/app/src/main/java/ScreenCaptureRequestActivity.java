//// android/app/src/main/java/com/meeting/pro/ScreenCaptureRequestActivity.java
//
//import android.app.Activity;
//import com.ss.bytertc.engine.flutter.screencapture.BaseScreenCaptureRequestActivity;
//import com.meeting.pro.R;
//import com.meeting.pro.MainActivity;
//
//public class ScreenCaptureRequestActivity
//        extends BaseScreenCaptureRequestActivity {
//
//    @Override
//    public int getLargeIcon() {
//        return R.mipmap.ic_launcher;
//    }
//
//    @Override
//    public int getSmallIcon() {
//        return R.mipmap.ic_launcher;
//    }
//
//    @Override
//    public Class<? extends Activity> getLaunchActivity() {
//        return MainActivity.class;
//    }
//
//    @Override
//    public String getContextText() {
//        return "正在进行屏幕共享";
//    }
//}