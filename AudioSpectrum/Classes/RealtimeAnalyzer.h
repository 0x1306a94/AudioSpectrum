//
//  RealtimeAnalyzer.h
//  AudioSpectrum
//
//  Created by king on 2019/3/27.
//  Copyright © 2019 taihe. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>

NS_ASSUME_NONNULL_BEGIN

@interface RealtimeAnalyzer : NSObject
@property (nonatomic, assign) float spectrumSmooth;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)initWithFFTSize:(int)fftSize NS_DESIGNATED_INITIALIZER;
- (NSArray<NSArray<NSNumber *> *> *)analyse:(AVAudioPCMBuffer *)buffer;
@end

NS_ASSUME_NONNULL_END

