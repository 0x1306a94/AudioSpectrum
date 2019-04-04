//
//  SSAudioDecoder.m
//  AudioSpectrum
//
//  Created by sun on 2019/4/3.
//  Copyright © 2019 taihe. All rights reserved.
//

#import "SSAudioDecoder.h"
#import "SSAudioFile.h"
#import "SSAudioFileProvider.h"
#import "SSAudioCommon.h"
#import "SSAudioLPCM.h"

#define BitRateEstimationMaxPackets 5000
#define BitRateEstimationMinPackets 10

#define kDefaultBufferByteCount  35280

@interface SSAudioDecoder ()
@property (nonatomic, strong) SSAudioFileProvider *fileProvider;
@property (nonatomic, assign) AudioFileTypeID fileType;
@property (nonatomic, assign) unsigned long long fileSize;
/** 是否正在解码中 */
@property (atomic, assign) BOOL decoding;
/** 解码到音频数据 */
@property (nonatomic, assign) BOOL readyToProducePackets;
/** 是否已经解码完成 */
@property (nonatomic, assign) BOOL finishing;

/** 已读数据长度 */
@property (nonatomic, assign) NSUInteger readDataOffset;

@property (nonatomic, strong) SSAudioLPCM *lpcm;
@end

@implementation SSAudioDecoder
{
    /** 是否连续 */
    BOOL _discontinuous;
    AudioFileStreamID _audioFileStreamID;
    AudioStreamBasicDescription _asdb;
    /** 转码器 */
    AudioConverterRef _audioConverter;
    /** 数据偏移量 */
    SInt64 _dataOffset;
    NSTimeInterval _packetDuration;

    UInt64 _processedPacketsCount;
    UInt64 _processedPacketsSizeTotal;
    /** 音频码率 */
    UInt32 _bitRate;
    UInt32 _maxPacketSize;
    /** 音频数据量 */
    UInt64 _audioDataByteCount;

    UInt64 _decodeCount;
    NSUInteger _bufferTime;
    NSUInteger _bufferByteCount;
    struct {
        unsigned int didAsbd: 1;
        unsigned int didReady: 1;
        unsigned int didReadyPlay: 1;
    } __delegateFlag;
}

@synthesize asdb = _asdb;
@synthesize bitRate = _bitRate;
@synthesize maxPacketSize = _maxPacketSize;
@synthesize audioDataByteCount = _audioDataByteCount;

static void __ss_AudioFileStream_PropertyListenerProc__(void *                            inClientData,
                                                        AudioFileStreamID                inAudioFileStream,
                                                        AudioFileStreamPropertyID        inPropertyID,
                                                        AudioFileStreamPropertyFlags *    ioFlags)
{
    SSAudioDecoder *decoder = (__bridge SSAudioDecoder *)inClientData;
    [decoder handlePropertyChangeForFileStream:inAudioFileStream
                          fileStreamPropertyID:inPropertyID
                                       ioFlags:ioFlags];
}

static void __ss_AudioFileStream_PacketsProc__(void *                            inClientData,
                                               UInt32                            inNumberBytes,
                                               UInt32                            inNumberPackets,
                                               const void *                    inInputData,
                                               AudioStreamPacketDescription    *inPacketDescriptions)
{
    SSAudioDecoder *decoder = (__bridge SSAudioDecoder *)inClientData;
    [decoder handleAudioPackets:inInputData
                    numberBytes:inNumberBytes
                  numberPackets:inNumberPackets
             packetDescriptions:inPacketDescriptions];
}

