//
//  SSAudioCommon.m
//  AudioSpectrum
//
//  Created by sun on 2019/4/3.
//  Copyright © 2019 taihe. All rights reserved.
//

#import "SSAudioCommon.h"

NSArray *ss_get_fallbackTypeIDs(NSString *mimeType, NSString *fileExtension) {
    if (mimeType.length == 0 || fileExtension.length == 0) return nil;

    NSMutableArray *fallbackTypeIDs = [NSMutableArray array];
    NSMutableSet *fallbackTypeIDSet = [NSMutableSet set];

    struct {
        CFStringRef specifier;
        AudioFilePropertyID propertyID;
    } properties[] = {
        {(__bridge CFStringRef)mimeType, kAudioFileGlobalInfo_TypesForMIMEType},
        {(__bridge CFStringRef)fileExtension, kAudioFileGlobalInfo_TypesForExtension}};

    const size_t numberOfProperties = sizeof(properties) / sizeof(properties[0]);

    for (size_t i = 0; i < numberOfProperties; ++i) {
        if (properties[i].specifier == NULL) {
            continue;
        }

        UInt32 outSize = 0;
        OSStatus status;

        status = AudioFileGetGlobalInfoSize(properties[i].propertyID,
                                            sizeof(properties[i].specifier),
                                            &properties[i].specifier,
                                            &outSize);
        if (status != noErr) {
            continue;
        }

        size_t count            = outSize / sizeof(AudioFileTypeID);
        AudioFileTypeID *buffer = (AudioFileTypeID *)malloc(outSize);
        if (buffer == NULL) {
            continue;
        }

        status = AudioFileGetGlobalInfo(properties[i].propertyID,
                                        sizeof(properties[i].specifier),
                                        &properties[i].specifier,
                                        &outSize,
                                        buffer);
        if (status != noErr) {
            free(buffer);
            continue;
        }

        for (size_t j = 0; j < count; ++j) {
            NSNumber *tid = [NSNumber numberWithUnsignedLong:buffer[j]];
            if ([fallbackTypeIDSet containsObject:tid]) {
                continue;
            }

            [fallbackTypeIDs addObject:tid];
            [fallbackTypeIDSet addObject:tid];
        }

        free(buffer);
    }

    return fallbackTypeIDs;
}

void ss_call_main_thread(dispatch_block_t block) {
    if (!block) return;
    if (NSThread.currentThread.isMainThread) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

NSString *ss_OSStatusToString(OSStatus status) {
    size_t len = sizeof(UInt32);
    long addr  = (unsigned long)&status;
    char cstring[5];

    len = (status >> 24) == 0 ? len - 1 : len;
    len = (status >> 16) == 0 ? len - 1 : len;
    len = (status >> 8) == 0 ? len - 1 : len;
    len = (status >> 0) == 0 ? len - 1 : len;

    addr += (4 - len);

    status = EndianU32_NtoB(status);  // strings are big endian

    strncpy(cstring, (char *)addr, len);
    cstring[len] = 0;

    return [NSString stringWithCString:(char *)cstring encoding:NSMacOSRomanStringEncoding];
}

