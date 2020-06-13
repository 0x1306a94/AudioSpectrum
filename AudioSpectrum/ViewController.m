//
//  ViewController.m
//  AudioSpectrum
//
//  Created by sun on 2019/3/27.
//  Copyright © 2019 taihe. All rights reserved.
//

#import "RealtimeAnalyzer.h"
#import "SpectrumView.h"
#import "TrackCell.h"
#import "ViewController.h"

#import "SSAudioDecoder.h"
#import "SSAudioFile.h"
#import "SSAudioFileProvider.h"
#import "SSAudioLPCM.h"

#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>

#import "AudioSpectrum-Swift.h"
//@import AudioStreamer;

@interface AudioFileModel : NSObject <SSAudioFile>
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSURL *url;
@end

@implementation AudioFileModel

- (NSURL *)ss_audioFileURL {
    return self.url;
}
@end

@interface ViewController () <
    UITableViewDataSource,
    UITableViewDelegate,
    SSAudioDecoderDelegate>

@property (nonatomic, strong) AVAudioEngine *engine;
@property (nonatomic, strong) AVAudioPlayerNode *player;
@property (nonatomic, assign) AVAudioFrameCount fftSize;

@property (nonatomic, strong) RealtimeAnalyzer *analyzer;

@property (nonatomic, weak) IBOutlet SpectrumView *spectrumView;
@property (nonatomic, weak) IBOutlet UITableView *tableView;

@property (nonatomic, strong) NSMutableArray<AudioFileModel *> *trackPaths;
@property (nonatomic, weak) TrackCell *currentCell;
@property (nonatomic, assign) BOOL switchAudio;

@property (nonatomic, strong) SSAudioFileProvider *fileProvider;
@property (nonatomic, strong) SSAudioDecoder *decoder;
@property (nonatomic, assign) BOOL started;

@property (nonatomic, strong) WrappedStream *stream;
@end

@implementation ViewController {
    AudioComponentInstance _outputAudioUnit;
}
- (void)dealloc {
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    //    Streamer *a = [[Streamer alloc] init];
    [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass(TrackCell.class) bundle:nil] forCellReuseIdentifier:NSStringFromClass(TrackCell.class)];

    self.trackPaths = [NSMutableArray<AudioFileModel *> array];

    {
        NSArray<NSString *> *paths = [[[NSBundle mainBundle] pathsForResourcesOfType:@"mp3" inDirectory:nil] sortedArrayUsingSelector:@selector(compare:)];
        [paths enumerateObjectsUsingBlock:^(NSString *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            NSString *trackPath = [[obj componentsSeparatedByString:@"/"] lastObject];
            if (trackPath) {
                AudioFileModel *model = [[AudioFileModel alloc] init];
                model.name            = trackPath;
                model.url             = [[NSBundle mainBundle] URLForResource:trackPath withExtension:nil];
                [self.trackPaths addObject:model];
            }
        }];
        //        {
        //            AudioFileModel *model = [[AudioFileModel alloc] init];
        //            model.name = @"13+月半小夜曲.wav";
        //            model.url = [NSURL fileURLWithPath:@"/Users/sun/Downloads/13+月半小夜曲.wav"];
        //            [self.trackPaths addObject:model];
        //        }
    }

    self.fftSize = 1024;

    [self setupPlayer];

    //    self.fileProvider = [SSAudioFileProvider fileProviderWithAudioFile:self.trackPaths.lastObject];
    //    self.decoder = [[SSAudioDecoder alloc] initWithFileProvider:self.fileProvider];
    //    self.decoder.delegate = self;
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    //    [self.decoder startDecoder];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat barSpace           = CGRectGetWidth(self.spectrumView.frame) / (CGFloat)(80 * 3 - 1);
    self.spectrumView.barWidth = barSpace * 2;
    self.spectrumView.space    = barSpace;
}

- (void)setupPlayer {

    self.analyzer = [[RealtimeAnalyzer alloc] initWithFFTSize:self.fftSize];
#warning 播放本地音频
    //    self.engine = [[AVAudioEngine alloc] init];
    //    self.player = [[AVAudioPlayerNode alloc] init];
    //    [self.engine attachNode:self.player];
    //    AVAudioMixerNode *mixer = self.engine.mainMixerNode;
    //    [self.engine connect:self.player to:mixer format:nil];
    //
    //    NSError *error = nil;
    //    [self.engine startAndReturnError:&error];
    //    if (error) {
    //        NSLog(@"%@", error);
    //        self.tableView.userInteractionEnabled = NO;
    //        return;
    //    };
    //
    //    self.tableView.userInteractionEnabled = YES;
    //
    //    [mixer removeTapOnBus:0];
    //    [mixer installTapOnBus:0 bufferSize:self.fftSize format:nil block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
    //        if (!self.player.isPlaying) return ;
    //        buffer.frameLength = self.fftSize;
    //        NSArray<NSArray<NSNumber *> *> *spectra = [self.analyzer analyse:buffer];
    //        dispatch_async(dispatch_get_main_queue(), ^{
    //            [self.spectrumView updateSpectra:spectra];
    //        });
    //    }];
    
#warning 播放在线音频
    NSURL *url = [NSURL URLWithString:@"https://raw.githubusercontent.com/0x1306a94/AudioSpectrum/master/AudioSpectrum/02.Ellis%20-%20Clear%20My%20Head%20(Radio%20Edit)%20%5BNCS%5D.mp3"];
    /* clang-format off */
    self.stream = [[WrappedStream alloc] initWithUrl:url fftSize:self.fftSize callBack:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        NSArray<NSArray<NSNumber *> *> *spectra = [self.analyzer analyse:buffer];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spectrumView updateSpectra:spectra];
        });
    }];
    /* clang-format on */
}

