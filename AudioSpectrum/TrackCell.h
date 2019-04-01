//
//  TrackCell.h
//  AudioSpectrum
//
//  Created by sun on 2019/4/1.
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

@protocol TrackCellDelegate;

@interface TrackCell : UITableViewCell
@property (nonatomic, strong) void(^didClickHandler)(void);
- (void)configureWithTrackName:(NSString *)trackName playing:(BOOL)playing;

- (void)updateState:(BOOL)playing;
@end



NS_ASSUME_NONNULL_END
