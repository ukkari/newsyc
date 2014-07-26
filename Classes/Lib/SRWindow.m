//
//  SRWindow.m
//  ScreenRecorder
//
//  Created by Ukai Yu on 2014/07/20.
//  Copyright (c) 2014年 kishikawa katsumi. All rights reserved.
//

#import "SRWindow.h"

@interface SRWindow()

@end

@implementation SRWindow

+ (SRWindow *)sharedInstance:(NSString*)appId
{
    static SRWindow *sharedInstance = nil;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        [Parse setApplicationId:@"CxxRDbr5yFX9LswUINcSNrKPb14VBkV7xFBhubJp"
                      clientKey:@"M4PiNcLYtFALuKrEE1EhiFiKRCVGtzl1TyDY0wxA"];
        
        sharedInstance = [[SRWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [sharedInstance setMakeKeyAndVisibleAfterDelay];
        [sharedInstance setAppId:appId];
    });
    return sharedInstance;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
       /*
        NSLog(@"window.frame %@",NSStringFromCGRect(self.bounds));
        CGRect rect = self.frame;
        rect.origin.y = self.frame.size.height/3 * 2;
        //rect.size.height = self.frame.size.height/3;
        self.frame = rect;
        NSLog(@"window.frame %@",NSStringFromCGRect(self.bounds));
        */
        self.windowLevel = UIWindowLevelNormal + 1;
        self.userInteractionEnabled = NO;
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"SRStoryboard" bundle:nil];
        UIViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"SRViewController"];
        self.rootViewController = viewController;
        self.rootViewController.view.hidden = YES;
        //[self makeKeyWindow];
    }
    return self;
}

- (void)setAppId:(NSString *)appId{
    _appId = appId;
}

- (void)setMakeKeyAndVisibleAfterDelay{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self makeKeyAndVisible];
        NSLog(@"window.frame %@",NSStringFromCGRect(self.bounds));
    });
}

// シェイク開始
- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (event.type == UIEventTypeMotion && event.subtype == UIEventSubtypeMotionShake)  {
        
        NSLog(@"Motion began");
    }
}

// シェイク完了
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (event.type == UIEventTypeMotion && event.subtype == UIEventSubtypeMotionShake) {
        if ([self.rootViewController respondsToSelector:@selector(updateView)]){
            //self.hidden = !self.hidden;
            [(SRViewController*)(self.rootViewController) updateView];
        }
        NSLog(@"Motion ended");
    }
}

// シェイクがキャンセルされた
- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (event.type == UIEventTypeMotion && event.subtype == UIEventSubtypeMotionShake) {
        NSLog(@"Motion cancelled");
    }
}


@end
