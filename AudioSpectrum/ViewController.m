//
//  ViewController.m
//  AudioSpectrum
//
//  Created by sun on 2019/3/27.
//  Copyright © 2019 taihe. All rights reserved.
//

#import "ViewController.h"
#import "RealtimeAnalyzer.h"
#import "SpectrumView.h"

#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIBarButtonItem *playItem;


@property (nonatomic, strong) AVAudioEngine *engine;
@property (nonatomic, strong) AVAudioPlayerNode *player;
@property (nonatomic, strong) AVAudioFile *file;
@property (nonatomic, assign) AVAudioFrameCount fftSize;

@property (nonatomic, strong) RealtimeAnalyzer *analyzer;

@property (nonatomic, weak) IBOutlet SpectrumView *spectrumView;
@end

@implementation ViewController

- (void)dealloc {

}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.fftSize = 2048;

    
    self.analyzer = [[RealtimeAnalyzer alloc] initWithFFTSize:self.fftSize];
    
    self.engine = [[AVAudioEngine alloc] init];
    self.player = [[AVAudioPlayerNode alloc] init];
    [self.engine attachNode:self.player];
    AVAudioMixerNode *mixer = self.engine.mainMixerNode;
    [self.engine connect:self.player to:mixer format:nil];

    NSError *error = nil;
    if (![self.engine startAndReturnError:&error]) {
        self.playItem.enabled = NO;
        NSLog(@"%@", error);
    };
    
    [mixer removeTapOnBus:0];
    [mixer installTapOnBus:0 bufferSize:self.fftSize format:nil block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        if (!self.player.isPlaying) return ;
        buffer.frameLength = self.fftSize;
        NSArray<NSArray<NSNumber *> *> *spectra = [self.analyzer analyse:buffer];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spectrumView updateSpectra:spectra];
        });
    }];


}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat barSpace = CGRectGetWidth(self.spectrumView.frame) / (CGFloat)(80 * 3 - 1);
    self.spectrumView.barWidth = barSpace * 2;
    self.spectrumView.space = barSpace;
}
- (IBAction)playItemAction:(UIBarButtonItem *)sender {
    if (!self.file) {
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"03.Spektrum & Sara Skinner - Keep You.mp3" withExtension:nil];
        self.file = [[AVAudioFile alloc] initForReading:url error:nil];
        [self.player scheduleFile:self.file atTime:nil completionHandler:nil];
    }
    if ([self.player isPlaying]) {
        sender.title = @"play";
        [self.player pause];
    } else {
        sender.title = @"pause";
        [self.player play];
    }
}
@end
