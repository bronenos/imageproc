//
//  ViewController.m
//  ImageProc
//
//  Created by Stan Potemkin on 4/20/13.
//  Copyright (c) 2013 Stan Potemkin. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import <Accelerate/Accelerate.h>
#import <sys/time.h>
#import "ViewController.h"


#define MEASURE_CALL_TIME( time, call ) \
{\
struct timeval tv;\
int64_t beginTicks;\
int64_t endTicks; \
gettimeofday(&tv, NULL); \
beginTicks = 1000000LL * static_cast<int64_t>(tv.tv_sec) + static_cast<int64_t>(tv.tv_usec); \
{ (call()); } \
gettimeofday(&tv, NULL); \
endTicks = 1000000LL * static_cast<int64_t>(tv.tv_sec) + static_cast<int64_t>(tv.tv_usec); \
endTicks -= beginTicks; \
time = [[NSString stringWithFormat:@"%u mcs", (uint32_t)endTicks] retain]; \
}

typedef NS_ENUM(NSUInteger, kImageAction) {
	kImageActionScale,
	kImageActionRotate
};


@interface ViewController()
@property(nonatomic, retain) UIImage *coregraphImage;
@property(nonatomic, retain) UIImage *accelerateImage;

- (NSString *)currentAction;
- (void)generateImages;
- (void)generateCoregraphImage;
- (void)generateAccelerateImage;

- (UIImage *)scaleCoregraph;
- (UIImage *)scaleAccelerate;

- (UIImage *)rotateCoregraph;
- (UIImage *)rotateAccelerate;
@end


@implementation ViewController
{
	kImageAction _action;
}

#pragma mark - Memory
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nil bundle:nil])) {
		// ...
	}
	
	return self;
}

- (void)dealloc
{
	[_originalImageView release];
	[_coregraphImageView release];
	[_coregraphTime release];
	[_accelerateImageView release];
	[_accelerateTime release];
	[super dealloc];
}


#pragma mark - View
- (void)viewDidLoad
{
	[super viewDidLoad];

	NSString *origPath = [[NSBundle mainBundle] pathForResource:@"image200" ofType:@"png"];
	self.originalImageView.image = [UIImage imageWithContentsOfFile:origPath];
	
	self.coregraphImageView.hidden = YES;
	self.coregraphTime.hidden = YES;
	
	self.accelerateImageView.hidden = YES;
	self.accelerateTime.hidden = YES;
}


#pragma mark - Public Methods
- (IBAction)doScale
{
	_action = kImageActionScale;
	[self generateImages];
}

- (IBAction)doRotate
{
	_action = kImageActionRotate;
	[self generateImages];
}


#pragma mark - Private Methods
- (NSString *)currentAction
{
	NSArray *actions = @[ @"scale", @"rotate" ];
	return actions[_action];
}

- (void)generateImages
{
	self.coregraphImageView.hidden = YES;
	self.coregraphTime.hidden = YES;
	
	self.accelerateImageView.hidden = YES;
	self.accelerateTime.hidden = YES;
	
	dispatch_queue_t back_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
	dispatch_async(back_queue, ^(void){
		[self generateCoregraphImage];
		[self generateAccelerateImage];
	});
}

- (void)generateCoregraphImage
{
	UIImage *origImage = self.originalImageView.image;
	if (origImage == nil) {
		return;
	}

	NSString *coregraphTime = nil;
	MEASURE_CALL_TIME(coregraphTime, ^{
		NSString *action = [[self currentAction] stringByAppendingString:@"Coregraph"];
		self.coregraphImage = [self performSelector:NSSelectorFromString(action)];
	});
	
	dispatch_async(dispatch_get_main_queue(), ^{
		self.coregraphImageView.image = self.coregraphImage;
		self.coregraphImageView.hidden = NO;

		if (self.coregraphImage) {
			self.coregraphTime.text = coregraphTime;
			self.coregraphTime.hidden = NO;
		}
	});
}

