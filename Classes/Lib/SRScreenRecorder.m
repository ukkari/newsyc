//
//  SRScreenRecorder.m
//  ScreenRecorder
//
//  Created by kishikawa katsumi on 2012/12/26.
//  Copyright (c) 2012年 kishikawa katsumi. All rights reserved.
//

#import <sys/xattr.h>
#import "SRScreenRecorder.h"
#import "KTouchPointerWindow.h"
#import "IOSurface.h"
#import "IOMobileFrameBuffer.h"
#ifndef APPSTORE_SAFE
#if DEBUG
#define APPSTORE_SAFE 0
#else
#define APPSTORE_SAFE 1
#endif
#endif

#define DEFAULT_FRAME_INTERVAL 0
#define TIME_SCALE 600

static NSInteger counter;

#if !APPSTORE_SAFE
CGImageRef UICreateCGImageFromIOSurface(CFTypeRef surface);
CVReturn CVPixelBufferCreateWithIOSurface(
                                          CFAllocatorRef allocator,
                                          CFTypeRef surface,
                                          CFDictionaryRef pixelBufferAttributes,
                                          CVPixelBufferRef *pixelBufferOut);
@interface UIWindow (ScreenRecorder)
+ (CFTypeRef)createScreenIOSurface;
@end

@interface UIScreen (ScreenRecorder)
- (CGRect)_boundsInPixels;
@end
#endif

@interface SRScreenRecorder ()

@property (strong, nonatomic) AVAssetWriter *writer;
@property (strong, nonatomic) AVAssetWriterInput *writerInput;
@property (strong, nonatomic) AVAssetWriterInput *audioWriterInput;
@property (strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor *writerInputPixelBufferAdaptor;
@property (strong, nonatomic) CADisplayLink *displayLink;
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureAudioDataOutput *audioOutput;


@end

@implementation SRScreenRecorder {
	CFAbsoluteTime firstFrameTime;
    CFTimeInterval startTimestamp;
    BOOL shouldRestart;
    
    dispatch_queue_t queue;
    dispatch_queue_t queue2;

    UIBackgroundTaskIdentifier backgroundTask;
    
    uint32_t m_width, m_height;
    
    
}

+ (SRScreenRecorder *)sharedInstance
{
    static SRScreenRecorder *sharedInstance = nil;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        sharedInstance = [[SRScreenRecorder alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        _showsTouchPointer = YES;
        _isRecording = NO;
        counter++;
        _taskId = nil;
        _frameInterval = DEFAULT_FRAME_INTERVAL;
        NSString *label = [NSString stringWithFormat:@"com.kishikawakatsumi.screen_recorder-%d", counter];
        queue = dispatch_queue_create([label cStringUsingEncoding:NSUTF8StringEncoding], NULL);
        queue2 = dispatch_queue_create("test", DISPATCH_QUEUE_SERIAL);
        [self setupAudioDevice];
        [self setupNotifications];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopRecordingWithCompletionHandler:^(NSURL *url) {
        ;
    }];
}

#pragma mark Setup

- (void)setupAssetWriterWithURL:(NSURL *)outputURL
{
    NSError *error = nil;
    
    self.writer = [[AVAssetWriter alloc] initWithURL:outputURL fileType:AVFileTypeQuickTimeMovie error:&error];
    NSParameterAssert(self.writer);
    if (error) {
        NSLog(@"Error: %@", [error localizedDescription]);
    }
    
    UIScreen *mainScreen = [UIScreen mainScreen];
#if APPSTORE_SAFE
    CGSize size = mainScreen.bounds.size;
#else
    CGRect boundsInPixels = [mainScreen _boundsInPixels];
    CGSize size = boundsInPixels.size;
#endif
    
    NSDictionary *outputSettings = @{AVVideoCodecKey : AVVideoCodecH264, AVVideoWidthKey : @(size.width), AVVideoHeightKey : @(size.height)};
    self.writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSettings];
	self.writerInput.expectsMediaDataInRealTime = YES;
    
    NSDictionary *sourcePixelBufferAttributes = @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32ARGB)};
    self.writerInputPixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.writerInput
                                                                                                          sourcePixelBufferAttributes:sourcePixelBufferAttributes];
    NSParameterAssert(self.writerInput);
    NSParameterAssert([self.writer canAddInput:self.writerInput]);
    [self.writer addInput:self.writerInput];
    
    //Audio
    // Add the audio input
    AudioChannelLayout acl;
    bzero( &acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
    
    NSDictionary* audioOutputSettings = nil;
        // should work from iphone 3GS on and from ipod 3rd generation
    audioOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                               [ NSNumber numberWithInt: kAudioFormatMPEG4AAC ], AVFormatIDKey,
                               [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,
                               [ NSNumber numberWithFloat: 44100.0 ], AVSampleRateKey,
                               [ NSNumber numberWithInt: 64000 ], AVEncoderBitRateKey,
                               [ NSData dataWithBytes: &acl length: sizeof( acl ) ], AVChannelLayoutKey,
                               nil];
    /*
    audioOutputSettings = [ NSDictionary dictionaryWithObjectsAndKeys:
                           [ NSNumber numberWithInt: kAudioFormatAppleLossless ], AVFormatIDKey,
                           [ NSNumber numberWithInt: 16 ], AVEncoderBitDepthHintKey,
                           [ NSNumber numberWithFloat: 44100.0 ], AVSampleRateKey,
                           [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,
                           [ NSData dataWithBytes: &acl length: sizeof( acl ) ], AVChannelLayoutKey,
                           nil ];
*/
    
    self.audioWriterInput = [AVAssetWriterInput
                          assetWriterInputWithMediaType: AVMediaTypeAudio
                          outputSettings: audioOutputSettings ];
    
    self.audioWriterInput.expectsMediaDataInRealTime = YES;
    NSParameterAssert(self.audioWriterInput);
    NSParameterAssert([self.writer canAddInput:self.audioWriterInput]);
    [self.writer addInput:self.audioWriterInput];

	firstFrameTime = CFAbsoluteTimeGetCurrent();
    
    [self.writer startWriting];
    [self.writer startSessionAtSourceTime:kCMTimeZero];
}

