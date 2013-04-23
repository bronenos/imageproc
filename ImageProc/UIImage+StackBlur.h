//
//  UIImage+StackBlur.h
//  stackBlur
//
//  Created by Thomas LANDSPURG on 07/02/12.
//  Copyright 2012 Digiwie. All rights reserved.
//
// StackBlur implementation on iOS
//
//

#import <Foundation/Foundation.h>


@interface UIImage (StackBlur) 

- (UIImage*) normalizeWithScale:(CGFloat)scale;
- (UIImage *) normalize;
- (UIImage *) stackBlur:(NSUInteger)radius;

@end

#ifdef __cplusplus
extern "C" {
#endif
CGImageRef newNormalizedImageWithScale(CGImageRef image, CGFloat scale);
CGImageRef newNormalizedImage(CGImageRef image);
CGImageRef newImageWithStackBlur(CGImageRef image, NSUInteger radius);
#ifdef __cplusplus
	}
#endif