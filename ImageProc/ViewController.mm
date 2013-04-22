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


#define MEASURE_CALL_TIME_ADD( time, call ) \
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
time += endTicks; \
}

typedef NS_ENUM(NSUInteger, kImageAction) {
	kImageActionScale,
	kImageActionRotate,
	kImageActionFlip,
};


@interface ViewController()
@property(nonatomic, retain) UIImage *coregraphImage;
@property(nonatomic, retain) UIImage *accelerateImage;

- (NSString *)currentAction;
- (void)updateCounter:(int)counter;
- (void)generateImages;

- (void)generateCoregraphImage;
- (UIImage *)prepareAndGenerateCoregraphImage;

- (void)generateAccelerateImage;
- (UIImage *)prepareAndGenerateAccelerateImage;
@end


@implementation ViewController
{
	kImageAction _action;
	vImage_Buffer _sourceBuffer, _destBuffer, _tmpBuffer;
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

- (IBAction)doFlip
{
	_action = kImageActionFlip;
	[self generateImages];
}


#pragma mark - Private Methods
- (NSString *)currentAction
{
	NSArray *actions = @[ @"scale", @"rotate", @"flip" ];
	return actions[_action];
}

- (void)updateCounter:(int)counter
{
	dispatch_async(dispatch_get_main_queue(), ^{
		self.counterBarItem.title = [NSString stringWithFormat:@"%d", counter];
	});
}

- (void)generateImages
{
	self.coregraphImageView.hidden = YES;
	self.coregraphTime.hidden = YES;
	
	self.accelerateImageView.hidden = YES;
	self.accelerateTime.hidden = YES;
	
	dispatch_queue_t back_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
	dispatch_async(back_queue, ^(void){
		__block int counter = 0;
		
		uint32_t ctime = 0;
		MEASURE_CALL_TIME_ADD(ctime, ^{
			for (int i = 0; i < 1000; i++, counter++) {
				[self generateCoregraphImage];
				[self updateCounter:counter];
			}
		});
		
		uint32_t atime = 0;
		MEASURE_CALL_TIME_ADD(atime, ^{
			for (int i = 0; i < 1000; i++, counter++) {
				[self generateAccelerateImage];
				[self updateCounter:counter];
			}
		});

		[self updateCounter:counter];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			self.coregraphImageView.image = self.coregraphImage;
			self.coregraphImageView.hidden = NO;

			if (self.coregraphImage) {
				self.coregraphTime.text = [NSString stringWithFormat:@"%u ms", ctime];
				self.coregraphTime.hidden = NO;
			}

			
			self.accelerateImageView.image = self.accelerateImage;
			self.accelerateImageView.hidden = NO;

			if (self.accelerateImage) {
				self.accelerateTime.text = [NSString stringWithFormat:@"%u ms", atime];
				self.accelerateTime.hidden = NO;
			}
		});
	});
}

- (void)generateCoregraphImage
{
	UIImage *origImage = self.originalImageView.image;
	if (origImage == nil) {
		return;
	}

	self.coregraphImage = [self prepareAndGenerateCoregraphImage];
}

- (UIImage *)prepareAndGenerateCoregraphImage
{
	const CGSize size = self.coregraphImageView.bounds.size;
	UIGraphicsBeginImageContext(size);

	NSString *action = [[self currentAction] stringByAppendingString:@"Coregraph"];
	[self performSelector:NSSelectorFromString(action)];
	
	UIImage *ret = [UIImage imageWithCGImage:UIGraphicsGetImageFromCurrentImageContext().CGImage];
	UIGraphicsEndImageContext();

	return ret;
}


- (void)generateAccelerateImage
{
	UIImage *origImage = self.originalImageView.image;
	if (origImage == nil) {
		return;
	}

	self.accelerateImage = [self prepareAndGenerateAccelerateImage];
}