static OSStatus __ss_decoder_data_proc__(AudioConverterRef inAudioConverter,
                                         UInt32 *ioNumberDataPackets,
                                         AudioBufferList *ioData,
                                         AudioStreamPacketDescription **outDataPacketDescription,
                                         void *inUserData)
{
    AudioBufferList audioBufferList = *(AudioBufferList *)inUserData;
    ioData->mBuffers[0].mData = audioBufferList.mBuffers[0].mData;
    ioData->mBuffers[0].mDataByteSize = audioBufferList.mBuffers[0].mDataByteSize;
    return noErr;
}
+ (NSThread *)decoderThread {
    static NSThread *thread = nil;
    if (thread) return thread;
    thread = [[NSThread alloc] initWithTarget:self selector:@selector(decoderThreadRun) object:nil];
    thread.name = @"com.0x1306a94.audio.decoder.thread";
    [thread start];
    return thread;
}
+ (void)decoderThreadRun {
    @autoreleasepool {
        //只要往RunLoop中添加了  timer、source或者observer就会继续执行，一个Run Loop通常必须包含一个输入源或者定时器来监听事件，如果一个都没有，Run Loop启动后立即退出。
        [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
        [[NSRunLoop currentRunLoop] run];
    }
}
- (instancetype)initWithFileProvider:(__kindof SSAudioFileProvider *)fileProvider {
    if (self == [super init]) {
        self.fileProvider = fileProvider;
        self.readDataOffset = 0;
        _discontinuous = NO;
        _bufferTime = 200;
        _audioConverter = NULL;
        self.lpcm = [[SSAudioLPCM alloc] init];

        self.fileSize = fileProvider.expectedLength;

        self.readyToProducePackets = NO;
        if (fileProvider.isReady) {
            NSArray *fallbackTypeIDs = ss_get_fallbackTypeIDs(fileProvider.mimeType, fileProvider.fileExtension);
            OSStatus err = noErr;
            for (id obj in fallbackTypeIDs) {
                AudioFileTypeID fileTypeHint = (AudioFileTypeID)[obj unsignedIntegerValue];
                if ((err = AudioFileStreamOpen((__bridge void *)(self), __ss_AudioFileStream_PropertyListenerProc__, __ss_AudioFileStream_PacketsProc__, fileTypeHint, &_audioFileStreamID)) == noErr) {
                    self.fileType = fileTypeHint;
                    break;
                }
            }
            if (_audioFileStreamID != NULL) {
                NSLog(@"AudioFileStreamOpen");
            }
        }
    }
    return self;
}
#pragma mark - override getter or setter
- (BOOL)available
{
    return _audioFileStreamID != NULL;
}
- (void)setDelegate:(id<SSAudioDecoderDelegate>)delegate {
    _delegate = delegate;
    __delegateFlag.didAsbd = [delegate respondsToSelector:@selector(ssAudioDecoder:didParseAudioStreamBasicDescription:)];
    __delegateFlag.didReady = [delegate respondsToSelector:@selector(ssAudioDecoderDidReadyToProducePackets:)];
    __delegateFlag.didReadyPlay = [delegate respondsToSelector:@selector(ssAudioDecoderDidReadyPlay:)];
}
#pragma mark - private method
- (void)startDecoder
{
    if (self.decoding) return;
    [self performSelector:@selector(_startDecoder) onThread:[self.class decoderThread] withObject:nil waitUntilDone:NO];
}

- (void)stopDecoder
{
    if (!self.decoding) return;
    [self performSelector:@selector(_stopDecoder) onThread:[self.class decoderThread] withObject:nil waitUntilDone:NO];
}

- (void)_startDecoder
{
    if (self.decoding) return;
    self.decoding = YES;
    while (self.decoding) {

//        if (self.readyToProducePackets) {
//            // 可以开始解析音频数据
//            if (_audioConverter == NULL) {
//                [self setupAudioConverterRef];
//                self.readDataOffset = _dataOffset;
//            }
//            NSUInteger length = MIN(4096, self.fileProvider.expectedLength - self.readDataOffset);
//
//
//            return;
//        }
        NSUInteger length = MIN(4096, self.fileProvider.expectedLength - self.readDataOffset);
        if (length == 0) break;
        NSRange range = NSMakeRange(self.readDataOffset, length);
        NSData *data = [self.fileProvider.mappedData subdataWithRange:range];
        self.readDataOffset += length;
        OSStatus err = noErr;
        AudioFileStreamParseFlags flag = (_discontinuous ? kAudioFileStreamParseFlag_Discontinuity : 0);
        err = AudioFileStreamParseBytes(_audioFileStreamID, (UInt32)length, data.bytes, flag);
        /*
         kAudioFileStreamError_UnsupportedFileType        = 'typ?',
         kAudioFileStreamError_UnsupportedDataFormat      = 'fmt?',
         kAudioFileStreamError_UnsupportedProperty        = 'pty?',
         kAudioFileStreamError_BadPropertySize            = '!siz',
         kAudioFileStreamError_NotOptimized               = 'optm',
         kAudioFileStreamError_InvalidPacketOffset        = 'pck?',
         kAudioFileStreamError_InvalidFile                = 'dta?',
         kAudioFileStreamError_ValueUnknown               = 'unk?',
         kAudioFileStreamError_DataUnavailable            = 'more',
         kAudioFileStreamError_IllegalOperation           = 'nope',
         kAudioFileStreamError_UnspecifiedError           = 'wht?',
         kAudioFileStreamError_DiscontinuityCantRecover   = 'dsc!'
         */

        switch (err) {
            case kAudioFileStreamError_UnsupportedFileType:
            {
                NSLog(@"kAudioFileStreamError_UnsupportedFileType");
                break;
            }
            case kAudioFileStreamError_UnsupportedDataFormat:
            {
                NSLog(@"kAudioFileStreamError_UnsupportedDataFormat");
                break;
            }
            case kAudioFileStreamError_UnsupportedProperty:
            {
                NSLog(@"kAudioFileStreamError_UnsupportedProperty");
                break;
            }
            case kAudioFileStreamError_BadPropertySize:
            {
                NSLog(@"kAudioFileStreamError_BadPropertySize");
                break;
            }
            case kAudioFileStreamError_NotOptimized:
            {
                NSLog(@"kAudioFileStreamError_NotOptimized");
                break;
            }
            case kAudioFileStreamError_InvalidPacketOffset:
            {
                NSLog(@"kAudioFileStreamError_InvalidPacketOffset");
                break;
            }
            case kAudioFileStreamError_InvalidFile:
            {
                NSLog(@"kAudioFileStreamError_InvalidFile");
                break;
            }
            case kAudioFileStreamError_ValueUnknown:
            {
                NSLog(@"kAudioFileStreamError_ValueUnknown");
                break;
            }
            case kAudioFileStreamError_DataUnavailable:
            {
                NSLog(@"kAudioFileStreamError_DataUnavailable");
                break;
            }
            case kAudioFileStreamError_IllegalOperation:
            {
                NSLog(@"kAudioFileStreamError_IllegalOperation");
                break;
            }
            case kAudioFileStreamError_UnspecifiedError:
            {
                NSLog(@"kAudioFileStreamError_UnspecifiedError");
                break;
            }
            case kAudioFileStreamError_DiscontinuityCantRecover:
            {
                NSLog(@"kAudioFileStreamError_DiscontinuityCantRecover");
                break;
            }
            default:
                break;
        }
        if (err != noErr) {
            NSLog(@"解码发生错误,中断解码....");
            break;
        }
    }
    self.decoding = NO;
    NSLog(@"解码完成...");
}

- (void)_stopDecoder
{
    if (!self.decoding) return;
    self.decoding = NO;
}
- (void)setupAudioConverterRef {
    AudioConverterRef audioConverter;
    memset(&audioConverter, 0, sizeof(audioConverter));
    AudioStreamBasicDescription outAsbd = [self.class defaultOutputFormat];
    OSStatus err = AudioConverterNew(&_asdb, &outAsbd, &audioConverter);
    if (err != noErr) {
        NSLog(@"%@", ss_OSStatusToString(err));
        return;
    }
    _audioConverter = audioConverter;
}

- (void)calculateBitRate
{
    if (_packetDuration && _processedPacketsCount > BitRateEstimationMinPackets && _processedPacketsCount <= BitRateEstimationMaxPackets) {
        double averagePacketByteSize = _processedPacketsSizeTotal / _processedPacketsCount;
        _bitRate = 8.0 * averagePacketByteSize / _packetDuration;
    }
}

- (void)calculateDuration
{
    if (_fileSize > 0 && _bitRate > 0) {
        _duration = ((_fileSize - _dataOffset) * 8.0) / _bitRate;
    }
}

- (void)calculatepPacketDuration
{
    if (_asdb.mSampleRate > 0) {
        _packetDuration = _asdb.mFramesPerPacket / _asdb.mSampleRate;
    }
}
- (void)handlePropertyChangeForFileStream:(AudioFileStreamID)inAudioFileStream
                     fileStreamPropertyID:(AudioFileStreamPropertyID)inPropertyID
                                  ioFlags:(UInt32 *)ioFlags
{
    @synchronized (self) {
        if (self.finishing) return;
        OSStatus err = noErr;
        switch (inPropertyID) {
            case kAudioFileStreamProperty_ReadyToProducePackets:
            {
//                [self setupAudioConverterRef];
                _discontinuous = YES;
                self.readyToProducePackets = YES;
                UInt32 sizeOfUInt32 = sizeof(_maxPacketSize);
                err = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_PacketSizeUpperBound, &sizeOfUInt32, &_maxPacketSize);
                if (err != noErr || _maxPacketSize == 0) {
                    err = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_MaximumPacketSize, &sizeOfUInt32, &_maxPacketSize);
                }
                ss_call_main_thread(^{
                    if (self->__delegateFlag.didReady) {
                        [self.delegate ssAudioDecoderDidReadyToProducePackets:self];
                    }
                });
                break;
            }
            case kAudioFileStreamProperty_BitRate:
            {
                UInt32 size = sizeof(UInt32);
                if ((err = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_BitRate, &size, &_bitRate)) != noErr) {

                    return;
                }
                [self calculateDuration];
                break;
            }
            case kAudioFileStreamProperty_DataOffset:
            {
                UInt32 offsetSize = sizeof(SInt64);
                if ((err = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_DataOffset, &offsetSize, &_dataOffset)) != noErr) {

                    return;
                }
                [self calculateDuration];
                break;
            }
            case kAudioFileStreamProperty_AudioDataByteCount:
            {
                UInt32 byteCountSize = sizeof(UInt64);
                if ((err = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_AudioDataByteCount, &byteCountSize, &_audioDataByteCount)) != noErr) {

                    return;
                }
                break;
            }
            case kAudioFileStreamProperty_DataFormat:
            {
                UInt32 formatSize = sizeof(_asdb);
                if ((err = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_DataFormat, &formatSize, &_asdb)) != noErr) {

                    return;
                }
                if ([self.class isInterleaved:_asdb]) {
                    NSLog(@"interleaved");
                }
                if ([self.class isFloatFormat:_asdb]) {
                    NSLog(@"float data");
                } else {
                    NSLog(@"no float data");
                }
                _bufferByteCount = (_bufferTime * _asdb.mSampleRate / 1000) * (_asdb.mChannelsPerFrame * _asdb.mBitsPerChannel / 8);
                _bufferByteCount = MAX(_bufferByteCount, kDefaultBufferByteCount);
                ss_call_main_thread(^{
                    if (self->__delegateFlag.didAsbd) {
                        [self.delegate ssAudioDecoder:self didParseAudioStreamBasicDescription:_asdb];
                    }
                });
                [self calculatepPacketDuration];
                break;
            }
            case kAudioFileStreamProperty_FormatList:
            {
                Boolean outWriteable;
                UInt32 formatListSize;
                if ((err = AudioFileStreamGetPropertyInfo(_audioFileStreamID, kAudioFileStreamProperty_FormatList, &formatListSize, &outWriteable) != noErr)) {

                    return;
                }

                AudioFormatListItem *formatList = (AudioFormatListItem *)calloc(1, formatListSize);
                if ((err = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_FormatList, &formatListSize, formatList)) != noErr) {

                    free(formatList);
                    return;
                }

                UInt32 supportedFormatsSize;
                if ((err = AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize)) != noErr) {

                    free(formatList);
                    return;
                }

                UInt32 supportedFormatCount = supportedFormatsSize / sizeof(OSType);
                OSType *supportedFormats = (OSType *)malloc(supportedFormatsSize);
                if ((err = AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize, supportedFormats)) != noErr) {
                    free(formatList);
                    free(supportedFormats);
                    return;
                }

                BOOL flag = NO;
                for (int i = 0; i * sizeof(AudioFormatListItem); i += sizeof(AudioFormatListItem)) {
                    AudioStreamBasicDescription asbd = formatList[i].mASBD;
                    for (UInt32 j = 0; j < supportedFormatCount; j++) {
                        if (asbd.mFormatID == supportedFormats[j]) {
                            _asdb = asbd;
                            if ([self.class isInterleaved:asbd]) {
                                NSLog(@"interleaved");
                            }
                            if ([self.class isFloatFormat:asbd]) {
                                NSLog(@"float data");
                            } else {
                                NSLog(@"no float data");
                            }
                            flag = YES;
                            [self calculatepPacketDuration];
                            _bufferByteCount = (_bufferTime * _asdb.mSampleRate / 1000) * (_asdb.mChannelsPerFrame * _asdb.mBitsPerChannel / 8);
                            _bufferByteCount = MAX(_bufferByteCount, kDefaultBufferByteCount);
                            ss_call_main_thread(^{
                                if (self->__delegateFlag.didAsbd) {
                                    [self.delegate ssAudioDecoder:self didParseAudioStreamBasicDescription:asbd];
                                }
                            });
                            break;
                        }
                    }
                    if (flag) {
                        break;
                    }
                }
                free(formatList);
                free(supportedFormats);
                break;
            }
            default:
                break;
        }
    }

}

