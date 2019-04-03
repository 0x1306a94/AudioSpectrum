//
//  SSAudioFileProvider.m
//  AudioSpectrum
//
//  Created by sun on 2019/4/3.
//  Copyright © 2019 taihe. All rights reserved.
//

#import "SSAudioFileProvider.h"
#import "NSData+SSMappedFile.h"
#import "SSAudioFile.h"

#import <MobileCoreServices/MobileCoreServices.h>
@interface SSAudioFileProvider () {
@protected
    id<SSAudioFile> _audioFile;
    NSString *_cachedPath;
    NSURL *_cachedURL;
    NSString *_mimeType;
    NSString *_fileExtension;
    NSString *_sha256;
    NSData *_mappedData;
    NSUInteger _expectedLength;
    NSUInteger _receivedLength;
    BOOL _failed;
}

- (instancetype)_initWithAudioFile:(id<SSAudioFile>)audioFile;
@end

@interface _SSAudioLocalFileProvider : SSAudioFileProvider

@end

@implementation _SSAudioLocalFileProvider
- (instancetype)_initWithAudioFile:(id<SSAudioFile>)audioFile {
    if (self == [super _initWithAudioFile:audioFile]) {
        _cachedURL = [audioFile ss_audioFileURL];
        _cachedPath = [_cachedURL path];
        BOOL isDirectory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:_cachedPath
                                                  isDirectory:&isDirectory] ||
            isDirectory) {
            return nil;
        }

        _mappedData = [NSData ss_dataWithMappedContentsOfFile:_cachedPath];
        _expectedLength = [_mappedData length];
        _receivedLength = [_mappedData length];
    }
    return self;
}
- (NSString *)mimeType
{
    if (_mimeType == nil &&
        [self fileExtension] != nil) {
        CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[self fileExtension], NULL);
        if (uti != NULL) {
            _mimeType = CFBridgingRelease(UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType));
            CFRelease(uti);
        }
    }

    return _mimeType;
}

- (NSString *)fileExtension
{
    if (_fileExtension == nil) {
        _fileExtension = [[[self audioFile] ss_audioFileURL] pathExtension];
    }

    return _fileExtension;
}

- (NSUInteger)downloadSpeed
{
    return _receivedLength;
}

- (BOOL)isReady
{
    return YES;
}

- (BOOL)isFinished
{
    return YES;
}
@end

@implementation SSAudioFileProvider
@synthesize audioFile = _audioFile;
@synthesize cachedPath = _cachedPath;
@synthesize cachedURL = _cachedURL;
@synthesize mimeType = _mimeType;
@synthesize fileExtension = _fileExtension;
@synthesize sha256 = _sha256;
@synthesize mappedData = _mappedData;
@synthesize expectedLength = _expectedLength;
@synthesize receivedLength = _receivedLength;
@synthesize failed = _failed;

+ (instancetype)fileProviderWithAudioFile:(id<SSAudioFile>)audioFile {
    if (audioFile == nil) return nil;
    NSURL *audioFileURL = [audioFile ss_audioFileURL];
    if (audioFileURL == nil) return nil;
    if ([audioFileURL isFileURL]) {
        return [[_SSAudioLocalFileProvider alloc] _initWithAudioFile:audioFile];
    }
    return nil;
}

- (instancetype)_initWithAudioFile:(id<SSAudioFile>)audioFile
{
    self = [super init];
    if (self) {
        _audioFile = audioFile;
    }

    return self;
}

- (NSUInteger)downloadSpeed
{
    [self doesNotRecognizeSelector:_cmd];
    return 0;
}

- (BOOL)isReady
{
    [self doesNotRecognizeSelector:_cmd];
    return NO;
}

- (BOOL)isFinished
{
    [self doesNotRecognizeSelector:_cmd];
    return NO;
}
@end
