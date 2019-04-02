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
#import "TrackCell.h"

#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>


@interface ViewController ()<
UITableViewDataSource,
UITableViewDelegate>

@property (nonatomic, strong) AVAudioEngine *engine;
@property (nonatomic, strong) AVAudioPlayerNode *player;
@property (nonatomic, assign) AVAudioFrameCount fftSize;

@property (nonatomic, strong) RealtimeAnalyzer *analyzer;

@property (nonatomic, weak) IBOutlet SpectrumView *spectrumView;
@property (nonatomic, weak) IBOutlet UITableView *tableView;

@property (nonatomic, strong) NSMutableArray<NSString *> *trackPaths;
@property (nonatomic, weak) TrackCell *currentCell;
@property (nonatomic, assign) BOOL switchAudio;
@end

@implementation ViewController

- (void)dealloc {

}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass(TrackCell.class) bundle:nil] forCellReuseIdentifier:NSStringFromClass(TrackCell.class)];

    self.trackPaths = [NSMutableArray<NSString *> array];

    {
        NSArray<NSString *> *paths = [[[NSBundle mainBundle] pathsForResourcesOfType:@"mp3" inDirectory:nil] sortedArrayUsingSelector:@selector(compare:)];
        [paths enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *trackPath = [[obj componentsSeparatedByString:@"/"] lastObject];
            if (trackPath) {
                [self.trackPaths addObject:trackPath];
            }
        }];
    }

    self.fftSize = 1024;

    [self setupPlayer];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat barSpace = CGRectGetWidth(self.spectrumView.frame) / (CGFloat)(80 * 3 - 1);
    self.spectrumView.barWidth = barSpace * 2;
    self.spectrumView.space = barSpace;
}

- (void)setupPlayer {

    self.analyzer = [[RealtimeAnalyzer alloc] initWithFFTSize:self.fftSize];

    self.engine = [[AVAudioEngine alloc] init];
    self.player = [[AVAudioPlayerNode alloc] init];
    [self.engine attachNode:self.player];
    AVAudioMixerNode *mixer = self.engine.mainMixerNode;
    [self.engine connect:self.player to:mixer format:nil];

    NSError *error = nil;
    [self.engine startAndReturnError:&error];
    if (error) {
        NSLog(@"%@", error);
        self.tableView.userInteractionEnabled = NO;
        return;
    };

    self.tableView.userInteractionEnabled = YES;

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

- (void)playWithTarckName:(NSString *)trackName {
    NSURL *url = [[NSBundle mainBundle] URLForResource:trackName withExtension:nil];
    if (!url) return;
    NSError *error = nil;
    AVAudioFile *file = [[AVAudioFile alloc] initForReading:url error:&error];
    if (error) {
        NSLog(@"create AVAudioFile error: %@", error);
        return;
    }
    self.switchAudio = YES;
    [self.player stop];
    [self.player scheduleFile:file atTime:nil completionHandler:^{
        NSLog(@"播放完成");
        if (self.switchAudio) {
            self.switchAudio = NO;
            return ;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.currentCell) {
                [self.currentCell updateState:NO];
                self.currentCell = nil;
            };
        });
    }];
    [self.player play];
}
#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.trackPaths.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TrackCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(TrackCell.class)];
    BOOL playing = (self.currentCell == cell);
    [cell configureWithTrackName:self.trackPaths[indexPath.row] playing:playing];
    cell.didClickHandler = ^{
        if (self.currentCell) {
            [self.currentCell updateState:NO];
            if (self.currentCell == cell) {
                // stop
                self.currentCell = nil;
                [self.player stop];
                return;
            }
        }
        [self playWithTarckName:self.trackPaths[indexPath.row]];
        [cell updateState:YES];
        self.currentCell = cell;
    };
    return cell;
}

@end