- (void)playWithAudioFileModel:(AudioFileModel *)audioFileModel {
#warning 播放在线音频
    [self.stream play];
    return;
    
#warning 播放本地音频
    NSURL *url = audioFileModel.url;
    if (!url) return;
    NSError *error    = nil;
    AVAudioFile *file = [[AVAudioFile alloc] initForReading:url error:&error];
    if (error) {
        NSLog(@"create AVAudioFile error: %@", error);
        return;
    }
    self.switchAudio = YES;
    [self.player stop];
    /* clang-format off */
    [self.player scheduleFile:file atTime:nil completionHandler:^{
        NSLog(@"播放完成");
        if (self.switchAudio) {
            self.switchAudio = NO;
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.currentCell) {
                [self.currentCell updateState:NO];
                self.currentCell = nil;
            };
        });
    }];
    /* clang-format on */
    [self.player play];
}
#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.trackPaths.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TrackCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(TrackCell.class)];
    BOOL playing    = (self.currentCell == cell);
    [cell configureWithTrackName:self.trackPaths[indexPath.row].name playing:playing];
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
        [self playWithAudioFileModel:self.trackPaths[indexPath.row]];
        [cell updateState:YES];
        self.currentCell = cell;
    };
    return cell;
}

- (BOOL)createAudioComponentInstanceWithAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd {
    if (_outputAudioUnit != NULL) {
        return YES;
    }

    OSStatus status;
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
#if TARGET_OS_IPHONE
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
#else  /* TARGET_OS_IPHONE */
    desc.componentSubType = kAudioUnitSubType_HALOutput;
#endif /* TARGET_OS_IPHONE */
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags        = 0;
    desc.componentFlagsMask    = 0;

    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    if (comp == NULL) {
        return NO;
    }

    status = AudioComponentInstanceNew(comp, &_outputAudioUnit);
    if (status != noErr) {
        _outputAudioUnit = NULL;
        return NO;
    }

    AudioStreamBasicDescription requestedDesc = [SSAudioDecoder defaultOutputFormat];
    status                                    = AudioUnitSetProperty(_outputAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &requestedDesc, sizeof(requestedDesc));
    if (status != noErr) {
        AudioComponentInstanceDispose(_outputAudioUnit);
        _outputAudioUnit = NULL;
        return NO;
    }

    UInt32 size = sizeof(requestedDesc);
    status      = AudioUnitGetProperty(_outputAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &requestedDesc, &size);
    if (status != noErr) {
        AudioComponentInstanceDispose(_outputAudioUnit);
        _outputAudioUnit = NULL;
        return NO;
    }

    AURenderCallbackStruct input;
    input.inputProc       = au_render_callback;
    input.inputProcRefCon = (__bridge void *)self;

    status = AudioUnitSetProperty(_outputAudioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &input, sizeof(input));
    if (status != noErr) {
        AudioComponentInstanceDispose(_outputAudioUnit);
        _outputAudioUnit = NULL;
        return NO;
    }

    status = AudioUnitInitialize(_outputAudioUnit);
    if (status != noErr) {
        AudioComponentInstanceDispose(_outputAudioUnit);
        _outputAudioUnit = NULL;
        return NO;
    }
    return YES;
}
#pragma mark - SSAudioDecoderDelegate
- (void)ssAudioDecoder:(SSAudioDecoder *)decoder didParseAudioStreamBasicDescription:(AudioStreamBasicDescription)asdb {
    if (![self createAudioComponentInstanceWithAudioStreamBasicDescription:asdb]) {
        NSLog(@"创建AudioComponentInstance 失败");
    }
}

- (void)ssAudioDecoderDidReadyToProducePackets:(SSAudioDecoder *)decoder {
}

- (void)ssAudioDecoderDidReadyPlay:(SSAudioDecoder *)decoder {
    if (_outputAudioUnit == NULL) return;
    if (self.started) return;
    self.started = YES;
    AudioOutputUnitStart(_outputAudioUnit);
}
static OSStatus au_render_callback(void *inRefCon,
                                   AudioUnitRenderActionFlags *inActionFlags,
                                   const AudioTimeStamp *inTimeStamp,
                                   UInt32 inBusNumber,
                                   UInt32 inNumberFrames,
                                   AudioBufferList *ioData) {
    ViewController *vc = (__bridge ViewController *)inRefCon;

    void *outBuffer;
    NSUInteger length = 0;
    if ([vc.decoder.lpcm readBytes:&outBuffer needReadLength:ioData->mBuffers[0].mDataByteSize realLength:&length] && length > 0) {
        memcpy(ioData->mBuffers[0].mData, outBuffer, length);
    } else if ([vc.decoder.lpcm isEnd]) {
        *inActionFlags = kAudioUnitRenderAction_OutputIsSilence;
        bzero(ioData->mBuffers[0].mData, ioData->mBuffers[0].mDataByteSize);
        NSLog(@"完成...");
        [vc.decoder.lpcm rest];
        AudioOutputUnitStop(vc->_outputAudioUnit);
    }
    return noErr;
}

@end

