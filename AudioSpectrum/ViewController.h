//
//  ViewController.h
//  AudioSpectrum
//
//  Created by sun on 2019/3/27.
//  Copyright © 2019 taihe. All rights reserved.
//

#import <UIKit/UIKit.h>

@import AVFoundation;

@interface ViewController : UIViewController
@property (nonatomic, assign, readonly) AVAudioFrameCount fftSize;
@end