- (UIImage *)prepareAndGenerateAccelerateImage
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
	
	size_t sourceCount = sourceWidth * sourceHeight * bytesPerPixel;
	unsigned char *sourceData = (unsigned char *) calloc(sourceCount, sizeof(unsigned char));

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
	
	size_t destCount = destWidth * destHeight * bytesPerPixel;
	unsigned char *destData = (unsigned char *) calloc(destCount, sizeof(unsigned char));
	unsigned char *tmpData = (unsigned char *) calloc(destCount, sizeof(unsigned char));

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
	_sourceBuffer.data = sourceData;
	_sourceBuffer.width = sourceWidth;
	_sourceBuffer.height = sourceHeight;
	_sourceBuffer.rowBytes = sourceBytesPerRow;

	_destBuffer.data = destData;
	_destBuffer.width = destWidth;
	_destBuffer.height = destHeight;
	_destBuffer.rowBytes = destBytesPerRow;
	
	_tmpBuffer.data = tmpData;
	_tmpBuffer.width = _destBuffer.width;
	_tmpBuffer.height = _destBuffer.height;
	_tmpBuffer.rowBytes = _destBuffer.rowBytes;
	
	NSString *action = [[self currentAction] stringByAppendingString:@"Accelerate"];
	[self performSelector:NSSelectorFromString(action)];
	
	free(sourceData);

	// SP - get result image
	CGImageRef destRef = CGBitmapContextCreateImage(destContext);
	UIImage *ret = [UIImage imageWithCGImage:destRef];
	CGImageRelease(destRef);

	// SP - cleanup
	CGColorSpaceRelease(colorSpace);
	CGContextRelease(destContext);

	free(destData);

	return ret;
}



#pragma mark - Scaling
- (void)scaleCoregraph
{
	const CGSize size = self.coregraphImageView.bounds.size;
	[self.originalImageView.image drawInRect:((CGRect) {CGPointZero, size})];
}

- (void)scaleAccelerate
{
//	vImageUnpremultiplyData_ARGB8888(&_sourceBuffer, &_sourceBuffer, kvImageNoFlags);
	vImageScale_ARGB8888(&_sourceBuffer, &_destBuffer, NULL, kvImageLeaveAlphaUnchanged);
//	vImagePremultiplyData_ARGB8888(&_destBuffer, &_destBuffer, kvImageNoFlags);
}


#pragma mark - Rotation
- (void)rotateCoregraph
{
	const CGSize size = self.coregraphImageView.bounds.size;
	CGContextRef context = UIGraphicsGetCurrentContext();

	CGContextRotateCTM(context, (float)(M_PI * .5f));
	CGContextTranslateCTM(context, 0, -size.height);
	[self.originalImageView.image drawInRect:((CGRect) {CGPointZero, size})];
}

- (void)rotateAccelerate
{
	vImageScale_ARGB8888(&_sourceBuffer, &_tmpBuffer, NULL, kvImageLeaveAlphaUnchanged);
	
	Pixel_8888 backgroundColor = {0, 0, 0, 0};
	vImageRotate90_ARGB8888(&_tmpBuffer, &_destBuffer, kRotate90DegreesClockwise, backgroundColor, kvImageNoFlags);
//	vImageRotate_ARGB8888(&_destBuffer, &_destBuffer, NULL, (float) (M_PI * 1.5f), backgroundColor, kvImageNoFlags);
}


#pragma mark - Flip
- (void)flipCoregraph
{
	const CGSize size = self.coregraphImageView.bounds.size;
	CGContextRef context = UIGraphicsGetCurrentContext();

	CGContextScaleCTM(context, 1.f, -1.f);
	CGContextTranslateCTM(context, 0, -size.height);
	[self.originalImageView.image drawInRect:((CGRect) {CGPointZero, size})];
}

- (void)flipAccelerate
{
	vImageScale_ARGB8888(&_sourceBuffer, &_tmpBuffer, NULL, kvImageLeaveAlphaUnchanged);
	vImageVerticalReflect_ARGB8888(&_tmpBuffer, &_destBuffer, kvImageNoFlags);
}

@end