- (void)setupTouchPointer
{
    if (self.showsTouchPointer) {
        KTouchPointerWindowInstall();
    } else {
        KTouchPointerWindowUninstall();
    }
}

- (void)setupNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void) setupAudioDevice{
    NSError *error = nil;
    // Setup the audio input
    AVCaptureDevice *audioDevice     = [AVCaptureDevice defaultDeviceWithMediaType: AVMediaTypeAudio];
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error ];
    // Setup the audio output
    _audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    
    _captureSession = [[AVCaptureSession alloc] init];
    if( [_captureSession canAddInput:audioInput])[_captureSession addInput:audioInput];
    if( [_captureSession canAddOutput:_audioOutput])[_captureSession addOutput:_audioOutput];
    _captureSession.sessionPreset = AVCaptureSessionPresetLow;
    
    // Setup the queue
    //dispatch_queue_t queue2 = dispatch_queue_create("MyQueue", DISPATCH_QUEUE_SERIAL);
        [_audioOutput setSampleBufferDelegate:self queue:queue2];
    //dispatch_release(queue2);
}



- (void)setupTimer
{
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(captureShot:)];
    self.displayLink.frameInterval = self.frameInterval;
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}


#pragma mark Recording

- (void)startRecording
{
    if(!_isRecording){
        [self setupAssetWriterWithURL:[self outputFileURL]];
    
        [self setupTouchPointer];
    
        [self setupTimer];
        [_captureSession startRunning];
        _isRecording = YES;
    }
}

- (void)startRecording:(NSString*)taskId{
    [self startRecording];
    _taskId = taskId;
}

- (NSURL *)stopRecording
{
    __block NSURL *url = nil;
    __block BOOL finished = NO;
    if(_isRecording){
        NSLog(@"stopRecording");
        [_captureSession stopRunning];
        _isRecording = NO;
        _showsTouchPointer = NO;
        [self setupTouchPointer];
        [self stopRecordingWithCompletionHandler:^(NSURL *saveUrl) {
            url = saveUrl;
            finished = YES;
        }];
    
        while (!finished) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        }
    }
    return url;
}

