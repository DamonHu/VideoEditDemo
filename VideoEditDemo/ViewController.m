//
//  ViewController.m
//  VideoEditDemo
//
//  Created by Damon on 2017/5/13.
//  Copyright © 2017年 damon. All rights reserved.
//

#import "ViewController.h"
#import "CommonHeader.h"
#import "AddWatermarkViewController.h"
#import "CropVideoViewController.h"
#import "AddVideoViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor lightGrayColor]];
    ///申请麦克风权限
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
    }];
    ///申请拍照权限
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
    }];
    ///申请相册权限
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
    }];
    [self creatUI];
}

-(void)creatUI{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:@"视频加水印" forState:UIControlStateNormal];
    [button.titleLabel sizeToFit];
    [button addTarget:self action:@selector(addWater) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    UIButton *button2 = [UIButton buttonWithType:UIButtonTypeCustom];
    [button2 setTitle:@"裁剪视频" forState:UIControlStateNormal];
    [button2 sizeToFit];
    [button2 addTarget:self action:@selector(cropWater) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button2];
    
    UIButton *button3 = [UIButton buttonWithType:UIButtonTypeCustom];
    [button3 setTitle:@"音频视频拼接" forState:UIControlStateNormal];
    [button3 sizeToFit];
    [button3 addTarget:self action:@selector(addVideo) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button3];
    
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.top.equalTo(self.view).with.offset(50);
    }];
    
    [button2 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.top.equalTo(self.view).with.offset(150);
    }];
    
    [button3 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.top.equalTo(self.view).with.offset(250);
    }];
}

-(void)addWater{
    AddWatermarkViewController *addwaterVC = [[AddWatermarkViewController alloc] init];
    [self presentViewController:addwaterVC animated:true completion:nil];
}

-(void)cropWater{
    CropVideoViewController *cropVC  = [[CropVideoViewController alloc] init];
    [self presentViewController:cropVC animated:true completion:nil];
}

-(void)addVideo{
    AddVideoViewController *addVC = [[AddVideoViewController alloc] init];
    [self presentViewController:addVC animated:true completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
