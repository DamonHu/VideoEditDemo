//
//  CropVideoViewController.m
//  VideoEditDemo
//
//  Created by Damon on 2017/5/13.
//  Copyright © 2017年 damon. All rights reserved.
//

#import "CropVideoViewController.h"
#import "CommonHeader.h"

typedef void(^JLXCommonToolVedioCompletionHandler)(NSURL *assetURL,NSError *error,BOOL isVideoAssetvertical);

@interface CropVideoViewController ()
{
    AVAsset * videoAsset;
    CADisplayLink* dlink;
    AVAssetExportSession *exporter;
    
    GPUImageMovie *movieFile;
    GPUImageOutput<GPUImageInput> *filter;
    GPUImageMovieWriter *movieWriter;
}
@property (copy,nonatomic)JLXCommonToolVedioCompletionHandler completionHandler;
@end

@implementation CropVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor lightGrayColor]];
    [self creatUI];
}

-(void)creatUI{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:@"裁剪视频" forState:UIControlStateNormal];
    [button.titleLabel sizeToFit];
    [button addTarget:self action:@selector(cropImage) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.top.equalTo(self.view).with.offset(50);
    }];
}

-(void)cropImage{
    NSURL *videoPath = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"selfS" ofType:@"MOV"]];
    [self saveVideoPath:videoPath withStartTime:0.1 withEndTime:0 withSize:CGSizeMake(300, 300) withVideoDealPoint:CGPointMake(50, 50) WithFileName:@"cropVideo" shouldScale:YES];
}

//使用gpuimage重新录制一次
-(void)saveVedioPath:(NSURL*)vedioPath WithFileName:(NSString*)fileName andCallBack:(JLXCommonToolVedioCompletionHandler)competion
{
    self.completionHandler = competion;
    // 滤镜
    filter = [[GPUImageAlphaBlendFilter alloc] init];
    //    //mix即为叠加后的透明度,这里就直接写1.0了
    [(GPUImageDissolveBlendFilter *)filter setMix:1.0f];
    
    // 播放
    NSURL *sampleURL  = vedioPath;
    AVAsset *asset = [AVAsset assetWithURL:sampleURL];
    movieFile = [[GPUImageMovie alloc] initWithAsset:asset];
    movieFile.runBenchmark = YES;
    movieFile.playAtActualSpeed = NO;
    
    AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    UIImageOrientation videoAssetOrientation_  = UIImageOrientationUp;
    //拍摄的时候视频是否是竖屏拍的
    BOOL isVideoAssetvertical  = NO;
    CGAffineTransform videoTransform = videoAssetTrack.preferredTransform;
    if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) {
        isVideoAssetvertical = YES;
        videoAssetOrientation_ =  UIImageOrientationUp;//正着拍
    }
    if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {
        //        videoAssetOrientation_ =  UIImageOrientationLeft;
        isVideoAssetvertical = YES;
        videoAssetOrientation_ = UIImageOrientationDown;//倒着拍
    }
    if (videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0) {
        isVideoAssetvertical = NO;
        videoAssetOrientation_ =  UIImageOrientationLeft;//左边拍的
    }
    if (videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0) {
        isVideoAssetvertical = NO;
        videoAssetOrientation_ = UIImageOrientationRight;//右边拍
    }
    
    GPUImageView *filterView = [[GPUImageView alloc] initWithFrame:CGRectMake(0, 0, asset.naturalSize.width, asset.naturalSize.height)];
    [filterView setTransform:CGAffineTransformMakeRotation(M_PI_2)];
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, asset.naturalSize.width, asset.naturalSize.height)];
    [view setBackgroundColor:[UIColor clearColor]];
    
    GPUImageUIElement *uielement = [[GPUImageUIElement alloc] initWithView:view];
    
    NSString *pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%@.mp4",fileName]];
    unlink([pathToMovie UTF8String]);
    NSURL *movieURL = [NSURL fileURLWithPath:pathToMovie];
    
    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(asset.naturalSize.width, asset.naturalSize.height)];
    
    GPUImageFilter* progressFilter = [[GPUImageFilter alloc] init];
    [movieFile addTarget:progressFilter];
    [progressFilter addTarget:filter];
    [uielement addTarget:filter];
    movieWriter.shouldPassthroughAudio = YES;
    if ([[asset tracksWithMediaType:AVMediaTypeAudio] count] > 0){
        movieFile.audioEncodingTarget = movieWriter;
    } else {//no audio
        movieFile.audioEncodingTarget = nil;
    }
    
    [movieFile enableSynchronizedEncodingUsingMovieWriter:movieWriter];
    // 显示到界面
    [filter addTarget:filterView];
    [filter addTarget:movieWriter];
    
    [movieWriter startRecording];
    [movieFile startProcessing];
    
    __weak typeof(self) weakSelf = self;
    
    [progressFilter setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
        [uielement update];
    }];
    
    [movieWriter setCompletionBlock:^{
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf->filter removeTarget:strongSelf->movieWriter];
        [strongSelf->movieWriter finishRecording];
        if (strongSelf.completionHandler) {
            strongSelf.completionHandler(movieURL,nil,isVideoAssetvertical);
        }
    }];
}

