//
//  SRTaskDetailedViewController.m
//  ScreenRecorder
//
//  Created by Ukai Yu on 2014/07/25.
//  Copyright (c) 2014年 kishikawa katsumi. All rights reserved.
//

#import "SRTaskDetailedViewController.h"
#import "SRScreenRecorder.h"
#import "SRViewController.h"

@interface SRTaskDetailedViewController ()
@property (weak, nonatomic) IBOutlet UILabel *bodyLabel;
@end

@implementation SRTaskDetailedViewController{
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _bodyLabel.text = _body;
    self.navigationItem.rightBarButtonItem = [self createStartButton];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIBarButtonItem*)createStartButton{
    return [[UIBarButtonItem alloc]
            initWithTitle:@"Start" style:UIBarButtonItemStylePlain target:self action:@selector(startTapped:)];
}

- (void)startTapped:(id)sender{
    [(SRViewController*)(self.presentingViewController) updateView];
    self.view.window.userInteractionEnabled = NO;
    [self dismissViewControllerAnimated:YES completion:^{
        [[SRScreenRecorder sharedInstance] startRecording:_parseId];
        //[(SRViewController*)(self.presentingViewController) ];
    }];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