- (void)stopRecordingWithCompletionHandler:(void (^)(NSURL *saveUrl))completionHandler
{
    [self.displayLink invalidate];
    startTimestamp = 0.0;
    NSLog(@"stopRecordingWithCompletionHandler");
    dispatch_async(queue, ^
                   {
                       NSURL *url = self.writer.outputURL;
                       if (self.writer.status != AVAssetWriterStatusCompleted && self.writer.status != AVAssetWriterStatusUnknown) {
                           [self.writerInput markAsFinished];
                           [self.audioWriterInput markAsFinished];
                       }
                       if ([self.writer respondsToSelector:@selector(finishWritingWithCompletionHandler:)]) {
                           [self.writer finishWritingWithCompletionHandler:^
                            {
                                [self finishBackgroundTask];
                                [self restartRecordingIfNeeded];
                                completionHandler(url);
                            }];
                       } else {
                           [self.writer finishWriting];
                           
                           [self finishBackgroundTask];
                           [self restartRecordingIfNeeded];
                           completionHandler(url);
                       }
                   });
    
    [self limitNumberOfFiles];
}

- (void)restartRecordingIfNeeded
{
    if (shouldRestart) {
        shouldRestart = NO;
        dispatch_async(queue, ^
                       {
                           dispatch_async(dispatch_get_main_queue(), ^
                                          {
                                              [self startRecording];
                                          });
                       });
    }
}

- (void)rotateFile
{
    shouldRestart = YES;
    dispatch_async(queue, ^
                   {
                       [self stopRecordingWithCompletionHandler:^(NSURL *url) {
                           ;
                       }];
                   });
}

/*
 * Method for recording Audio
 */

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
   
    if( !CMSampleBufferDataIsReady(sampleBuffer) )
    {
        NSLog( @"sample buffer is not ready. Skipping sample" );
        return;
    }else{
        
    }
    if( _isRecording == YES )
    {
        //NSLog(@"should be recorded");
        if( self.writer.status > AVAssetWriterStatusWriting )
        {
            NSLog(@"Warning: writer status is %d", self.writer.status);
            if( self.writer.status == AVAssetWriterStatusFailed )
                NSLog(@"Error: %@", self.writer.error);
            return;
        }

        CMSampleBufferRef newSampleBuffer = [self adjustTiming:sampleBuffer];
        
        if( [_audioWriterInput appendSampleBuffer:newSampleBuffer] ){
            //NSLog(@"Successfully append new sample buffer");
            CFRelease(newSampleBuffer);
        }else{
            NSLog(@"Unable to write to audio input");
        }

    }else{
        NSLog(@"is not recorded");
        return;
    }

}

/*
 * Method for recording Video
 * Mostly copied from http://stackoverflow.com/questions/14135215/iosurfaces-artefacts-in-video-and-unable-to-grab-video-surfaces?lq=1
 */

