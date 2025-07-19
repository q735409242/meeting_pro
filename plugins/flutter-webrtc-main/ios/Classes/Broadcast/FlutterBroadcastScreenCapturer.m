//
//  FlutterBroadcastScreenCapturer.m
//  RCTWebRTC
//
//  Created by Alex-Dan Bumbu on 06/01/2021.
//

#import "FlutterBroadcastScreenCapturer.h"
#import "FlutterDirectSampleBufferCapturer.h"
#import "FlutterSampleBufferManager.h"
#import <ReplayKit/ReplayKit.h>

NSString* const kRTCAppGroupIdentifier = @"RTCAppGroupIdentifier";
NSString* const kRTCScreenSharingExtension = @"RTCScreenSharingExtension";
NSString* const kRTCBroadcastStoppedNotification = @"RTCBroadcastStoppedNotification";
NSString* const kStopScreenNotification = @"StopScreen";

@interface FlutterBroadcastScreenCapturer ()

@property(nonatomic, retain) FlutterDirectSampleBufferCapturer* capturer;

@end

@implementation FlutterBroadcastScreenCapturer

- (void)startCapture {
    FlutterDirectSampleBufferCapturer* capturer = 
        [[FlutterDirectSampleBufferCapturer alloc] initWithDelegate:self.delegate];
    self.capturer = capturer;
    
    // Register the capturer with the shared manager
    [[FlutterSampleBufferManager sharedInstance] registerCapturer:capturer];
    
    NSLog(@"FlutterBroadcastScreenCapturer: Started direct capture");
}

- (void)stopCapture {
    if (self.capturer) {
        [[FlutterSampleBufferManager sharedInstance] unregisterCapturer:self.capturer];
        self.capturer = nil;
        NSLog(@"FlutterBroadcastScreenCapturer: Stopped direct capture");
        
        // Send notification to stop broadcast
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                           (CFStringRef)kStopScreenNotification,
                                           NULL,
                                           NULL,
                                           true);
    }
}

- (void)stopCaptureWithCompletionHandler:(nullable void (^)(void))completionHandler {
    [self stopCapture];
    if (completionHandler != nil) {
        completionHandler();
    }
}

@end
