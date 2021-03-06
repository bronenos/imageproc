//
//  ViewController.h
//  ImageProc
//
//  Created by Stan Potemkin on 4/20/13.
//  Copyright (c) 2013 Stan Potemkin. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface ViewController : UIViewController
@property(nonatomic, retain) IBOutlet UIImageView *originalImageView;
@property(nonatomic, retain) IBOutlet UIImageView *coregraphImageView;
@property(nonatomic, retain) IBOutlet UILabel *coregraphTime;
@property(nonatomic, retain) IBOutlet UIImageView *accelerateImageView;
@property(nonatomic, retain) IBOutlet UILabel *accelerateTime;
@property(nonatomic, retain) IBOutlet UIToolbar *menuToolbar;
@property(nonatomic, retain) IBOutlet UIBarButtonItem *counterBarItem;
@property(nonatomic, retain) IBOutlet UIBarButtonItem *switcherBarItem;

- (IBAction)onSwitcher:(UISwitch *)sender;

- (void)doScale;
- (void)doRotate;
- (void)doFlip;
- (void)doBlur;
@end
