//
//  SSAudioLPCM.h
//  AudioSpectrum
//
//  Created by sun on 2019/4/4.
//  Copyright © 2019 taihe. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AudioToolbox/AudioToolbox.h>
NS_ASSUME_NONNULL_BEGIN

@interface SSAudioLPCM : NSObject
@property (nonatomic, assign, getter=isEnd) BOOL end;

- (void)rest;
- (BOOL)readBytes:(void **)bytes needReadLength:(NSUInteger)needReadLength realLength:(NSUInteger *)realLength;
- (void)writeBytes:(const void *)bytes length:(NSUInteger)length;
@end

NS_ASSUME_NONNULL_END
