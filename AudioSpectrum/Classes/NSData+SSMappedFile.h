//
//  NSData+SSMappedFile.h
//  AudioSpectrum
//
//  Created by sun on 2019/4/3.
//  Copyright © 2019 taihe. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData (SSMappedFile)
+ (instancetype)ss_dataWithMappedContentsOfFile:(NSString *)path;
+ (instancetype)ss_dataWithMappedContentsOfURL:(NSURL *)url;

+ (instancetype)ss_modifiableDataWithMappedContentsOfFile:(NSString *)path;
+ (instancetype)ss_modifiableDataWithMappedContentsOfURL:(NSURL *)url;

- (void)ss_synchronizeMappedFile;
@end

NS_ASSUME_NONNULL_END
