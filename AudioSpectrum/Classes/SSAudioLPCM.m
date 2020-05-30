//
//  SSAudioLPCM.m
//  AudioSpectrum
//
//  Created by sun on 2019/4/4.
//  Copyright © 2019 taihe. All rights reserved.
//

#import "SSAudioLPCM.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
#import <os/lock.h>
#else
#import <libkern/OSAtomic.h>
#endif

#import <AvailabilityInternal.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
#define __Lock(v)                   \
    do {                            \
        if (v != NULL) {            \
            os_unfair_lock_lock(v); \
        }                           \
    } while (0)

#define __UnLock(v)                   \
    do {                              \
        if (v != NULL) {              \
            os_unfair_lock_unlock(v); \
        }                             \
    } while (0)

#else

#define __Lock(v)              \
    do {                       \
        if (v != NULL) {       \
            OSSpinLockLock(v); \
        }                      \
    } while (0)

#define __UnLock(v)              \
    do {                         \
        if (v != NULL) {         \
            OSSpinLockUnlock(v); \
        }                        \
    } while (0)

#endif

typedef struct data_segment {
    void *bytes;
    NSUInteger length;
    NSUInteger pos;
    struct data_segment *next;
} data_segment;

@implementation SSAudioLPCM {
  @private
    data_segment *_segments;
    BOOL _end;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    os_unfair_lock _lock;
#else
    OSSpinLock _lock;
#endif
}

@synthesize end = _end;

- (id)init {
    self = [super init];
    if (self) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
        _lock = OS_UNFAIR_LOCK_INIT;
#else
        _lock = OS_SPINLOCK_INIT;
#endif
    }
    return self;
}

- (void)dealloc {
    while (_segments != NULL) {
        data_segment *next = _segments->next;
        free(_segments->bytes);
        free(_segments);
        _segments = next;
    }
}

- (void)setEnd:(BOOL)end {
    __Lock(&_lock);
    if (end && !_end) {
        _end = YES;
    }
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    os_unfair_lock_unlock(&_lock);
#else
    OSSpinLockUnlock(&_lock);
#endif
}
- (void)rest {
    while (_segments != NULL) {
        data_segment *next = _segments->next;
        free(_segments->bytes);
        free(_segments);
        _segments = next;
    }
}
- (BOOL)readBytes:(void **)bytes needReadLength:(NSUInteger)needReadLength realLength:(NSUInteger *)realLength {
    *bytes      = NULL;
    *realLength = 0;

    __Lock(&_lock);

    if (_end && _segments == NULL) {
        __UnLock(&_lock);
        return NO;
    }

    if (_segments != NULL) {
        NSUInteger readLength = 0;
        *bytes                = calloc(1, needReadLength);
        while (readLength < needReadLength && _segments != NULL) {
            NSUInteger len = MIN(needReadLength - readLength, _segments->length - _segments->pos);
            memcpy(*bytes + readLength, _segments->bytes + _segments->pos, len);
            _segments->pos += len;
            readLength += len;
            if (_segments->pos >= _segments->length) {
                data_segment *next = _segments->next;
                free(_segments->bytes);
                free(_segments);
                _segments = next;
            }
        }
        *realLength = readLength;
    }
    __UnLock(&_lock);
    return YES;
}

- (void)writeBytes:(const void *)bytes length:(NSUInteger)length {
    __Lock(&_lock);

    if (_end) {
        __UnLock(&_lock);
        return;
    }

    if (bytes == NULL || length == 0) {
        __UnLock(&_lock);
        return;
    }

    data_segment *segment = (data_segment *)malloc(sizeof(data_segment));
    segment->bytes        = calloc(1, length);
    segment->length       = length;
    segment->pos          = 0;
    segment->next         = NULL;
    memcpy(segment->bytes, bytes, length);

    data_segment **link = &_segments;
    while (*link != NULL) {
        data_segment *current = *link;
        link                  = &current->next;
    }

    *link = segment;
    __UnLock(&_lock);
}
@end

