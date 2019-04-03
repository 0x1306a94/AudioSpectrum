//
//  NSData+SSMappedFile.m
//  AudioSpectrum
//
//  Created by sun on 2019/4/3.
//  Copyright © 2019 taihe. All rights reserved.
//

#import "NSData+SSMappedFile.h"

#import <sys/types.h>
#import <sys/mman.h>

static NSMutableDictionary *__ss_get_size_map__()
{
    static NSMutableDictionary *map = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = [[NSMutableDictionary alloc] init];
    });

    return map;
}

static void __ss_mmap_deallocate__(void *ptr, void *info)
{
    NSNumber *key = [NSNumber numberWithUnsignedLongLong:(uintptr_t)ptr];
    NSNumber *fileSize = nil;

    NSMutableDictionary *sizeMap = __ss_get_size_map__();
    @synchronized(sizeMap) {
        fileSize = [sizeMap objectForKey:key];
        [sizeMap removeObjectForKey:key];
    }

    size_t size = (size_t)[fileSize unsignedLongLongValue];
    munmap(ptr, size);
}

static CFAllocatorRef __ss_get_mmap_deallocator__()
{
    static CFAllocatorRef deallocator = NULL;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CFAllocatorContext context;
        bzero(&context, sizeof(context));
        context.deallocate = __ss_mmap_deallocate__;

        deallocator = CFAllocatorCreate(kCFAllocatorDefault, &context);
    });

    return deallocator;
}

@implementation NSData (SSMappedFile)
+ (instancetype)ss_dataWithMappedContentsOfFile:(NSString *)path
{
    return [[self class] _ss_dataWithMappedContentsOfFile:path modifiable:NO];
}

+ (instancetype)ss_dataWithMappedContentsOfURL:(NSURL *)url
{
    return [[self class] ss_dataWithMappedContentsOfFile:[url path]];
}

+ (instancetype)ss_modifiableDataWithMappedContentsOfFile:(NSString *)path
{
    return [[self class] _ss_dataWithMappedContentsOfFile:path modifiable:YES];
}

+ (instancetype)ss_modifiableDataWithMappedContentsOfURL:(NSURL *)url
{
    return [[self class] ss_modifiableDataWithMappedContentsOfFile:[url path]];
}

+ (instancetype)_ss_dataWithMappedContentsOfFile:(NSString *)path modifiable:(BOOL)modifiable
{
    NSFileHandle *fileHandle = nil;
    if (modifiable) {
        fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
    }
    else {
        fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    }
    if (fileHandle == nil) {
        return nil;
    }

    int fd = [fileHandle fileDescriptor];
    if (fd < 0) {
        return nil;
    }

    off_t size = lseek(fd, 0, SEEK_END);
    if (size < 0) {
        return nil;
    }

    int protection = PROT_READ;
    if (modifiable) {
        protection |= PROT_WRITE;
    }

    void *address = mmap(NULL, (size_t)size, protection, MAP_FILE | MAP_SHARED, fd, 0);
    if (address == MAP_FAILED) {
        return nil;
    }

    NSMutableDictionary *sizeMap = __ss_get_size_map__();
    @synchronized(sizeMap) {
        [sizeMap setObject:[NSNumber numberWithUnsignedLongLong:(unsigned long long)size]
                    forKey:[NSNumber numberWithUnsignedLongLong:(uintptr_t)address]];
    }

    return CFBridgingRelease(CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (const UInt8 *)address, (CFIndex)size, __ss_get_mmap_deallocator__()));
}

- (void)ss_synchronizeMappedFile
{
    NSNumber *key = [NSNumber numberWithUnsignedLongLong:(uintptr_t)[self bytes]];
    NSNumber *fileSize = nil;

    NSMutableDictionary *sizeMap = __ss_get_size_map__();
    @synchronized(sizeMap) {
        fileSize = [sizeMap objectForKey:key];
    }

    if (fileSize == nil) {
        return;
    }

    size_t size = (size_t)[fileSize unsignedLongLongValue];
    msync((void *)[self bytes], size, MS_SYNC | MS_INVALIDATE);
}
@end