/**
 裁剪视频
 @param videoPath 视频的路径
 @param startTime 截取视频开始时间
 @param endTime 截取视频结束时间，如果为0则为整个视频
 @param videoSize 视频截取的大小，如果为0则不裁剪视频大小
 @param videoDealPoint Point(x,y):传zero则为裁剪从0,0开始
 @param fileName 文件名字
 @param shouldScale 是否拉伸，false的话不拉伸，裁剪黑背景
 */
- (void)saveVideoPath:(NSURL*)videoPath withStartTime:(float)startTime withEndTime:(float)endTime withSize:(CGSize)videoSize withVideoDealPoint:(CGPoint)videoDealPoint WithFileName:(NSString*)fileName shouldScale:(BOOL)shouldScale
{
    if (!videoPath) {
        [SVProgressHUD dismiss];
        return;
    }
    [SVProgressHUD showWithStatus:@"裁剪视频到系统相册"];
    //1 创建AVAsset实例 AVAsset包含了video的所有信息 self.videoUrl输入视频的路径
    
    //封面图片
    NSDictionary *opts = [NSDictionary dictionaryWithObject:@(YES) forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    videoAsset = [AVURLAsset URLAssetWithURL:videoPath options:opts];     //初始化视频媒体文件
    bool isWXVideo = false;
    for (int i=0; i<videoAsset.metadata.count; i++) {
        AVMetadataItem * item = [videoAsset.metadata objectAtIndex:i];
        NSLog(@"======metadata:%@,%@,%@,%@",item.identifier,item.extraAttributes,item.value,item.dataType);
        NSDictionary *dic = [self StrToArrayOrNSDictionary:[NSString stringWithFormat:@"%@",item.value]];
        if ([[dic.allKeys objectAtIndex:0] isEqualToString: @"WXVer"]) {
            isWXVideo = true;
            [self saveVedioPath:videoPath WithFileName:@"wxVideo" andCallBack:^(NSURL *assetURL, NSError *error,BOOL isVideoAssetvertical) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    NSString *newVideoPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/wxVideo.mp4"];
                    [self goSaveVideoPath:[NSURL fileURLWithPath:newVideoPath] withStartTime:startTime withEndTime:endTime withSize:videoSize withVideoDealPoint:videoDealPoint WithFileName:fileName shouldScale:shouldScale isWxVideoAssetvertical:isVideoAssetvertical];
                });
            }];
            break;
        }
    }
    if ([[videoAsset tracksWithMediaType:AVMediaTypeAudio] count] == 0){
        [self saveVedioPath:videoPath WithFileName:@"wxVideo" andCallBack:^(NSURL *assetURL, NSError *error,BOOL isVideoAssetvertical) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *newVideoPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/wxVideo.mp4"];
                [self goSaveVideoPath:[NSURL fileURLWithPath:newVideoPath] withStartTime:startTime withEndTime:endTime withSize:videoSize withVideoDealPoint:videoDealPoint WithFileName:fileName shouldScale:shouldScale isWxVideoAssetvertical:isVideoAssetvertical];
            });
        }];
        return;
    }
    if (!isWXVideo) {
        [self goSaveVideoPath:videoPath withStartTime:startTime withEndTime:endTime withSize:videoSize withVideoDealPoint:videoDealPoint WithFileName:fileName shouldScale:shouldScale isWxVideoAssetvertical:NO];
    }
}

