//
//  UIImage+StackBlur.m
//  stackBlur
//
//  Created by Thomas on 07/02/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "UIImage+StackBlur.h"
#import "CoreGraphics/CoreGraphics.h"

CGImageRef newNormalizedImageWithScale(CGImageRef image, CGFloat scale) {
	NSUInteger width = (NSUInteger)CGImageGetWidth(image) * scale;
	NSUInteger height = (NSUInteger)CGImageGetHeight(image) * scale;
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef thumbBitmapCtxt = CGBitmapContextCreate(NULL,
														 width,
														 height,
														 8,
														 width * 4,
														 colorSpace,
														 kCGImageAlphaPremultipliedLast
														 );
	CGColorSpaceRelease(colorSpace);

	if (thumbBitmapCtxt == nil) {
		return nil;
	}

    CGContextSetInterpolationQuality(thumbBitmapCtxt, kCGInterpolationHigh);
    CGRect destRect = CGRectMake(0, 0, width, height);

	CGContextDrawImage(thumbBitmapCtxt, destRect, image);
    CGImageRef tmpThumbImage = CGBitmapContextCreateImage(thumbBitmapCtxt);
	CGContextRelease(thumbBitmapCtxt);

	return tmpThumbImage;
}

CGImageRef newNormalizedImage(CGImageRef image) {
	return newNormalizedImageWithScale(image, 1.0f);
}

