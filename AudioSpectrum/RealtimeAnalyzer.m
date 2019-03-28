//
//  RealtimeAnalyzer.m
//  AudioSpectrum
//
//  Created by king on 2019/3/27.
//  Copyright © 2019 taihe. All rights reserved.
//

#import "RealtimeAnalyzer.h"

typedef struct {
    float lowerFrequency;
    float upperFrequency;
} __Bands;

/** 频带数量 */
static int const kFrequencyBands = 80;
/** 起始帧率 */
static float const kStartFrequency = 100.0;
/** 截止帧率 */
static float const kEndFrequency = 18000.0;

@interface RealtimeAnalyzer ()
@property (nonatomic, assign) int fftSize;
@property (nonatomic, assign) FFTSetup fftSetup;

@property (nonatomic, strong) NSMutableArray<NSMutableArray<NSNumber *> *> *spectrumBuffer;

@property (nonatomic, assign) __Bands *bands;

@end
@implementation RealtimeAnalyzer
- (void)dealloc {
    if (self.fftSetup != NULL) {
        vDSP_destroy_fftsetup(self.fftSetup);
        self.fftSetup = NULL;
    }
}
- (instancetype)initWithFFTSize:(int)fftSize {
    if (self == [super init]) {
        _fftSize = fftSize;
        _spectrumSmooth = 0.5;
        _spectrumBuffer = NULL;
        _bands = NULL;
        _fftSetup = vDSP_create_fftsetup(round(log2(fftSize)), kFFTRadix2);
        
        self.spectrumBuffer = [NSMutableArray<NSMutableArray<NSNumber *> *> array];
        for (NSUInteger i = 0; i < 2; i++) {
            NSMutableArray<NSNumber *> *arr = [NSMutableArray<NSNumber *> array];
            for (int j = 0; j < kFrequencyBands; j++) {
                [arr addObject: [NSNumber numberWithFloat:0.0]];
            }
            [self.spectrumBuffer addObject:arr];
        }
    }
    return self;
}

