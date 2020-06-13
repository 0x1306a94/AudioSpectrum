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
@property (nonatomic, strong) NSMutableArray<CAShapeLayer *> *lineLayers;
@property (nonatomic, assign) CGFloat radius;
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

//    [self.layer addSublayer:self.leftGradientLayer];
//    [self.layer addSublayer:self.rightGradientLayer];
    
    //先设定大圆的半径 取长和宽最短的
    self.radius = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds)) / 2 - 50;
    //计算圆心位置
    CGPoint center      = CGPointMake(CGRectGetWidth(self.bounds) / 2, CGRectGetHeight(self.bounds) / 2);
    NSInteger itemCount = 160;
    CGFloat perAngle    = M_PI * 2 / itemCount;
    self.lineLayers     = [NSMutableArray<CAShapeLayer *> arrayWithCapacity:itemCount];
    //我们需要计算出每段弧线的起始角度和结束角度
    //这里我们从- M_PI 开始，我们需要理解与明白的是我们画的弧线与内侧弧线是同一个圆心
    for (int i = 0; i < itemCount; i++) {

        CGFloat startAngel = ((M_PI * 2) + perAngle * i);
        CGFloat endAngel   = startAngel + perAngle / 2;

        UIBezierPath *tickPath = [UIBezierPath bezierPathWithArcCenter:center radius:self.radius startAngle:startAngel endAngle:endAngel clockwise:YES];
        CAShapeLayer *perLayer = [CAShapeLayer layer];
        perLayer.fillColor     = [UIColor clearColor].CGColor;
        perLayer.strokeColor   = [UIColor redColor].CGColor;
        perLayer.anchorPoint   = CGPointMake(0.5, 1.0);
        perLayer.lineWidth     = 0;

        perLayer.path = tickPath.CGPath;
        [self.lineLayers addObject:perLayer];
        [self.layer addSublayer:perLayer];
    }

    UIView *view                                   = [[UIView alloc] init];
    view.backgroundColor                           = UIColor.blackColor;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.layer.cornerRadius                        = self.radius;
    [self addSubview:view];

    [NSLayoutConstraint activateConstraints:@[
        [view.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [view.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [view.widthAnchor constraintEqualToConstant:self.radius * 2],
        [view.heightAnchor constraintEqualToConstant:self.radius * 2],
    ]];
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
    NSUInteger count       = spectra.firstObject.count;
    if (count != self.lineLayers.count) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    for (NSUInteger i = 0; i < count; i++) {
        if (spectra.count == 2) {
            self.lineLayers[i].lineWidth = MAX(spectra[0][i].floatValue, spectra[1][i].floatValue) * 100;
        } else {
            self.lineLayers[i].lineWidth = spectra[0][i].floatValue * 100;
        }
    }
//    UIBezierPath *leftPath = [UIBezierPath bezierPath];
//    NSUInteger count       = spectra.firstObject.count;
//    for (int i = 0; i < count; i++) {
//        CGFloat x         = (CGFloat)i * (self.barWidth + self.space) + self.space;
//        CGFloat y         = [self translateAmplitudeToYPosition:spectra[0][i].floatValue];
//        CGRect rect       = CGRectMake(x, y, self.barWidth, CGRectGetHeight(self.bounds) - self.bottomSpace - y);
//        UIBezierPath *bar = [UIBezierPath bezierPathWithRect:rect];
//        [leftPath appendPath:bar];
//    }
//
//    CAShapeLayer *leftMaskLayer  = [CAShapeLayer layer];
//    leftMaskLayer.path           = leftPath.CGPath;
//    self.leftGradientLayer.frame = CGRectMake(0, self.topSpace, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds) - self.topSpace - self.bottomSpace);
//    self.leftGradientLayer.mask  = leftMaskLayer;
//
//    if (spectra.count >= 2) {
//        UIBezierPath *rightPath = [UIBezierPath bezierPath];
//        count                   = spectra[1].count;
//        for (int i = 0; i < count; i++) {
//            CGFloat x         = (CGFloat)(count - 1 - i) * (self.barWidth + self.space) + self.space;
//            CGFloat y         = [self translateAmplitudeToYPosition:spectra[1][i].floatValue];
//            CGRect rect       = CGRectMake(x, y, self.barWidth, CGRectGetHeight(self.bounds) - self.bottomSpace - y);
//            UIBezierPath *bar = [UIBezierPath bezierPathWithRect:rect];
//            [rightPath appendPath:bar];
//        }
//        CAShapeLayer *rightMaskLayer  = [CAShapeLayer layer];
//        rightMaskLayer.path           = rightPath.CGPath;
//        self.rightGradientLayer.frame = CGRectMake(0, self.topSpace, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds) - self.topSpace - self.bottomSpace);
//        self.rightGradientLayer.mask  = rightMaskLayer;
//    }
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