- (void)handleAudioPackets:(const void *)inInputData
               numberBytes:(UInt32)inNumberBytes
             numberPackets:(UInt32)inNumberPackets
        packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions
{
    @synchronized (self) {
        if (_discontinuous) {
            _discontinuous = NO;
        }

        if (inNumberBytes == 0 || inNumberPackets == 0) {
            [self.lpcm setEnd:YES];
            return;
        }
        NSLog(@"解码数据: %lu ->> %lu", self.fileProvider.expectedLength, self.readDataOffset);
        BOOL deletePackDesc = NO;
        if (inPacketDescriptions == NULL) {
            //如果packetDescriptioins不存在，就按照CBR处理，平均每一帧的数据后生成packetDescriptioins
            deletePackDesc = YES;
            UInt32 packetSize = inNumberBytes / inNumberPackets;
            inPacketDescriptions = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * inNumberPackets);

            for (int i = 0; i < inNumberPackets; i++) {
                UInt32 packetOffset = packetSize * i;
                inPacketDescriptions[i].mStartOffset = packetOffset;
                inPacketDescriptions[i].mVariableFramesInPacket = 0;
                if (i == inNumberPackets - 1) {
                    inPacketDescriptions[i].mDataByteSize = inNumberBytes - packetOffset;
                } else {
                    inPacketDescriptions[i].mDataByteSize = packetSize;
                }
            }
        }

        for (int i = 0; i < inNumberPackets; ++i) {

            AudioStreamPacketDescription aspd = inPacketDescriptions[i];
            SInt64 packetOffset = aspd.mStartOffset;
            /*

            //设置输入
            AudioBufferList inAaudioBufferList;
            inAaudioBufferList.mNumberBuffers = 1;
            inAaudioBufferList.mBuffers[0].mNumberChannels = 2;
            inAaudioBufferList.mBuffers[0].mDataByteSize = aspd.mDataByteSize;
            inAaudioBufferList.mBuffers[0].mData = calloc(1, aspd.mDataByteSize);
            memcpy(inAaudioBufferList.mBuffers[0].mData, (inInputData + packetOffset), aspd.mDataByteSize);

            //设置输出
            void *buffer = (void *)malloc(aspd.mDataByteSize);
            memset(buffer, 0, aspd.mDataByteSize);
            AudioBufferList outAudioBufferList;
            outAudioBufferList.mNumberBuffers = 1;
            outAudioBufferList.mBuffers[0].mNumberChannels = inAaudioBufferList.mBuffers[0].mNumberChannels;
            outAudioBufferList.mBuffers[0].mDataByteSize = aspd.mDataByteSize;
            outAudioBufferList.mBuffers[0].mData = buffer;

            UInt32 ioOutputDataPacketSize = 1;

            OSStatus err = AudioConverterFillComplexBuffer(_audioConverter,
                                                           __ss_decoder_data_proc__,
                                                           &inAaudioBufferList,
                                                           &ioOutputDataPacketSize,
                                                           &outAudioBufferList,
                                                           NULL);
            if (err != noErr) {
                NSLog(@"%@", ss_OSStatusToString(err));
                return;
            }
            _decodeCount += aspd.mDataByteSize;
            [self.lpcm writeBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
             */
            _decodeCount += aspd.mDataByteSize;
            [self.lpcm writeBytes:(inInputData + packetOffset) length:aspd.mDataByteSize];
            if (_processedPacketsCount < BitRateEstimationMaxPackets)
            {
                _processedPacketsSizeTotal += aspd.mDataByteSize;
                _processedPacketsCount += 1;
                [self calculateBitRate];
                [self calculateDuration];


            }
        }
        if (_decodeCount >= _bufferByteCount) {
            ss_call_main_thread(^{
                if (__delegateFlag.didReadyPlay) {
                    [self.delegate ssAudioDecoderDidReadyPlay:self];
                }
            });
        }

        if (deletePackDesc) {
            free(inPacketDescriptions);
        }

        if (self.readDataOffset >= self.fileProvider.expectedLength) {
            [self.lpcm setEnd:YES];
        }
    }
}

