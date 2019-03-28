//
//  SpectrumView.h
//  AudioSpectrum
//
//  Created by king on 2019/3/28.
//  Copyright © 2019 taihe. All rights reserved.
//

#import <UIKit/UIKit.h>

/* System */

/* ViewController */

/* View */

/* Model */

/* Util */

/* NetWork InterFace */

/* Vender */

NS_ASSUME_NONNULL_BEGIN

@interface SpectrumView : UIView
@property (nonatomic, assign) CGFloat barWidth;
@property (nonatomic, assign) CGFloat space;
@property (nonatomic, assign) CGFloat bottomSpace;
@property (nonatomic, assign) CGFloat topSpace;
- (void)updateSpectra:(NSArray<NSArray<NSNumber *> *> *)spectra;
@end

NS_ASSUME_NONNULL_END
