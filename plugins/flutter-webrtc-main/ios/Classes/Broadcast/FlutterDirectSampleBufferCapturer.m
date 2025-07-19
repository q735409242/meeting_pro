//
//  FlutterDirectSampleBufferCapturer.m
//  flutter_webrtc
//
//  Created for direct sample buffer sharing.
//

#include <mach/mach_time.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

#import <WebRTC/RTCCVPixelBuffer.h>
#import <WebRTC/RTCVideoFrameBuffer.h>

#import "FlutterDirectSampleBufferCapturer.h"

@implementation FlutterDirectSampleBufferCapturer {
    mach_timebase_info_data_t _timebaseInfo;
    int64_t _startTimeStampNs;
}

- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate {
    self = [super initWithDelegate:delegate];
    if (self) {
        mach_timebase_info(&_timebaseInfo);
        _startTimeStampNs = -1;
    }
    return self;
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!sampleBuffer) {
        return;
    }
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pixelBuffer) {
        return;
    }
    
    // Get video orientation
    int orientation = 0; // Default to portrait (0 degrees)
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    if (formatDescription) {
        // For now, we'll use a default orientation
        // The actual orientation will be handled by the video frame rotation
        orientation = kCGImagePropertyOrientationUp;
    }
    
    [self didCaptureVideoFrame:pixelBuffer withOrientation:orientation];
}

#pragma mark - Private Methods

- (void)didCaptureVideoFrame:(CVPixelBufferRef)pixelBuffer
             withOrientation:(CGImagePropertyOrientation)orientation {
    int64_t currentTime = mach_absolute_time();
    int64_t currentTimeStampNs = currentTime * _timebaseInfo.numer / _timebaseInfo.denom;
    
    if (_startTimeStampNs < 0) {
        _startTimeStampNs = currentTimeStampNs;
    }
    
    RTCCVPixelBuffer* rtcPixelBuffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer:pixelBuffer];
    int64_t frameTimeStampNs = currentTimeStampNs - _startTimeStampNs;
    
    RTCVideoRotation rotation;
    switch (orientation) {
        case kCGImagePropertyOrientationLeft:
            rotation = RTCVideoRotation_90;
            break;
        case kCGImagePropertyOrientationDown:
            rotation = RTCVideoRotation_180;
            break;
        case kCGImagePropertyOrientationRight:
            rotation = RTCVideoRotation_270;
            break;
        default:
            rotation = RTCVideoRotation_0;
            break;
    }
    
    RTCVideoFrame* videoFrame = [[RTCVideoFrame alloc] initWithBuffer:[rtcPixelBuffer toI420]
                                                          rotation:rotation
                                                       timeStampNs:frameTimeStampNs];
    
    [self.delegate capturer:self didCaptureVideoFrame:videoFrame];
}

@end 