- (void)generateAccelerateImage
{
	UIImage *origImage = self.originalImageView.image;
	if (origImage == nil) {
		return;
	}

	NSString *accelerateTime = nil;
	MEASURE_CALL_TIME(accelerateTime, ^{
		NSString *action = [[self currentAction] stringByAppendingString:@"Accelerate"];
		self.accelerateImage = [self performSelector:NSSelectorFromString(action)];
	});
	
	dispatch_async(dispatch_get_main_queue(), ^{
		self.accelerateImageView.image = self.accelerateImage;
		self.accelerateImageView.hidden = NO;

		if (self.accelerateImage) {
			self.accelerateTime.text = accelerateTime;
			self.accelerateTime.hidden = NO;
		}
	});
}


#pragma mark - Scaling
- (UIImage *)scaleCoregraph
{
	const CGSize size = self.coregraphImageView.bounds.size;
	UIGraphicsBeginImageContext(size);
	
	[self.originalImageView.image drawInRect:((CGRect) {CGPointZero, size})];
	
	UIImage *ret = [UIImage imageWithCGImage:UIGraphicsGetImageFromCurrentImageContext().CGImage];
	UIGraphicsEndImageContext();
	
	return ret;
}

- (UIImage *)scaleAccelerate
{
	// SP - general info
	const NSUInteger bytesPerPixel = 4;
	const NSUInteger bitsPerComponent = 8;
	const CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	const CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big;

	// SP - source info
	const CGImageRef sourceRef = self.originalImageView.image.CGImage;
	const NSUInteger sourceWidth = CGImageGetWidth(sourceRef);
	const NSUInteger sourceHeight = CGImageGetHeight(sourceRef);
	const NSUInteger sourceBytesPerRow = sourceWidth * bytesPerPixel;
	unsigned char *sourceData = (unsigned char *) calloc(sourceWidth * sourceHeight * bytesPerPixel, sizeof(unsigned char));

	// SP - source context
	CGContextRef sourceContext = CGBitmapContextCreate(
			sourceData,
			sourceWidth,
			sourceHeight,
			bitsPerComponent,
			sourceBytesPerRow,
			colorSpace,
			bitmapInfo
	);

	// SP - draw source
	CGContextDrawImage(sourceContext, CGRectMake(0, 0, sourceWidth, sourceHeight), sourceRef);
	CGContextRelease(sourceContext);

	// SP - destination info
	const CGSize destSize = self.accelerateImageView.bounds.size;
	const NSUInteger destWidth = (NSUInteger) destSize.width;
	const NSUInteger destHeight = (NSUInteger) destSize.height;
	const NSUInteger destBytesPerRow = destWidth * bytesPerPixel;
	unsigned char *destData = (unsigned char *) calloc(destWidth * destHeight * bytesPerPixel, sizeof(unsigned char));

	// SP - destination context
	CGContextRef destContext = CGBitmapContextCreate(
			destData,
			destWidth,
			destHeight,
			bitsPerComponent,
			destBytesPerRow,
			colorSpace,
			bitmapInfo
	);

	// SP - draw into destination using Accelerate framework
	vImage_Buffer sourceBuffer;
	sourceBuffer.data = sourceData;
	sourceBuffer.width = sourceWidth;
	sourceBuffer.height = sourceHeight;
	sourceBuffer.rowBytes = sourceBytesPerRow;

	vImage_Buffer destBuffer;
	destBuffer.data = destData;
	destBuffer.width = destWidth;
	destBuffer.height = destHeight;
	destBuffer.rowBytes = destBytesPerRow;

	vImage_Error err = vImageScale_ARGB8888(&sourceBuffer, &destBuffer, NULL, kvImageLeaveAlphaUnchanged);
	free(sourceData);

	// SP - get result image
	CGImageRef destRef = CGBitmapContextCreateImage(destContext);
	UIImage *ret = [UIImage imageWithCGImage:destRef];
	CGImageRelease(destRef);

	// SP - cleanup
	CGColorSpaceRelease(colorSpace);
	CGContextRelease(destContext);

	free(destData);

	if (err != kvImageNoError) {
		assert(0);
	}
	
	return ret;
}


#pragma mark - Rotation
- (UIImage *)rotateCoregraph
{
	return nil;
}

- (UIImage *)rotateAccelerate
{
	return nil;
}

@end
