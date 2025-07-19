//
//  SampleHandler.swift
//  ScreenCapture
//
//  Created by Rover on 2025/5/13.
//

import ReplayKit
import JWExtensionKit

class SampleHandler: RPBroadcastSampleHandler {

    // 标记是否需要结束广播
    private static var isFinished = false
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
        print("🎥 Broadcast started with setup info: \(String(describing: setupInfo))")
        FIAgoraSampleHandlerSocketManager.shared().setUpSocket()
        
        // 注册停止通知
        let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        let notificationName = "StopScreen" as CFString
        
        // 添加观察者
        CFNotificationCenterAddObserver(
            notificationCenter,
            nil,
            { (_, _, _, _, _) in
                // 收到通知时，设置结束标志
                SampleHandler.isFinished = true
            },
            notificationName,
            nil,
            CFNotificationSuspensionBehavior.deliverImmediately
        )
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
        print("⏸️ Broadcast paused")
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
        print("▶️ Broadcast resumed")
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast.
        print("🏁 Broadcast finished")
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            // 处理视频样本缓冲区
            sendData(sampleBuffer: sampleBuffer)
            break
        case RPSampleBufferType.audioApp:
            // Handle audio sample buffer for app audio
            print("🔊 Processing app audio buffer")
            break
        case RPSampleBufferType.audioMic:
            // Handle audio sample buffer for mic audio
            print("🎤 Processing mic audio buffer")
            break
        @unknown default:
            // Handle other sample buffer types
            print("⚠️ Unknown sample buffer type")
            fatalError("Unknown type of sample buffer")
        }
    }
    
    // 发送数据并检查是否需要结束广播
    private func sendData(sampleBuffer: CMSampleBuffer) {
        if SampleHandler.isFinished {
            // 创建错误对象
            let error = NSError(
                domain: String(describing: type(of: self)),
                code: 0,
                userInfo: [NSLocalizedFailureReasonErrorKey: "屏幕共享已结束"]
            )
            
            // 释放socket
            FIAgoraSampleHandlerSocketManager.shared().socketDelloc()
            
            // 结束广播
            finishBroadcastWithError(error)
        } else {
            // 发送视频数据
            FIAgoraSampleHandlerSocketManager.shared().sendVideoBuffer(toHostApp: sampleBuffer)
        }
    }
}