#pragma mark - override getter or setter
- (void)setSpectrumSmooth:(float)spectrumSmooth {
    _spectrumSmooth = MAX(0.0, spectrumSmooth);
    _spectrumSmooth = MIN(1.0, _spectrumSmooth);
}
- (__Bands *)bands {
    if (_bands == NULL) {
        __Bands tmpBands[kFrequencyBands];
        float n = log2f(kEndFrequency / kStartFrequency) / (kFrequencyBands * 1.0);
        __Bands nextBand = (__Bands){kStartFrequency, 0};
        for (int i = 1; i <= kFrequencyBands; i++) {
            float highFrequency = nextBand.lowerFrequency * powf(2, n);
            float upperFrequency = i == kFrequencyBands ? kEndFrequency : highFrequency;
            tmpBands[i - 1] = (__Bands){nextBand.lowerFrequency, upperFrequency};
            nextBand.lowerFrequency = highFrequency;
        }
        _bands = tmpBands;
    }
    return _bands;
}
#pragma mark - privte method
- (float)findMaxAmplitude:(__Bands)band amplitudes:(NSArray<NSNumber *> *)amplitudes bandWidth:(float)bandWidth {
    NSUInteger amplitudesCount = amplitudes.count;
    NSUInteger startIndex = (NSUInteger)(round(band.lowerFrequency / bandWidth));
    NSUInteger endIndex = MIN((NSUInteger)(round(band.upperFrequency / bandWidth)), amplitudesCount - 1);
    if (startIndex >= amplitudesCount || endIndex >= amplitudesCount) return 0;
    float max = amplitudes[startIndex].floatValue;
    for (NSUInteger idx = startIndex; idx <= endIndex; idx++) {
        if (max < amplitudes[idx].floatValue) {
            max = amplitudes[idx].floatValue;
        }
    }
    return max;
}
- (NSArray<NSNumber *> *)createFrequencyWeights {
    float Δf = 44100.0 / (float)self.fftSize;
    int bins = self.fftSize / 2;
    
    float f[bins];
    for (int i = 0; i < bins; i++) {
        f[i] = (1.0 * i ) * Δf;
        f[i] = f[i] * f[i];
    }
    
    float c1 = powf(12194.217, 2.0);
    float c2 = powf(20.598997, 2.0);
    float c3 = powf(107.65265, 2.0);
    float c4 = powf(737.86223, 2.0);
    
    float num[bins];
    float den[bins];
    NSMutableArray<NSNumber *> *weightsArray = [NSMutableArray<NSNumber *> arrayWithCapacity:bins];
    for (int i = 0; i < bins; i++) {
        num[i] = c1 * f[i] * f[i];
        den[i] = (f[i] + c2) * sqrtf((f[i] + c3) * (f[i] + c4)) * (f[i] + c1);
        float weights = 1.2589 * num[i] / den[i];
        [weightsArray addObject: [NSNumber numberWithFloat:weights]];
    }
    return weightsArray.copy;
}
- (NSArray<NSNumber *> *)highlightWaveform:(NSArray<NSNumber *> *)spectrum {
    
    //1: 定义权重数组，数组中间的5表示自己的权重
    //   可以随意修改，个数需要奇数
    float weights[7] = {1, 2, 3, 5, 3, 2, 1};
    float totalWeights = 0;
    for (int i = 0; i < 7; i++) {
        totalWeights += weights[i];
    }
    int startIndex = 7 / 2;
    //2: 开头几个不参与计算
    NSMutableArray<NSNumber *> *averagedSpectrum = [NSMutableArray<NSNumber *> array];
    
    NSUInteger spectrumCount = spectrum.count;
    for (NSUInteger i = 0; i < startIndex; i++) {
        [averagedSpectrum addObject:spectrum[i]];
    }
    
    for (int i = startIndex; i < (spectrumCount - startIndex); i++) {
        //3: zip作用: zip([a,b,c], [x,y,z]) -> [(a,x), (b,y), (c,z)]
        int count = MIN(((i + startIndex) - (i - startIndex) + 1), 7);
        int zipOneIdx = (i - startIndex);
        float total = 0;
        for (int j = 0; j < count; j++) {
            total += spectrum[zipOneIdx].floatValue * weights[j];
            zipOneIdx++;
        }
        float averaged = total / totalWeights;
        [averagedSpectrum addObject: [NSNumber numberWithFloat:averaged]];
        
    }
    //4：末尾几个不参与计算
    NSUInteger idx = (spectrumCount - startIndex);
    for (NSUInteger i = idx; i < spectrumCount; i++) {
        [averagedSpectrum addObject:spectrum[i]];
    }
    return averagedSpectrum.copy;
}
- (NSArray<NSArray<NSNumber *> *> *)fft:(AVAudioPCMBuffer *)buffer {
    //1：抽取buffer中的样本数据
    float *const *floatChannelData = buffer.floatChannelData;
    float **channels = floatChannelData;
    
    AVAudioChannelCount channelCount = buffer.format.channelCount;
    BOOL isInterleaved = buffer.format.isInterleaved;
    NSMutableArray<NSArray<NSNumber *> *> *amplitudes = [NSMutableArray<NSArray<NSNumber *> *> array];
    if (isInterleaved) {
        // deinterleave
        float interleavedData[self.fftSize * channelCount];
        memcpy(interleavedData, floatChannelData[0], self.fftSize * channelCount);
        float *channelsTemp[channelCount];
        for (int i = 0; i < channelCount; i++) {
            int count = 0;
            for (int j = i; j < (self.fftSize * channelCount); j += channelCount) {
                count++;
            }
            float channelData[count];
            int idx = 0;
            for (int j = i; j < (self.fftSize * channelCount); j += channelCount) {
                channelData[idx] = interleavedData[j];
                idx++;
            }
            channelsTemp[i] = channelData;
        }
        channels = channelsTemp;
    }
    // 傅里叶变换
    for (int i = 0; i < channelCount; i++) {
        float *channel = channels[i];
        //2: 加汉宁窗
        float window[self.fftSize];
        vDSP_hamm_window(window, self.fftSize, vDSP_HANN_DENORM);
        vDSP_vmul(channel, 1, window, 1, channel, 1, self.fftSize);
        //3: 将实数包装成FFT要求的复数fftInOut，既是输入也是输出
        float reap[self.fftSize / 2];
        float imap[self.fftSize / 2];
        DSPSplitComplex fftInOut = (DSPSplitComplex){reap, imap};
        DSPComplex complex[self.fftSize / sizeof(DSPComplex)];
        memcpy(complex, channel, self.fftSize);
        vDSP_ctoz(complex, 2, &fftInOut, 1, self.fftSize / 2);
        //4：执行FFT
        vDSP_fft_zip(self.fftSetup, &fftInOut, 1, round(log2(self.fftSize)), FFT_FORWARD);
        //5：调整FFT结果，计算振幅
        fftInOut.imagp[0] = 0;
        float fftNormFactor = 1.0 / (self.fftSize * 1.0);
        vDSP_vsmul(fftInOut.realp, 1, &fftNormFactor, fftInOut.realp, 1, self.fftSize / 2);
        vDSP_vsmul(fftInOut.imagp, 1, &fftNormFactor, fftInOut.imagp, 1, self.fftSize / 2);
        float channelAmplitudes[self.fftSize / 2];
        vDSP_zvabs(&fftInOut, 1, channelAmplitudes, 1, self.fftSize / 2);
        channelAmplitudes[0] = channelAmplitudes[0] / 2;
        int count = self.fftSize / 2;
        NSMutableArray<NSNumber *> *arry = [NSMutableArray<NSNumber *> array];
        for (NSUInteger c = 0; c < count; c++) {
            float val = channelAmplitudes[c];
            [arry addObject: [NSNumber numberWithFloat:val]];
        }
        [amplitudes addObject:arry.copy];
    }
    return amplitudes.copy;
}

