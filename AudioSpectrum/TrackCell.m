//
//  TrackCell.m
//  AudioSpectrum
//
//  Created by sun on 2019/4/1.
//  Copyright © 2019 taihe. All rights reserved.
//

#import "TrackCell.h"

/* System */

/* ViewController */

/* View */

/* Model */

/* Util */

/* NetWork InterFace */

/* Vender */

@interface TrackCell ()
@property (weak, nonatomic) IBOutlet UILabel *trackNameLabel;
@property (weak, nonatomic) IBOutlet UIButton *playButton;

@property (nonatomic, copy) NSString *trackName;
@end
@implementation TrackCell

#if DEBUG
- (void)dealloc {
    NSLog(@"[%@ dealloc]", NSStringFromClass(self.class));
}
#endif

#pragma mark - life cycle
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self == [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
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
    self.contentView.backgroundColor = [UIColor whiteColor];
    [self addSubViews];
    [self addSubViewConstraints];
}

#pragma mark - add subview
- (void)addSubViews {

}

#pragma mark - layout
- (void)addSubViewConstraints {

}

#pragma mark - private method
- (IBAction)playOrStopTapped:(UIButton *)sender {
    !self.didClickHandler ?: self.didClickHandler();
}
#pragma mark - public method
- (void)configureWithTrackName:(NSString *)trackName playing:(BOOL)playing {
    self.trackName = trackName;
    self.trackNameLabel.text = trackName;
    self.playButton.selected = playing;
}
- (void)updateState:(BOOL)playing {
    self.playButton.selected = playing;
}
#pragma mark - getters and setters

@end