- (void)captureShot:(CMTime)frameTime
{
    dispatch_async(queue, ^
                   {
    CVPixelBufferRef buffer = NULL;
    IOMobileFramebufferConnection connect;
    kern_return_t result;
    IOSurfaceRef screenSurface = NULL;
    
    io_service_t framebufferService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleH1CLCD"));
    if(!framebufferService)
        framebufferService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleM2CLCD"));
    if(!framebufferService)
        framebufferService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleCLCD"));
    
    result = IOMobileFramebufferOpen(framebufferService, mach_task_self(), 0, &connect);
    
    result = IOMobileFramebufferGetLayerDefaultSurface(connect, 0, &screenSurface);
    
    uint32_t aseed;
    IOSurfaceLock(screenSurface, kIOSurfaceLockReadOnly, &aseed);
    uint32_t width = IOSurfaceGetWidth(screenSurface);
    uint32_t height = IOSurfaceGetHeight(screenSurface);
    m_width = width;
    m_height = height;
    CFMutableDictionaryRef dict;
    int pitch = width*4, size = width*height*4;
    int bPE=4;
    char pixelFormat[4] = {'A','R','G','B'};
    dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(dict, kIOSurfaceIsGlobal, kCFBooleanTrue);
    CFDictionarySetValue(dict, kIOSurfaceBytesPerRow, CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &pitch));
    CFDictionarySetValue(dict, kIOSurfaceBytesPerElement, CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bPE));
    CFDictionarySetValue(dict, kIOSurfaceWidth, CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &width));
    CFDictionarySetValue(dict, kIOSurfaceHeight, CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &height));
    CFDictionarySetValue(dict, kIOSurfacePixelFormat, CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, pixelFormat));
    CFDictionarySetValue(dict, kIOSurfaceAllocSize, CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &size));
    
    IOSurfaceRef destSurf = IOSurfaceCreate(dict);
    
    IOSurfaceAcceleratorRef outAcc;
    IOSurfaceAcceleratorCreate(NULL, 0, &outAcc);
    
    IOSurfaceAcceleratorTransferSurface(outAcc, screenSurface, destSurf, dict, NULL);
    
    IOSurfaceUnlock(screenSurface, kIOSurfaceLockReadOnly, &aseed);
    CFRelease(outAcc);
    
    // MOST RELEVANT PART OF CODE
    
    CVPixelBufferCreateWithBytes(NULL, width, height, kCVPixelFormatType_32BGRA, IOSurfaceGetBaseAddress(destSurf), IOSurfaceGetBytesPerRow(destSurf), NULL, NULL, NULL, &buffer);
    
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    CFTimeInterval elapsedTime = currentTime - firstFrameTime;
    
    CMTime presentTime =  CMTimeMake(elapsedTime * TIME_SCALE, TIME_SCALE);
    
    [self.writerInputPixelBufferAdaptor appendPixelBuffer:buffer withPresentationTime:presentTime];
    
    CFRelease(buffer);
    CFRelease(destSurf);
                   });
}

/*
 * Adjust timing of the video
 */

- (CMSampleBufferRef)adjustTiming:(CMSampleBufferRef)sampleBuffer{
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    CFTimeInterval elapsedTime = currentTime - firstFrameTime;
    
    CMTime presentTime =  CMTimeMake(elapsedTime * TIME_SCALE, TIME_SCALE);
    NSLog(@"presentTime:%f", CMTimeGetSeconds(presentTime));
    CMSampleBufferRef newSampleBuffer;
    CMSampleTimingInfo sampleTimingInfo;
    sampleTimingInfo.duration = CMTimeMake(1 * TIME_SCALE, TIME_SCALE);
    sampleTimingInfo.presentationTimeStamp = presentTime;
    sampleTimingInfo.decodeTimeStamp = kCMTimeInvalid;
    
    CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault,
                                          sampleBuffer,
                                          1,
                                          &sampleTimingInfo,
                                          &newSampleBuffer);
    
    return newSampleBuffer;
}

#pragma mark Background tasks

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    UIApplication *application = [UIApplication sharedApplication];
    
    UIDevice *device = [UIDevice currentDevice];
    BOOL backgroundSupported = NO;
    if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
        backgroundSupported = device.multitaskingSupported;
    }
    
    if (backgroundSupported) {
        backgroundTask = [application beginBackgroundTaskWithExpirationHandler:^{
            [self finishBackgroundTask];
        }];
    }
    
    if(_isRecording)[self stopRecordingWithCompletionHandler:^(NSURL *url) {
        ;
    }];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self finishBackgroundTask];
    [self startRecording];
}

- (void)finishBackgroundTask
{
    if (backgroundTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
        backgroundTask = UIBackgroundTaskInvalid;
    }
}

#pragma mark Utility methods

- (NSString *)documentDirectory
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	return documentsDirectory;
}

- (NSString *)defaultFilename
{
    time_t timer;
    time(&timer);
    NSString *timestamp = [NSString stringWithFormat:@"%ld", timer];
    return timestamp;
}