#pragma mark - public method
- (NSArray<NSArray<NSNumber *> *> *)analyse:(AVAudioPCMBuffer *)buffer {
    NSArray<NSArray<NSNumber *> *> *channelsAmplitudes = [self fft:buffer];
    NSArray<NSNumber *> *aWeights = [self createFrequencyWeights];
    
    NSUInteger count = channelsAmplitudes.count;
    for (int i = 0; i < count; i++) {
        NSArray<NSNumber *> *amplitudes = channelsAmplitudes[i];
        int subCount = self.fftSize / 2;
        NSMutableArray<NSNumber *> *weightedAmplitudes = [NSMutableArray<NSNumber *> array];
        for (int j = 0; j < subCount; j++) {
            float weighted = amplitudes[j].floatValue * aWeights[j].floatValue;
            [weightedAmplitudes addObject: [NSNumber numberWithFloat:weighted]];
        }
        
        NSMutableArray<NSNumber *> *spectrum = [NSMutableArray<NSNumber *> array];
        for (int t = 0; t < kFrequencyBands; t++) {
            float bandWidth = (float)buffer.format.sampleRate / (float)(self.fftSize * 1.0);
            float result = [self findMaxAmplitude:self.bands[t] amplitudes:weightedAmplitudes.copy bandWidth:bandWidth] * 5.0;
            [spectrum addObject: [NSNumber numberWithFloat:result]];
        }
        
        spectrum = [self highlightWaveform:spectrum];
        
        for (int t = 0; t < kFrequencyBands; t++) {
            float oldVal = self.spectrumBuffer[i][t].floatValue;
            oldVal = isnan(oldVal) ? 0 : oldVal;
            
            float newVal = spectrum[t].floatValue;
            newVal = isnan(newVal) ? 0 : newVal;
            
            float result = oldVal * self.spectrumSmooth + newVal * (1.0 - self.spectrumSmooth);
            self.spectrumBuffer[i][t] = [NSNumber numberWithFloat:(isnan(result) ? 0 : result)];
        }
    }
    return self.spectrumBuffer.copy;
}
@end