//Assetvertical gpuimage会把微信的竖屏渲染成横屏，横屏还是横屏
- (void)goSaveVideoPath:(NSURL*)videoPath withStartTime:(float)startTime withEndTime:(float)endTime withSize:(CGSize)videoSize withVideoDealPoint:(CGPoint)videoDealPoint WithFileName:(NSString*)fileName shouldScale:(BOOL)shouldScale isWxVideoAssetvertical:(BOOL)Assetvertical{
    if (!videoPath) {
        [SVProgressHUD dismiss];
        return;
    }
    //1 创建AVAsset实例 AVAsset包含了video的所有信息 self.videoUrl输入视频的路径
    
    //封面图片
    NSDictionary *opts = [NSDictionary dictionaryWithObject:@(YES) forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    //    NSDictionary *opts = [NSDictionary dictionaryWithObjectsAndKeys:@(YES),AVURLAssetPreferPreciseDurationAndTimingKey,AVAssetReferenceRestrictionForbidNone,AVURLAssetReferenceRestrictionsKey, nil];
    videoAsset = [AVURLAsset URLAssetWithURL:videoPath options:opts];     //初始化视频媒体文件
    
    //开始时间
    CMTime startCropTime = CMTimeMakeWithSeconds(startTime, 600);
    //结束时间
    CMTime endCropTime = CMTimeMakeWithSeconds(endTime, 600);
    if (endTime == 0) {
        endCropTime = CMTimeMakeWithSeconds(videoAsset.duration.value/videoAsset.duration.timescale-startTime, videoAsset.duration.timescale);
    }
    
    //2 创建AVMutableComposition实例. apple developer 里边的解释 【AVMutableComposition is a mutable subclass of AVComposition you use when you want to create a new composition from existing assets. You can add and remove tracks, and you can add, remove, and scale time ranges.】
    AVMutableComposition *mixComposition = [AVMutableComposition composition];
    
    //有声音
    if ([[videoAsset tracksWithMediaType:AVMediaTypeAudio] count] > 0){
        //声音采集
        AVURLAsset * audioAsset = [[AVURLAsset alloc] initWithURL:videoPath options:opts];
        //音频通道
        AVMutableCompositionTrack * audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        //音频采集通道
        AVAssetTrack * audioAssetTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] lastObject];
        [audioTrack insertTimeRange:CMTimeRangeMake(startCropTime, endCropTime) ofTrack:audioAssetTrack atTime:kCMTimeZero error:nil];
    }
    
    //3 视频通道  工程文件中的轨道，有音频轨、视频轨等，里面可以插入各种对应的素材
    AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
    NSError *error;
    //把视频轨道数据加入到可变轨道中 这部分可以做视频裁剪TimeRange
    [videoTrack insertTimeRange:CMTimeRangeMake(startCropTime, endCropTime)
                        ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] lastObject]
                         atTime:kCMTimeZero error:&error];
    
    
    //3.1 AVMutableVideoCompositionInstruction 视频轨道中的一个视频，可以缩放、旋转等
    AVMutableVideoCompositionInstruction *mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, videoTrack.timeRange.duration);
    
    // 3.2 AVMutableVideoCompositionLayerInstruction 一个视频轨道，包含了这个轨道上的所有视频素材
    AVMutableVideoCompositionLayerInstruction *videolayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    
    AVAssetTrack *videoAssetTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] lastObject];
    UIImageOrientation videoAssetOrientation_  = UIImageOrientationUp;
    //拍摄的时候视频是否是竖屏拍的
    BOOL isVideoAssetvertical  = NO;
    CGAffineTransform videoTransform = videoAssetTrack.preferredTransform;
    if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) {
        isVideoAssetvertical = YES;
        videoAssetOrientation_ =  UIImageOrientationUp;//正着拍
    }
    if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {
        //        videoAssetOrientation_ =  UIImageOrientationLeft;
        isVideoAssetvertical = YES;
        videoAssetOrientation_ = UIImageOrientationDown;//倒着拍
    }
    if (videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0) {
        isVideoAssetvertical = NO;
        videoAssetOrientation_ =  UIImageOrientationLeft;//左边拍的
    }
    if (videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0) {
        isVideoAssetvertical = NO;
        videoAssetOrientation_ = UIImageOrientationRight;//右边拍
    }
    
    float scaleX = 1.0,scaleY = 1.0,scale = 1.0;
    CGSize originVideoSize;
    if (isVideoAssetvertical || Assetvertical) {
        originVideoSize = CGSizeMake([[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize].height, [[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize].width);
    }
    else{
        originVideoSize = CGSizeMake([[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize].width, [[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize].height);
    }
    float x = videoDealPoint.x;
    float y = videoDealPoint.y;
    if (shouldScale) {
        scaleX = videoSize.width/originVideoSize.width;
        scaleY = videoSize.height/originVideoSize.height;
        scale  = MAX(scaleX, scaleY);
        if (scaleX>scaleY) {
            NSLog(@"竖屏");
        }
        else{
            NSLog(@"横屏");
        }
    }
    else{
        scaleX = 1.0;
        scaleY = 1.0;
        scale = 1.0;
    }
    if (Assetvertical) {
        CGAffineTransform trans = CGAffineTransformMake(videoAssetTrack.preferredTransform.a*scale, videoAssetTrack.preferredTransform.b*scale, videoAssetTrack.preferredTransform.c*scale, videoAssetTrack.preferredTransform.d*scale, videoAssetTrack.preferredTransform.tx*scale-x+720, videoAssetTrack.preferredTransform.ty*scale-y);
        
        //    [videolayerInstruction setTransform:trans atTime:kCMTimeZero];
        CGAffineTransform trans2 = CGAffineTransformRotate(trans, M_PI_2);
        [videolayerInstruction setTransform:trans2 atTime:kCMTimeZero];
    }
    else{
        CGAffineTransform trans = CGAffineTransformMake(videoAssetTrack.preferredTransform.a*scale, videoAssetTrack.preferredTransform.b*scale, videoAssetTrack.preferredTransform.c*scale, videoAssetTrack.preferredTransform.d*scale, videoAssetTrack.preferredTransform.tx*scale-x, videoAssetTrack.preferredTransform.ty*scale-y);
        
        [videolayerInstruction setTransform:trans atTime:kCMTimeZero];
    }
    //裁剪区域
    //    [videolayerInstruction setCropRectangle:CGRectMake(0, 0, 720, 720) atTime:kCMTimeZero];
    // 3.3 - Add instructions
    mainInstruction.layerInstructions = [NSArray arrayWithObjects:videolayerInstruction,nil];
    //AVMutableVideoComposition：管理所有视频轨道，可以决定最终视频的尺寸，裁剪需要在这里进行
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    
    CGSize naturalSize;
    //    if(isVideoAssetvertical){
    //        naturalSize = CGSizeMake(videoAssetTrack.naturalSize.height, videoAssetTrack.naturalSize.width);
    //    } else {
    //        naturalSize = videoAssetTrack.naturalSize;
    //    }
    naturalSize = originVideoSize;
    int64_t renderWidth = 0, renderHeight = 0;
    if (videoSize.height ==0.0 || videoSize.width == 0.0) {
        renderWidth = naturalSize.width;
        renderHeight = naturalSize.height;
    }
    else{
        renderWidth = ceil(videoSize.width);
        renderHeight = ceil(videoSize.height);
    }
    
    mainCompositionInst.renderSize = CGSizeMake(renderWidth, renderHeight);
    mainCompositionInst.instructions = [NSArray arrayWithObject:mainInstruction];
    mainCompositionInst.frameDuration = CMTimeMake(1, 30);
    
    // 4 - 输出路径
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4",fileName]];
    unlink([myPathDocs UTF8String]);
    NSURL* videoUrl = [NSURL fileURLWithPath:myPathDocs];
    
    //    dlink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateProgress)];
    //    [dlink setFrameInterval:15];
    //    [dlink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    //    [dlink setPaused:NO];
    // 5 - 视频文件输出
    
    exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition
                                                presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL=videoUrl;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    exporter.videoComposition = mainCompositionInst;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            //这里是输出视频之后的操作，做你想做的
            [self cropExportDidFinish:exporter];
        });
    }];
}


- (void)cropExportDidFinish:(AVAssetExportSession*)session {
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
    else{
        NSLog(@"%@",session.error);
        [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"裁剪失败", nil)];
    }
}

// 将JSONDATA转化为字典或者数组
- (id)DataToArrayOrNSDictionary:(NSData *)jsonData{
    NSError *error = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:&error];
    if (jsonObject != nil && error == nil){
        return jsonObject;
    }else{
        // 解析错误
        return nil;
    }
}

// 将JSON串转化为字典或者数组
- (id)StrToArrayOrNSDictionary:(NSString *)jsonStr {
    NSData *jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    return [self DataToArrayOrNSDictionary:jsonData];
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
