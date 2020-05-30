//
//  SpectrumView.m
//  AudioSpectrum
//
//  Created by king on 2019/3/28.
//  Copyright © 2019 taihe. All rights reserved.
//

#import "SpectrumView.h"

/* System */

/* ViewController */

/* View */

/* Model */

/* Util */

/* NetWork InterFace */

/* Vender */

#define RGB(r, g, b) [UIColor colorWithRed:(r / 255.0) green:(g / 255.0) blue:(b / 255.0) alpha:1.0]

@interface SpectrumView ()
@property (nonatomic, strong) CAGradientLayer *leftGradientLayer;
@property (nonatomic, strong) CAGradientLayer *rightGradientLayer;
@end
@implementation SpectrumView

#if DEBUG
- (void)dealloc {
    NSLog(@"[%@ dealloc]", NSStringFromClass(self.class));
}
#endif

#pragma mark - load from nib
+ (instancetype __nullable)makeFromNibWithBundle:(NSBundle *)bundle {
    if (!bundle) bundle = [NSBundle mainBundle];
    NSArray *objs = [[NSBundle mainBundle] loadNibNamed:NSStringFromClass(self.class) owner:nil options:nil];
    if (!objs || objs.count == 0) return nil;
    if ([objs.firstObject isKindOfClass:self.class]) return objs.firstObject;
    return nil;
}

#pragma mark - life cycle
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self commonInit];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self commonInit];
}

#pragma mark - initial Methods
- (void)commonInit {
    /*custom view u want draw in here*/
    self.backgroundColor = [UIColor blackColor];

    self.barWidth    = 3.0;
    self.space       = 1.0;
    self.bottomSpace = 0;
    self.topSpace    = 0;

    [self addSubViews];
    [self addSubViewConstraints];
}

#pragma mark - add subview
- (void)addSubViews {

    [self.layer addSublayer:self.leftGradientLayer];
    [self.layer addSublayer:self.rightGradientLayer];
}

#pragma mark - layout
- (void)addSubViewConstraints {
}

#pragma mark - private method
- (CGFloat)translateAmplitudeToYPosition:(float)amplitude {
    CGFloat barHeight = (CGFloat)amplitude * (CGRectGetHeight(self.bounds) - self.bottomSpace - self.topSpace);
    return CGRectGetHeight(self.bounds) - self.bottomSpace - barHeight;
}
#pragma mark - public method
- (void)updateSpectra:(NSArray<NSArray<NSNumber *> *> *)spectra {
    if (spectra.count == 0) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    UIBezierPath *leftPath = [UIBezierPath bezierPath];
    NSUInteger count       = spectra.firstObject.count;
    for (int i = 0; i < count; i++) {
        CGFloat x         = (CGFloat)i * (self.barWidth + self.space) + self.space;
        CGFloat y         = [self translateAmplitudeToYPosition:spectra[0][i].floatValue];
        CGRect rect       = CGRectMake(x, y, self.barWidth, CGRectGetHeight(self.bounds) - self.bottomSpace - y);
        UIBezierPath *bar = [UIBezierPath bezierPathWithRect:rect];
        [leftPath appendPath:bar];
    }

    CAShapeLayer *leftMaskLayer  = [CAShapeLayer layer];
    leftMaskLayer.path           = leftPath.CGPath;
    self.leftGradientLayer.frame = CGRectMake(0, self.topSpace, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds) - self.topSpace - self.bottomSpace);
    self.leftGradientLayer.mask  = leftMaskLayer;

    if (spectra.count >= 2) {
        UIBezierPath *rightPath = [UIBezierPath bezierPath];
        count                   = spectra[1].count;
        for (int i = 0; i < count; i++) {
            CGFloat x         = (CGFloat)(count - 1 - i) * (self.barWidth + self.space) + self.space;
            CGFloat y         = [self translateAmplitudeToYPosition:spectra[1][i].floatValue];
            CGRect rect       = CGRectMake(x, y, self.barWidth, CGRectGetHeight(self.bounds) - self.bottomSpace - y);
            UIBezierPath *bar = [UIBezierPath bezierPathWithRect:rect];
            [rightPath appendPath:bar];
        }
        CAShapeLayer *rightMaskLayer  = [CAShapeLayer layer];
        rightMaskLayer.path           = rightPath.CGPath;
        self.rightGradientLayer.frame = CGRectMake(0, self.topSpace, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds) - self.topSpace - self.bottomSpace);
        self.rightGradientLayer.mask  = rightMaskLayer;
    }
    [CATransaction commit];
}
#pragma mark - getters and setters
- (CAGradientLayer *)leftGradientLayer {
    if (!_leftGradientLayer) {
        _leftGradientLayer        = [CAGradientLayer layer];
        _leftGradientLayer.colors = @[
            (id)RGB(52, 232, 158).CGColor,
            (id)RGB(15, 52, 67).CGColor,
        ];
        _leftGradientLayer.locations = @[@0.6, @1.0];
    }
    return _leftGradientLayer;
}
- (CAGradientLayer *)rightGradientLayer {
    if (!_rightGradientLayer) {
        _rightGradientLayer        = [CAGradientLayer layer];
        _rightGradientLayer.colors = @[
            (id)RGB(194, 21, 0).CGColor,
            (id)RGB(255, 197, 0).CGColor,
        ];
        _rightGradientLayer.locations = @[@0.6, @1.0];
    }
    return _rightGradientLayer;
}
@end

