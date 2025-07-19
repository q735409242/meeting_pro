//
//  FlutterSampleBufferManager.h
//  flutter_webrtc
//
//  Created as a bridge between AppDelegate and WebRTC plugin.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import "FlutterDirectSampleBufferCapturer.h"

NS_ASSUME_NONNULL_BEGIN

@interface FlutterSampleBufferManager : NSObject

/**
 * Shared instance of the manager.
 */
+ (FlutterSampleBufferManager *)sharedInstance;

/**
 * Register a capturer to receive sample buffer updates.
 */
- (void)registerCapturer:(FlutterDirectSampleBufferCapturer *)capturer;

/**
 * Unregister a capturer.
 */
- (void)unregisterCapturer:(FlutterDirectSampleBufferCapturer *)capturer;

/**
 * Process a new sample buffer and distribute to registered capturers.
 */
- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END 