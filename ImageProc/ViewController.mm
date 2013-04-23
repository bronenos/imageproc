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
#import "UIImage+StackBlur.h"


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
	kImageActionBlur,
};


@interface ViewController()
@property(nonatomic, retain) UIImage *coregraphImage;
@property(nonatomic, retain) UIImage *accelerateImage;
@property(nonatomic, retain) UIFont *regularFont;
@property(nonatomic, retain) UIFont *boldFont;

- (UIBarButtonItem *)buttonWithTitle:(NSString *)title selector:(SEL)sel;

- (NSString *)currentAction;
- (void)updateCounter:(int)counter;
- (void)generateImages;

- (CGFloat)scaleFactor;
- (Pixel_8888 *)backgroundColor;

- (void)generateCoregraphImage;
- (UIImage *)prepareAndGenerateCoregraphImage;

- (void)generateAccelerateImage;
- (UIImage *)prepareAndGenerateAccelerateImage;
- (void)accelerateImageWithTransform:(CGAffineTransform *)tf;
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
		self.regularFont = [UIFont systemFontOfSize:14.f];
		self.boldFont = [UIFont boldSystemFontOfSize:15.f];
	}
	
	return self;
}

- (void)dealloc
{
	[_originalImageView release];
	[_coregraphImageView release];
	[_coregraphTime release];
	[_accelerateImageView release];
	[_menuToolbar release];
	[_accelerateTime release];
	[_regularFont release];
	[_boldFont release];
	[super dealloc];
}


#pragma mark - View
- (void)viewDidLoad
{
	[super viewDidLoad];
	
	NSMutableArray *menuButtons = [NSMutableArray array];
	[menuButtons addObject:[self buttonWithTitle:@"Scale" selector:@selector(doScale)]];
	[menuButtons addObject:[self buttonWithTitle:@"Rotate" selector:@selector(doRotate)]];
	[menuButtons addObject:[self buttonWithTitle:@"Flip" selector:@selector(doFlip)]];
	[menuButtons addObject:[self buttonWithTitle:@"Blur" selector:@selector(doBlur)]];
	[menuButtons addObjectsFromArray:self.menuToolbar.items];
	self.menuToolbar.items = menuButtons;
	
	NSString *origPath = [[NSBundle mainBundle] pathForResource:@"image200" ofType:@"png"];
	self.originalImageView.image = [UIImage imageWithContentsOfFile:origPath];
	
	self.coregraphImageView.hidden = YES;
	self.coregraphTime.hidden = YES;
	
	self.accelerateImageView.hidden = YES;
	self.accelerateTime.hidden = YES;
}

- (UIBarButtonItem *)buttonWithTitle:(NSString *)title selector:(SEL)sel
{
	UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithTitle:title
															   style:UIBarButtonItemStyleBordered
															  target:self
															  action:sel];
	return [button autorelease];
}


#pragma mark - Public Methods
- (void)doScale
{
	_action = kImageActionScale;
	[self generateImages];
}

- (void)doRotate
{
	_action = kImageActionRotate;
	[self generateImages];
}

- (void)doFlip
{
	_action = kImageActionFlip;
	[self generateImages];
}

- (void)doBlur
{
	_action = kImageActionBlur;
	[self generateImages];
}


#pragma mark - Private Methods
- (NSString *)currentAction
{
	NSArray *actions = @[ @"scale", @"rotate", @"flip", @"blur" ];
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
		const size_t timesToRepeat = 250;
		__block int counter = 0;
		
		uint32_t ctime = 0;
		MEASURE_CALL_TIME_ADD(ctime, ^{
			for (int i=0, cnt=timesToRepeat; i<cnt; i++, counter++) {
				[self generateCoregraphImage];
				[self updateCounter:counter];
			}
		});
		
		uint32_t atime = 0;
		MEASURE_CALL_TIME_ADD(atime, ^{
			for (int i=0, cnt=timesToRepeat; i<cnt; i++, counter++) {
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
				self.coregraphTime.font = (ctime < atime ? self.boldFont : self.regularFont);
				self.coregraphTime.hidden = NO;
			}

			
			self.accelerateImageView.image = self.accelerateImage;
			self.accelerateImageView.hidden = NO;

			if (self.accelerateImage) {
				self.accelerateTime.text = [NSString stringWithFormat:@"%u ms", atime];
				self.accelerateTime.font = (atime < ctime ? self.boldFont : self.regularFont);
				self.accelerateTime.hidden = NO;
			}
		});
	});
}

