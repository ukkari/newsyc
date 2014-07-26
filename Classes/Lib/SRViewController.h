//
//  SRViewController.h
//  ScreenRecorder
//
//  Created by Ukai Yu on 2014/07/20.
//  Copyright (c) 2014年 kishikawa katsumi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SRScreenRecorder.h"
#import <Parse/Parse.h>
#import "SRWindow.h"
@interface SRViewController : UIViewController
- (BOOL)updateView;
- (IBAction)recordTapped:(id)sender;
@end
