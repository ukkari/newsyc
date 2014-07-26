//
//  SRVideoTableViewController.m
//  ScreenRecorder
//
//  Created by Ukai Yu on 2014/07/21.
//  Copyright (c) 2014年 kishikawa katsumi. All rights reserved.
//

#import "SRVideoTableViewController.h"

@interface SRVideoTableViewController ()
@property (strong, nonatomic) MPMoviePlayerViewController *player;
@end

@implementation SRVideoTableViewController{
    NSMutableArray* listOfRecordedVideos;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    self.navigationItem.rightBarButtonItem = [self createDoneButton];
    
    listOfRecordedVideos = [self getListOfFilesWithPath:[self documentDirectory]];
}



- (void)doneTapped:(id)sender{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [listOfRecordedVideos count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.textLabel.text = [listOfRecordedVideos objectAtIndex:indexPath.row];
    
    return cell;
}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSURL* url = [NSURL fileURLWithPath:[self getFilePathWithRowNumber:indexPath.row]];
    _player = [[MPMoviePlayerViewController alloc] initWithContentURL:url];
    [[NSNotificationCenter defaultCenter] removeObserver:_player
                                                    name:MPMoviePlayerPlaybackDidFinishNotification
                                                  object:_player.moviePlayer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(videoFinished:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification 
                                               object:_player.moviePlayer];
    
    [self presentMoviePlayerViewControllerAnimated:_player];
}

//Not to dismiss MPMoviePlayerViewController when playing finishes
//http://xoyip.hatenablog.com/entry/2014/06/09/203000
- (void)videoFinished:(NSNotification*)notification{
    int value = [[notification.userInfo valueForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey] intValue];
    if (value == MPMovieFinishReasonUserExited) {
        [self dismissMoviePlayerViewControllerAnimated];
    }
}



// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [self removeWithPath:[self getFilePathWithRowNumber:indexPath.row]];
        [listOfRecordedVideos removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    if (editing) {
        //in editing mode
        self.navigationItem.rightBarButtonItem = nil;
    }else{
        //back from editing mode
        self.navigationItem.rightBarButtonItem = [self createDoneButton];
    }
}

#pragma mark Utility methods

- (NSString*)getFilePathWithRowNumber:(NSUInteger)row{
    NSString* fileName = [listOfRecordedVideos objectAtIndex:row];
    return [[self documentDirectory] stringByAppendingPathComponent:fileName];
}

- (NSMutableArray*) getListOfFilesWithPath:(NSString*)path{
    NSArray *tempArray = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
    NSMutableArray *directoryContent = [NSMutableArray arrayWithArray:tempArray];
    for (int count = 0; count < (int)[directoryContent count]; count++)
    {
        NSLog(@"File %d: %@", (count + 1), [directoryContent objectAtIndex:count]);
    }
    return directoryContent;
}

- (NSString *)documentDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return documentsDirectory;
}

- (BOOL)removeWithPath:(NSString*)path{
    NSError *error;
    return [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
}

- (UIBarButtonItem*)createDoneButton{
    return [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:UIBarButtonSystemItemDone
            target:self
            action:@selector(doneTapped:)];
}

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
