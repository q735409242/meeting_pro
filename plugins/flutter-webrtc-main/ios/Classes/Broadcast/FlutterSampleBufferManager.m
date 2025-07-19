//
//  FlutterSampleBufferManager.m
//  flutter_webrtc
//
//  Created as a bridge between AppDelegate and WebRTC plugin.
//

#import "FlutterSampleBufferManager.h"

@interface FlutterSampleBufferManager ()

@property (nonatomic, strong) NSMutableArray<FlutterDirectSampleBufferCapturer *> *registeredCapturers;
@property (nonatomic, strong) dispatch_queue_t processingQueue;

@end

@implementation FlutterSampleBufferManager

+ (FlutterSampleBufferManager *)sharedInstance {
    static FlutterSampleBufferManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FlutterSampleBufferManager alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _registeredCapturers = [NSMutableArray array];
        _processingQueue = dispatch_queue_create("FlutterSampleBufferManagerQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)registerCapturer:(FlutterDirectSampleBufferCapturer *)capturer {
    dispatch_async(self.processingQueue, ^{
        if (![self.registeredCapturers containsObject:capturer]) {
            [self.registeredCapturers addObject:capturer];
            NSLog(@"Registered screen capturer, total capturers: %lu", (unsigned long)self.registeredCapturers.count);
        }
    });
}

- (void)unregisterCapturer:(FlutterDirectSampleBufferCapturer *)capturer {
    dispatch_async(self.processingQueue, ^{
        if ([self.registeredCapturers containsObject:capturer]) {
            [self.registeredCapturers removeObject:capturer];
            NSLog(@"Unregistered screen capturer, remaining capturers: %lu", (unsigned long)self.registeredCapturers.count);
        }
    });
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    // Make a copy of the sample buffer if needed
    if (!sampleBuffer) {
        return;
    }
    
    CFRetain(sampleBuffer);
    
    dispatch_async(self.processingQueue, ^{
        for (FlutterDirectSampleBufferCapturer *capturer in self.registeredCapturers) {
            [capturer processSampleBuffer:sampleBuffer];
        }
        
        CFRelease(sampleBuffer);
    });
}

@end 