#pragma mark - public method
+ (AudioStreamBasicDescription)defaultOutputFormat
{
    static AudioStreamBasicDescription defaultOutputFormat;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultOutputFormat.mFormatID = kAudioFormatLinearPCM;
        defaultOutputFormat.mSampleRate = 44100;

        defaultOutputFormat.mBitsPerChannel = 16;
        defaultOutputFormat.mChannelsPerFrame = 2;
        defaultOutputFormat.mBytesPerFrame = defaultOutputFormat.mChannelsPerFrame * (defaultOutputFormat.mBitsPerChannel / 8);

        defaultOutputFormat.mFramesPerPacket = 1;
        defaultOutputFormat.mBytesPerPacket = defaultOutputFormat.mFramesPerPacket * defaultOutputFormat.mBytesPerFrame;

        defaultOutputFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    });

    return defaultOutputFormat;
}
- (SInt64)seekToTime:(NSTimeInterval *)time
{
    SInt64 approximateSeekOffset = _dataOffset + (*time / _duration) * _audioDataByteCount;
    SInt64 seekToPacket = floor(*time / _packetDuration);
    SInt64 seekByteOffset;
    UInt32 ioFlags = 0;
    SInt64 outDataByteOffset;
    OSStatus status = AudioFileStreamSeek(_audioFileStreamID, seekToPacket, &outDataByteOffset, &ioFlags);
    if (status == noErr && !(ioFlags & kAudioFileStreamSeekFlag_OffsetIsEstimated))
    {
        *time -= ((approximateSeekOffset - _dataOffset) - outDataByteOffset) * 8.0 / _bitRate;
        seekByteOffset = outDataByteOffset + _dataOffset;
    }
    else
    {
        _discontinuous = YES;
        seekByteOffset = approximateSeekOffset;
    }
    return seekByteOffset;
}
- (NSData *)fetchMagicCookie
{
    UInt32 cookieSize;
    Boolean writable;
    OSStatus status = AudioFileStreamGetPropertyInfo(_audioFileStreamID, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
    if (status != noErr)
    {
        return nil;
    }

    void *cookieData = malloc(cookieSize);
    status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
    if (status != noErr)
    {
        return nil;
    }

    NSData *cookie = [NSData dataWithBytes:cookieData length:cookieSize];
    free(cookieData);

    return cookie;
}
//------------------------------------------------------------------------------

+ (BOOL)isFloatFormat:(AudioStreamBasicDescription)asbd
{
    return asbd.mFormatFlags & kAudioFormatFlagIsFloat;
}

//------------------------------------------------------------------------------

+ (BOOL)isInterleaved:(AudioStreamBasicDescription)asbd
{
    return !(asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved);
}

//------------------------------------------------------------------------------

+ (BOOL)isLinearPCM:(AudioStreamBasicDescription)asbd
{
    return asbd.mFormatID == kAudioFormatLinearPCM;
}
@end
