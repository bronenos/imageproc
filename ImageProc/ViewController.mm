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


@interface ViewController()
- (void)generateImages;
- (void)generateCoregraphImage;
- (void)generateAccelerateImage;
@end


@implementation ViewController
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
	[_originalImage release];
	[_coregraphImage release];
	[_coregraphTime release];
	[_accelerateImage release];
	[_accelerateTime release];
	[super dealloc];
}


#pragma mark - View
- (void)viewDidLoad
{
	[super viewDidLoad];

	NSString *origPath = [[NSBundle mainBundle] pathForResource:@"image200" ofType:@"png"];
	self.originalImage.image = [UIImage imageWithContentsOfFile:origPath];
	
	self.coregraphImage.hidden = YES;
	self.coregraphTime.hidden = YES;
	
	self.accelerateImage.hidden = YES;
	self.accelerateTime.hidden = YES;
	
	[self performSelector:@selector(generateImages) withObject:nil afterDelay:1.f];
}


#pragma mark - Private Methods
- (void)generateImages
{
	dispatch_queue_t back_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
	dispatch_async(back_queue, ^(void){
		[self generateCoregraphImage];
		[self generateAccelerateImage];
	});
}

- (void)generateCoregraphImage
{
	UIImage *origImage = self.originalImage.image;
	if (origImage == nil) {
		return;
	}

	__block UIImage *coregraphImage = nil;
	__block NSString *coregraphTime = nil;

	MEASURE_CALL_TIME(coregraphTime, ^{
		const CGSize size = self.coregraphImage.bounds.size;
		UIGraphicsBeginImageContext(size);
		[origImage drawInRect:((CGRect) {CGPointZero, size})];
		coregraphImage = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
	});

	dispatch_async(dispatch_get_main_queue(), ^{
		self.coregraphImage.image = coregraphImage;
		self.coregraphImage.hidden = NO;

		self.coregraphTime.text = coregraphTime;
		self.coregraphTime.hidden = NO;
	});
}

- (void)generateAccelerateImage
{
	UIImage *origImage = self.originalImage.image;
	if (origImage == nil) {
		return;
	}

	__block UIImage *accelerateImage = nil;
	__block NSString *accelerateTime = nil;

	MEASURE_CALL_TIME(accelerateTime, ^{
		const NSUInteger bytesPerPixel = 4;
		const NSUInteger bitsPerComponent = 8;
		const CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		const CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big;

		const CGImageRef sourceRef = origImage.CGImage;
		const NSUInteger sourceWidth = CGImageGetWidth(sourceRef);
		const NSUInteger sourceHeight = CGImageGetHeight(sourceRef);
		const NSUInteger sourceBytesPerRow = sourceWidth * bytesPerPixel;

		unsigned char *sourceData = (unsigned char *) calloc(sourceWidth * sourceHeight * bytesPerPixel, sizeof(unsigned char));
		CGContextRef sourceContext = CGBitmapContextCreate(
				sourceData,
				sourceWidth,
				sourceHeight,
				bitsPerComponent,
				sourceBytesPerRow,
				colorSpace,
				bitmapInfo
		);

		CGContextDrawImage(sourceContext, CGRectMake(0, 0, sourceWidth, sourceHeight), sourceRef);
		CGContextRelease(sourceContext);

		const CGSize destSize = self.accelerateImage.bounds.size;
		const NSUInteger destWidth = (NSUInteger) destSize.width;
		const NSUInteger destHeight = (NSUInteger) destSize.height;
		const NSUInteger destBytesPerRow = destWidth * bytesPerPixel;
		unsigned char *destData = (unsigned char *) calloc(destWidth * destHeight * bytesPerPixel, sizeof(unsigned char));

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
		
		vImage_Error err = vImageScale_ARGB8888(&sourceBuffer, &destBuffer, NULL, 0);
		free(sourceData);

		CGContextRef destContext = CGBitmapContextCreate(
				destData,
				destWidth,
				destHeight,
				bitsPerComponent,
				destBytesPerRow,
				colorSpace,
				bitmapInfo
		);

		CGImageRef destRef = CGBitmapContextCreateImage(destContext);
		accelerateImage = [UIImage imageWithCGImage:destRef];
		CGImageRelease(destRef);

		CGColorSpaceRelease(colorSpace);
		CGContextRelease(destContext);

		free(destData);

		if (err != kvImageNoError) {
			assert(0);
		}
	});

	dispatch_async(dispatch_get_main_queue(), ^{
		self.accelerateImage.image = accelerateImage;
		self.accelerateImage.hidden = NO;

		self.accelerateTime.text = accelerateTime;
		self.accelerateTime.hidden = NO;
	});
}

@end
