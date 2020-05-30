//
//  SSAudioCommon.h
//  AudioSpectrum
//
//  Created by sun on 2019/4/3.
//  Copyright © 2019 taihe. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import <Endian.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 获取 可用 的 AudioFileTypeID
FOUNDATION_EXTERN NSArray *ss_get_fallbackTypeIDs(NSString *mimeType, NSString *fileExtension);

FOUNDATION_EXTERN void ss_call_main_thread(dispatch_block_t block);

FOUNDATION_EXTERN NSString *ss_OSStatusToString(OSStatus status);
NS_ASSUME_NONNULL_END

