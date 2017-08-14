//
//  AddVideoViewController.m
//  VideoEditDemo
//
//  Created by Damon on 2017/5/13.
//  Copyright © 2017年 damon. All rights reserved.
//

#import "AddVideoViewController.h"
#import "CommonHeader.h"

@interface AddVideoViewController ()
{
    ///AVFoundation
    AVAsset * videoAsset;
    AVAssetExportSession *exporter;
    
    AVMutableCompositionTrack *AudioTrack;
}
@end

@implementation AddVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor lightGrayColor]];
    [self creatUI];
}

-(void)creatUI{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:@"两个视频拼接" forState:UIControlStateNormal];
    [button.titleLabel sizeToFit];
    [button addTarget:self action:@selector(addVideo) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    UIButton *button2 = [UIButton buttonWithType:UIButtonTypeCustom];
    [button2 setTitle:@"添加背景音乐" forState:UIControlStateNormal];
    [button2 sizeToFit];
    [button2 addTarget:self action:@selector(addMusic) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button2];
    
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.top.equalTo(self.view).with.offset(50);
    }];
    
    [button2 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.top.equalTo(self.view).with.offset(150);
    }];
}

-(void)addVideo{
    NSURL *videoPath1 = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"selfS" ofType:@"MOV"]];
    NSURL *videoPath2 = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"selfH" ofType:@"MOV"]];
    [self addFirstVideo:videoPath1 andSecondVideo:videoPath2 withMusic:nil];
}

-(void)addMusic{
    NSURL *videoPath1 = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"selfS" ofType:@"MOV"]];
    NSURL *videoPath2 = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"selfH" ofType:@"MOV"]];
    NSURL *music = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"music" ofType:@"mp3"]];
    [self addFirstVideo:videoPath1 andSecondVideo:videoPath2 withMusic:music];
}

-(void)addFirstVideo:(NSURL*)firstVideoPath andSecondVideo:(NSURL*)secondVideo withMusic:(NSURL*)musicPath{
    
    [SVProgressHUD showWithStatus:@"正在合成到系统相册中"];
    AVAsset *firstAsset = [AVAsset assetWithURL:firstVideoPath];
    AVAsset *secondAsset = [AVAsset assetWithURL:secondVideo];
    AVAsset *musciAsset = [AVAsset assetWithURL:musicPath];
    
    // 1 - Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    // 2 - Video track
    AVMutableCompositionTrack *firstTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
    [firstTrack insertTimeRange:CMTimeRangeFromTimeToTime(kCMTimeZero, firstAsset.duration)
                        ofTrack:[[firstAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
    [firstTrack insertTimeRange:CMTimeRangeFromTimeToTime(kCMTimeZero, secondAsset.duration)
                        ofTrack:[[secondAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:firstAsset.duration error:nil];
    
    if (musciAsset!=nil){
        AudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                                preferredTrackID:kCMPersistentTrackID_Invalid];
        [AudioTrack insertTimeRange:CMTimeRangeFromTimeToTime(kCMTimeZero, CMTimeAdd(firstAsset.duration, secondAsset.duration))
                                ofTrack:[[musciAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:kCMTimeZero error:nil];
    }
    
    
    // 4 - Get path
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:
                             [NSString stringWithFormat:@"mergeVideo-%d.mov",arc4random() % 1000]];
    NSURL *url = [NSURL fileURLWithPath:myPathDocs];
    // 5 - Create exporter
    exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition
                                                                      presetName:AVAssetExportPresetHighestQuality];
    
    //修改背景音乐的音量start
    AVMutableAudioMix *videoAudioMixTools = [AVMutableAudioMix audioMix];
    if (musciAsset) {
        //调节音量
        //获取音频轨道
        AVMutableAudioMixInputParameters *firstAudioParam = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:AudioTrack];
        //设置音轨音量,可以设置渐变,设置为1.0就是全音量
        [firstAudioParam setVolumeRampFromStartVolume:1.0 toEndVolume:1.0 timeRange:CMTimeRangeMake(kCMTimeZero, CMTimeAdd(firstAsset.duration, secondAsset.duration))];
        [firstAudioParam setTrackID:AudioTrack.trackID];
        videoAudioMixTools.inputParameters = [NSArray arrayWithObject:firstAudioParam];
    }
    //end
    
    exporter.outputURL=url;
    exporter.outputFileType = AVFileTypeQuickTimeMovie;
    exporter.audioMix = videoAudioMixTools;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self exportDidFinish:exporter];
        });
    }];
}

- (void)exportDidFinish:(AVAssetExportSession*)session {
    if (session.status == AVAssetExportSessionStatusCompleted) {
        NSURL *outputURL = session.outputURL;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
            __block PHObjectPlaceholder *placeholder;
            if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(outputURL.path)) {
                NSError *error;
                [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
                    PHAssetChangeRequest* createAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:outputURL];
                    placeholder = [createAssetRequest placeholderForCreatedAsset];
                } error:&error];
                if (error) {
                    [SVProgressHUD showErrorWithStatus:[NSString stringWithFormat:@"%@",error]];
                }
                else{
                    [SVProgressHUD showSuccessWithStatus:@"视频已经保存到相册"];
                }
            }else {
                [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"视频保存相册失败，请设置软件读取相册权限", nil)];
            }
        });
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
