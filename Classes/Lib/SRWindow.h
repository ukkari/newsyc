//
//  SRWindow.h
//  ScreenRecorder
//
//  Created by Ukai Yu on 2014/07/20.
//  Copyright (c) 2014年 kishikawa katsumi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SRViewController.h"
#import <Parse/Parse.h>

@interface SRWindow : UIWindow
+ (SRWindow*)sharedInstance:(NSString*)appId;
@property (strong,nonatomic) NSString* appId;
@end