- (CGFloat)scaleFactor
{
	const CGFloat destWidth = _destBuffer.width;
	const CGFloat sourceWidth = _sourceBuffer.width;
	return destWidth / sourceWidth;
}

- (Pixel_8888 *)backgroundColor
{
	static Pixel_8888 backgroundColor = { 0, 0, 0, 0 };
	return &backgroundColor;
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

- (void)accelerateImageWithTransform:(CGAffineTransform *)tf
{
	vImageAffineWarp_ARGB8888(
			&_sourceBuffer, &_destBuffer, NULL,
			(vImage_CGAffineTransform *)tf, *[self backgroundColor], kvImageBackgroundColorFill
	);
}


#pragma mark - Scaling
- (void)scaleCoregraph
{
	const CGSize size = self.coregraphImageView.bounds.size;
	[self.originalImageView.image drawInRect:((CGRect) {CGPointZero, size})];
}

- (void)scaleAccelerate
{
	CGAffineTransform tf = CGAffineTransformIdentity;
	tf = CGAffineTransformScale(tf, [self scaleFactor], [self scaleFactor]);
	
	[self accelerateImageWithTransform:&tf];
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
	CGAffineTransform tf = CGAffineTransformIdentity;
	tf = CGAffineTransformRotate(tf, -float(M_PI / 2.f));
	tf = CGAffineTransformTranslate(tf, -float(_destBuffer.width), 0);
	tf = CGAffineTransformScale(tf, [self scaleFactor], [self scaleFactor]);

	[self accelerateImageWithTransform:&tf];
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
	
	CGAffineTransform tf = CGAffineTransformIdentity;
	tf = CGAffineTransformRotate(tf, -float(M_PI));
	tf = CGAffineTransformTranslate(tf, -float(_destBuffer.width), -float(_destBuffer.height));
	tf = CGAffineTransformScale(tf, -[self scaleFactor], [self scaleFactor]);
	tf = CGAffineTransformTranslate(tf, -float(_destBuffer.width / [self scaleFactor]), 0);

	[self accelerateImageWithTransform:&tf];
}


#pragma mark - Blur
- (void)blurCoregraph
{
	const CGSize size = self.coregraphImageView.bounds.size;
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	UIImage *blurredImage = [self.originalImageView.image stackBlur:3];
	[blurredImage drawInRect:((CGRect) {CGPointZero, size})];
}

- (void)blurAccelerate
{
	const size_t kernelWidth = 5;
	const size_t kernelHeight = 5;
	
	const int16_t kernel[kernelWidth * kernelHeight] = {
			1,	2,	2,	2,	1,
			2,	4,	8,	4,	2,
			2,	8,	16,	8,	2,
			2,	4,	8,	4,	2,
			1,	2,	2,	2,	1,
	};
	
	int16_t sum = 0;
	for (int i=0, cnt=kernelWidth*kernelHeight; i<cnt; i++) {
		sum += kernel[i];
	}

	vImageScale_ARGB8888(&_sourceBuffer, &_tmpBuffer, NULL, kvImageLeaveAlphaUnchanged);
	vImageConvolve_ARGB8888(
			&_tmpBuffer, &_destBuffer, NULL,
			0, 0, kernel, kernelHeight, kernelWidth,
			sum, *[self backgroundColor], kvImageBackgroundColorFill
	);
}

@end
