//
//  SSAudioDecoder.h
//  AudioSpectrum
//
//  Created by sun on 2019/4/3.
//  Copyright © 2019 taihe. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@class SSAudioFileProvider;
@class SSAudioLPCM;

@protocol SSAudioDecoderDelegate;

@interface SSAudioDecoder : NSObject
@property (nonatomic, strong, readonly) SSAudioFileProvider *fileProvider;
@property (nonatomic, assign, readonly) AudioFileTypeID fileType;
@property (nonatomic, assign, readonly) BOOL available;
@property (nonatomic, assign, readonly) BOOL readyToProducePackets;
@property (nonatomic, assign, readonly) AudioStreamBasicDescription asdb;
@property (nonatomic, assign, readonly) unsigned long long fileSize;
@property (nonatomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, assign, readonly) UInt32 bitRate;
@property (nonatomic, assign, readonly) UInt32 maxPacketSize;
@property (nonatomic, assign, readonly) UInt64 audioDataByteCount;

@property (nonatomic, strong, readonly) SSAudioLPCM *lpcm;
@property (nonatomic, weak) id<SSAudioDecoderDelegate> delegate;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)initWithFileProvider:(__kindof SSAudioFileProvider *)fileProvider NS_DESIGNATED_INITIALIZER;

- (void)startDecoder;
- (void)stopDecoder;

+ (void)printAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd;
+ (AudioStreamBasicDescription)defaultOutputFormat;
+ (BOOL)isFloatFormat:(AudioStreamBasicDescription)asbd;

//------------------------------------------------------------------------------

+ (BOOL)isInterleaved:(AudioStreamBasicDescription)asbd;
//------------------------------------------------------------------------------

+ (BOOL)isLinearPCM:(AudioStreamBasicDescription)asbd;
@end


@protocol SSAudioDecoderDelegate <NSObject>

- (void)ssAudioDecoder:(SSAudioDecoder *)decoder didParseAudioStreamBasicDescription:(AudioStreamBasicDescription)asdb;
- (void)ssAudioDecoderDidReadyToProducePackets:(SSAudioDecoder *)decoder;
- (void)ssAudioDecoderDidReadyPlay:(SSAudioDecoder *)decoder;
@end

NS_ASSUME_NONNULL_END
