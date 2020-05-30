//
//  SSAudioFileProvider.h
//  AudioSpectrum
//
//  Created by sun on 2019/4/3.
//  Copyright © 2019 taihe. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SSAudioFile;

@interface SSAudioFileProvider : NSObject
+ (instancetype)fileProviderWithAudioFile:(id<SSAudioFile>)audioFile;

@property (nonatomic, strong, readonly) id<SSAudioFile> audioFile;
@property (nonatomic, copy, readonly) NSString *cachedPath;
@property (nonatomic, copy, readonly) NSURL *cachedURL;
@property (nonatomic, copy, readonly) NSString *mimeType;
@property (nonatomic, copy, readonly) NSString *fileExtension;
@property (nonatomic, copy, readonly) NSString *sha256;
@property (nonatomic, strong, readonly) NSData *mappedData;
@property (nonatomic, assign, readonly) NSUInteger expectedLength;
@property (nonatomic, assign, readonly) NSUInteger receivedLength;
@property (nonatomic, assign, readonly) NSUInteger downloadSpeed;
@property (nonatomic, assign, readonly, getter=isFailed) BOOL failed;
@property (nonatomic, assign, readonly, getter=isReady) BOOL ready;
@property (nonatomic, assign, readonly, getter=isFinished) BOOL finished;

@end

NS_ASSUME_NONNULL_END