// Stackblur algorithm
// from
// http://incubator.quasimondo.com/processing/fast_blur_deluxe.php
// by  Mario Klingemann
//
// ss - use normalize before blur
CGImageRef newImageWithStackBlur(CGImageRef image, NSUInteger inradius) {
	if (NULL == image) {
		return NULL;
	}
	NSInteger radius = inradius;
	CGDataProviderRef m_DataProvideRef = CGImageGetDataProvider(image);
	CFDataRef m_DataRef = CGDataProviderCopyData(m_DataProvideRef);
	NSMutableData *m_MutData = [NSMutableData dataWithData:(NSData *)m_DataRef];
	UInt8 *m_PixelBuf = (UInt8 *) m_MutData.bytes;
	CFRelease(m_DataRef);

	CGContextRef ctx = CGBitmapContextCreate(m_PixelBuf,
											 CGImageGetWidth(image),
											 CGImageGetHeight(image),
											 CGImageGetBitsPerComponent(image),
											 CGImageGetBytesPerRow(image),
											 CGImageGetColorSpace(image),
											 CGImageGetBitmapInfo(image)
											 );
	if (ctx == nil) {
		return nil;
	}

	int w=CGImageGetWidth(image);
	int h=CGImageGetHeight(image);
	int wm=w-1;
	int hm=h-1;
	int wh=w*h;
	int div=radius+radius+1;

	int *r=malloc(wh*sizeof(int));
	int *g=malloc(wh*sizeof(int));
	int *b=malloc(wh*sizeof(int));
	memset(r,0,wh*sizeof(int));
	memset(g,0,wh*sizeof(int));
	memset(b,0,wh*sizeof(int));
	int rsum,gsum,bsum,x,y,i,p,yp,yi,yw;
	int *vmin = malloc(sizeof(int)*MAX(w,h));
	memset(vmin,0,sizeof(int)*MAX(w,h));
	int divsum=(div+1)>>1;
	divsum*=divsum;
	int *dv=malloc(sizeof(int)*(256*divsum));
	for (i=0;i<256*divsum;i++){
		dv[i]=(i/divsum);
	}

	yw=yi=0;

	int *stack=malloc(sizeof(int)*(div*3));
	int stackpointer;
	int stackstart;
	int *sir;
	int rbs;
	int r1=radius+1;
	int routsum,goutsum,boutsum;
	int rinsum,ginsum,binsum;
	memset(stack,0,sizeof(int)*div*3);

	for (y=0;y<h;y++){
		rinsum=ginsum=binsum=routsum=goutsum=boutsum=rsum=gsum=bsum=0;

		for(int i=-radius;i<=radius;i++){
			sir=&stack[(i+radius)*3];
			/*			p=m_PixelBuf[yi+MIN(wm,MAX(i,0))];
			 sir[0]=(p & 0xff0000)>>16;
			 sir[1]=(p & 0x00ff00)>>8;
			 sir[2]=(p & 0x0000ff);
			 */
			int offset=(yi+MIN(wm,MAX(i,0)))*4;
			sir[0]=m_PixelBuf[offset];
			sir[1]=m_PixelBuf[offset+1];
			sir[2]=m_PixelBuf[offset+2];

			rbs=r1-abs(i);
			rsum+=sir[0]*rbs;
			gsum+=sir[1]*rbs;
			bsum+=sir[2]*rbs;
			if (i>0){
				rinsum+=sir[0];
				ginsum+=sir[1];
				binsum+=sir[2];
			} else {
				routsum+=sir[0];
				goutsum+=sir[1];
				boutsum+=sir[2];
			}
		}
		stackpointer=radius;


		for (x=0;x<w;x++){
			r[yi]=dv[rsum];
			g[yi]=dv[gsum];
			b[yi]=dv[bsum];

			rsum-=routsum;
			gsum-=goutsum;
			bsum-=boutsum;

			stackstart=stackpointer-radius+div;
			sir=&stack[(stackstart%div)*3];

			routsum-=sir[0];
			goutsum-=sir[1];
			boutsum-=sir[2];

			if(y==0){
				vmin[x]=MIN(x+radius+1,wm);
			}

			/*			p=m_PixelBuf[yw+vmin[x]];

			 sir[0]=(p & 0xff0000)>>16;
			 sir[1]=(p & 0x00ff00)>>8;
			 sir[2]=(p & 0x0000ff);
			 */
			int offset=(yw+vmin[x])*4;
			sir[0]=m_PixelBuf[offset];
			sir[1]=m_PixelBuf[offset+1];
			sir[2]=m_PixelBuf[offset+2];
			rinsum+=sir[0];
			ginsum+=sir[1];
			binsum+=sir[2];

			rsum+=rinsum;
			gsum+=ginsum;
			bsum+=binsum;

			stackpointer=(stackpointer+1)%div;
			sir=&stack[((stackpointer)%div)*3];

			routsum+=sir[0];
			goutsum+=sir[1];
			boutsum+=sir[2];

			rinsum-=sir[0];
			ginsum-=sir[1];
			binsum-=sir[2];

			yi++;
		}
		yw+=w;
	}
	for (x=0;x<w;x++){
		rinsum=ginsum=binsum=routsum=goutsum=boutsum=rsum=gsum=bsum=0;
		yp=-radius*w;
		for(i=-radius;i<=radius;i++){
			yi=MAX(0,yp)+x;

			sir=&stack[(i+radius)*3];

			sir[0]=r[yi];
			sir[1]=g[yi];
			sir[2]=b[yi];

			rbs=r1-abs(i);

			rsum+=r[yi]*rbs;
			gsum+=g[yi]*rbs;
			bsum+=b[yi]*rbs;

			if (i>0){
				rinsum+=sir[0];
				ginsum+=sir[1];
				binsum+=sir[2];
			} else {
				routsum+=sir[0];
				goutsum+=sir[1];
				boutsum+=sir[2];
			}

			if(i<hm){
				yp+=w;
			}
		}
		yi=x;
		stackpointer=radius;
		for (y=0;y<h;y++){
			//			m_PixelBuf[yi]=0xff000000 | (dv[rsum]<<16) | (dv[gsum]<<8) | dv[bsum];
			int offset=yi*4;
			m_PixelBuf[offset]=dv[rsum];
			m_PixelBuf[offset+1]=dv[gsum];
			m_PixelBuf[offset+2]=dv[bsum];
			rsum-=routsum;
			gsum-=goutsum;
			bsum-=boutsum;

			stackstart=stackpointer-radius+div;
			sir=&stack[(stackstart%div)*3];

			routsum-=sir[0];
			goutsum-=sir[1];
			boutsum-=sir[2];

			if(x==0){
				vmin[y]=MIN(y+r1,hm)*w;
			}
			p=x+vmin[y];

			sir[0]=r[p];
			sir[1]=g[p];
			sir[2]=b[p];

			rinsum+=sir[0];
			ginsum+=sir[1];
			binsum+=sir[2];

			rsum+=rinsum;
			gsum+=ginsum;
			bsum+=binsum;

			stackpointer=(stackpointer+1)%div;
			sir=&stack[(stackpointer)*3];

			routsum+=sir[0];
			goutsum+=sir[1];
			boutsum+=sir[2];

			rinsum-=sir[0];
			ginsum-=sir[1];
			binsum-=sir[2];

			yi+=w;
		}
	}
	free(r);
	free(g);
	free(b);
	free(vmin);
	free(dv);
	free(stack);
	CGImageRef imageRef = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);

	return imageRef;
}

@implementation  UIImage (StackBlur)

- (UIImage *) normalizeWithScale:(CGFloat)scale {
	CGImageRef imageRef = newNormalizedImageWithScale(self.CGImage, scale / self.scale);
	UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
	CGImageRelease(imageRef);
	return finalImage;
}

- (UIImage *) normalize
{
    return [self normalizeWithScale:1.0f];
}

- (UIImage *) stackBlur:(NSUInteger)inradius
{
	CGImageRef imageRef = newImageWithStackBlur(self.CGImage, inradius);
	UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
	CGImageRelease(imageRef);	
	return finalImage;
}


@end
