//
//  FlutterDirectSampleBufferCapturer.h
//  flutter_webrtc
//
//  Created for direct sample buffer sharing.
//

#import <Foundation/Foundation.h>
#import <WebRTC/RTCVideoCapturer.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

@interface FlutterDirectSampleBufferCapturer : RTCVideoCapturer

/**
 * Initialize the capturer with a delegate.
 */
- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate;

/**
 * Process a new video frame from a CMSampleBuffer.
 */
- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END 