- (BOOL)existsFile:(NSString *)filename
{
    NSString *path = [[self directoryPathForSave] stringByAppendingPathComponent:filename];
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    BOOL isDirectory;
    return [fileManager fileExistsAtPath:path isDirectory:&isDirectory] && !isDirectory;
}

- (NSString *)nextFilename:(NSString *)filename
{
    static NSInteger fileCounter;
    
    fileCounter++;
    NSString *pathExtension = [filename pathExtension];
    filename = [[[filename stringByDeletingPathExtension] stringByAppendingString:[NSString stringWithFormat:@"-%d", fileCounter]] stringByAppendingPathExtension:pathExtension];
    
    if ([self existsFile:filename]) {
        return [self nextFilename:filename];
    }
    
    return filename;
}

- (NSURL *)outputFileURL
{    
    if (!self.filenameBlock) {
        __block SRScreenRecorder *wself = self;
        self.filenameBlock = ^(void) {
            return [wself defaultFilename];
        };
    }
    
    NSString *filename = self.filenameBlock();
    filename = [filename stringByAppendingPathExtension:@"mov"];
    if ([self existsFile:filename]) {
        filename = [self nextFilename:filename];
    }
    
    NSString *path = [[self directoryPathForSave] stringByAppendingPathComponent:filename];
    return [NSURL fileURLWithPath:path];
}

- (NSString *)directoryPathForSave
{
    NSString *path = nil;
    if (self.directoryPath.length > 0) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:self.directoryPath]) {
            BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:self.directoryPath
                                                     withIntermediateDirectories:YES
                                                                      attributes:nil
                                                                           error:nil];
            if (success) {
                [self addSkipBackupAttributeAtPath:self.directoryPath];
                path = self.directoryPath;
            }
        } else {
            path = self.directoryPath;
        }
    }
    if (!path) {
        path = self.documentDirectory;
    }
    return path;
}

- (BOOL)addSkipBackupAttributeAtPath:(NSString *)path
{
    if ([[[UIDevice currentDevice] systemVersion] compare:@"5.0.1" options:NSNumericSearch] != NSOrderedDescending) {
        // iOS <= 5.0.1
        const char *filePath = [path fileSystemRepresentation];
        const char *attrName = "com.apple.MobileBackup";
        u_int8_t attrValue = 1;
        
        int result = setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
        return result == 0;
    } else {
        // iOS >= 5.1
        NSURL *URL = [NSURL fileURLWithPath:path];
        BOOL result = [URL setResourceValue:[NSNumber numberWithBool:YES]
                                     forKey:@"NSURLIsExcludedFromBackupKey"
                                      error:nil];
        return result;
    }
}

- (void)limitNumberOfFiles
{
    if (self.maxNumberOfFiles == 0) {
        return;
    }
    
    NSString *dirPath = [self directoryPathForSave];
    NSError *error = nil;
    NSArray *list = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self directoryPathForSave] error:&error];
    if (!error) {
        NSMutableArray *attributes = [NSMutableArray array];
        for (NSString *file in list) {
            NSMutableDictionary *dic = [NSMutableDictionary dictionary];
            NSString *filePath = [dirPath stringByAppendingPathComponent:file];
            NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
            if ([[filePath pathExtension] isEqualToString:@"mov"] && [attr objectForKey:NSFileType] == NSFileTypeRegular) {
                [dic setDictionary:attr];
                [dic setObject:filePath forKey:@"FilePath"];
                [attributes addObject:dic];
            }
        }
        
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:NSFileCreationDate ascending:YES];
        NSArray *descArray = [NSArray arrayWithObject:sortDescriptor];
        NSArray *sortedArray = [attributes sortedArrayUsingDescriptors:descArray];
        
        if (sortedArray.count > self.maxNumberOfFiles) {
            for (int i = 0; i < sortedArray.count - self.maxNumberOfFiles; i++) {
                [[NSFileManager defaultManager] removeItemAtPath:attributes[i][@"FilePath"] error:nil];
            }
        }
    }
}

@end
