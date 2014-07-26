//
//  SRScreenRecorder.h
//  ScreenRecorder
//
//  Created by kishikawa katsumi on 2012/12/26.
//  Copyright (c) 2012年 kishikawa katsumi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <TargetConditionals.h>

typedef NSString *(^SRScreenRecorderOutputFilenameBlock)();

@interface SRScreenRecorder : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate>
@property (assign, nonatomic) NSInteger frameInterval;
@property (assign, nonatomic) BOOL showsTouchPointer;
@property (copy, nonatomic) SRScreenRecorderOutputFilenameBlock filenameBlock;
@property (copy, nonatomic) NSString *directoryPath;
@property (assign, nonatomic) NSUInteger maxNumberOfFiles;
@property (nonatomic) BOOL isRecording;
@property (strong, nonatomic) NSString* taskId;

+ (SRScreenRecorder *)sharedInstance;
- (void)startRecording;
- (void)startRecording:(NSString*)taskId;
- (NSURL *)stopRecording;

@end
