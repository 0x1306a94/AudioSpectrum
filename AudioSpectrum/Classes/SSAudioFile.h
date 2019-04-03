//
//  SSAudioFile.h
//  AudioSpectrum
//
//  Created by sun on 2019/4/3.
//  Copyright © 2019 taihe. All rights reserved.
//

#ifndef SSAudioFile_h
#define SSAudioFile_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SSAudioFile <NSObject>

@required
- (NSURL *)ss_audioFileURL;
@end

NS_ASSUME_NONNULL_END

#endif /* SSAudioFile_h */
