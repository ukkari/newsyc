//
//  SRViewController.m
//  ScreenRecorder
//
//  Created by Ukai Yu on 2014/07/20.
//  Copyright (c) 2014年 kishikawa katsumi. All rights reserved.
//

#import "SRViewController.h"

@interface SRViewController ()

@end

@implementation SRViewController{
    BOOL isAvailable;
    //BOOL isRecording;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    //初期化処理
    isAvailable = NO;
    NSLog(@"SRViewController: %@",NSStringFromCGRect(self.view.frame));
    CGRect rect = self.view.frame;
    rect.origin.y = self.view.frame.size.height/3 * 2;
    //rect.size.height = self.frame.size.height/3;
    self.view.frame = rect;
    NSLog(@"SRViewController: %@",NSStringFromCGRect(self.view.frame));
}

- (IBAction)recordTapped:(id)sender {
    if(![SRScreenRecorder sharedInstance].isRecording){
        [[SRScreenRecorder sharedInstance] startRecording];
    }else{
        NSURL* savedFilePath = [[SRScreenRecorder sharedInstance] stopRecording];
        NSLog(@"Video has been saved to %@",savedFilePath.path);
        [self uploadToParse:savedFilePath];
        //[self uploadVideo:savedFilePath];
    }
    
    self.view.hidden = YES;
    self.view.window.userInteractionEnabled = NO;
    self.view.backgroundColor = [UIColor clearColor];
    isAvailable = NO;
}

- (void)uploadToParse:(NSURL*)url{
    __block NSURL* _url = url;
    __block PFFile* _file = [PFFile fileWithName:url.lastPathComponent contentsAtPath:url.path];
    [_file saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if(succeeded){
            PFObject *video = [PFObject objectWithClassName:@"Video"];
            video[@"fileName"] = _url.lastPathComponent;
            video[@"file"] = _file;
            SRWindow* _window = (SRWindow*)(self.view.window);
            video[@"appId"] = _window.appId;
            if([SRScreenRecorder sharedInstance].taskId != nil){
                video[@"taskId"] = [SRScreenRecorder sharedInstance].taskId;
            }else{
                video[@"taskId"] = @"default";
            }
            [video saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                [SRScreenRecorder sharedInstance].taskId = nil;
            }];
        }
    } progressBlock:^(int percentDone) {
        NSLog(@"Uploading:%d",percentDone);
    }];
}

- (void)viewDidLoad
{
    NSLog(@"SRViewController loaded");
    //[self becomeFirstResponder];
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    NSLog(@"SRViewController: %@",NSStringFromCGRect(self.view.frame));
    CGRect rect = self.view.frame;
    rect.origin.y = self.view.frame.size.height/3 * 2;
    //rect.size.height = self.frame.size.height/3;
    self.view.frame = rect;
    NSLog(@"SRViewController: %@",NSStringFromCGRect(self.view.frame));
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)updateView{
    isAvailable = !isAvailable;
    if(isAvailable) {
        self.view.hidden = NO;
        self.view.window.userInteractionEnabled = YES;
        self.view.backgroundColor = [UIColor whiteColor];
    }else{
        self.view.hidden = YES;
        self.view.window.userInteractionEnabled = NO;
        self.view.backgroundColor = [UIColor clearColor];
    }
    return isAvailable;
}

- (BOOL)canBecomeFirstResponder {
    return NO;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
