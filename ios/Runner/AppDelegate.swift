import Flutter
import ReplayKit
import UIKit
import JWExtensionKit
import CallKit

// 导入FlutterSampleBufferManager
// Swift和Objective-C桥接
@objc protocol FlutterSampleBufferManagerProtocol {
    func processSampleBuffer(_ sampleBuffer: CMSampleBuffer?)
}

@main
@objc class AppDelegate: FlutterAppDelegate {

    // FlutterSampleBufferManager的引用
    private var sampleBufferManager: FlutterSampleBufferManagerProtocol?
    let callObserver = CXCallObserver()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 在低电量模式下,系统只会强制保持屏幕亮30秒
        // 我们保持屏幕常亮以帮助内部测试
        application.isIdleTimerDisabled = true
        FIAgoraClientBufferSocketManager.shared().setupSocket()        // 添加前后台切换通知监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        let controller = window?.rootViewController as! FlutterViewController

        let screensharingIOSChannel = FlutterMethodChannel(name: "example_screensharing_ios", binaryMessenger: controller.binaryMessenger)

        screensharingIOSChannel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "showRPSystemBroadcastPickerView":
                self?.showRPSystemBroadcastPickerView()
                result(nil)
            case "suspendApp":
                DispatchQueue.main.async {
                    UIApplication.shared.perform(Selector(("suspend")))
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        let callStatusChannel = FlutterMethodChannel(name: "call_status_channel", binaryMessenger: controller.binaryMessenger)
        callStatusChannel.setMethodCallHandler { [weak self] call, result in
            if call.method == "isInCall" {
                let calls = self?.callObserver.calls ?? []
                let isInCall = calls.contains { !$0.hasEnded }
                result(isInCall)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        // 获取FlutterSampleBufferManager
        if let sampleBufferManagerClass = NSClassFromString("FlutterSampleBufferManager") as? NSObject.Type,
           let manager = sampleBufferManagerClass.perform(NSSelectorFromString("sharedInstance"))?.takeUnretainedValue() as? FlutterSampleBufferManagerProtocol {
            sampleBufferManager = manager
            NSLog("FlutterSampleBufferManager successfully initialized")
        }
        
        FIAgoraClientBufferSocketManager.shared().testBlock = { [weak self] testText, sampleBuffer in
            self?.processSampleBuffer(sampleBuffer)
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // Process and send sample buffer to Flutter
    private func processSampleBuffer(_ sampleBuffer: CMSampleBuffer?) {
        guard let sampleBuffer = sampleBuffer else {
            return
        }
        // 将样本缓冲区传递给FlutterSampleBufferManager
        FlutterSampleBufferManager.sharedInstance().processSampleBuffer(sampleBuffer)
    }
    
    // 即将进入前台
    @objc private func willEnterForeground() {
        FJDeepSleepPreventerPlus.sharedInstance().stop()
    }
    
    // 进入后台
    @objc private func didEnterBackground() {
        FJDeepSleepPreventerPlus.sharedInstance().start()
    }
    
    // 这个原生方法会弹出屏幕录制选项框，方便用户选择
    private func showRPSystemBroadcastPickerView() {
        if #available(iOS 12.0, *) {
            DispatchQueue.main.async {
                if let url = Bundle.main.url(forResource: nil, withExtension: "appex", subdirectory: "PlugIns"),
                   let bundle = Bundle(url: url)
                {
                    let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
                    picker.showsMicrophoneButton = true
                    picker.preferredExtension = bundle.bundleIdentifier
                    for view in picker.subviews {
                        if let button = view as? UIButton {
                            button.sendActions(for: .allTouchEvents)
                        }
                    }
                }
            }
        }
    }
}
