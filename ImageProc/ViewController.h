//
//  ViewController.h
//  ImageProc
//
//  Created by Stan Potemkin on 4/20/13.
//  Copyright (c) 2013 Stan Potemkin. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface ViewController : UIViewController
@property(nonatomic, retain) IBOutlet UIImageView *originalImage;
@property(nonatomic, retain) IBOutlet UIImageView *coregraphImage;
@property(nonatomic, retain) IBOutlet UILabel *coregraphTime;
@property(nonatomic, retain) IBOutlet UIImageView *accelerateImage;
@property(nonatomic, retain) IBOutlet UILabel *accelerateTime;
@end
