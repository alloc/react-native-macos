//
//  UIImageUtils.m
//  RCTTest
//
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "RCTUtils.h"
#import "UIImageUtils.h"

NSData *UIImagePNGRepresentation(NSImage *image)
{
  CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)[image TIFFRepresentation], NULL);
  CGImageRef maskRef =  CGImageSourceCreateImageAtIndex(source, 0, NULL);
  CFRelease(source);

  NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:maskRef];
  CGImageRelease(maskRef);

  return [newRep representationUsingType:NSPNGFileType
                              properties:@{ NSImageProgressive: @YES }];
}

NSData *UIImageJPEGRepresentation(NSImage *image, float quality)
{
  CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)[image TIFFRepresentation], NULL);
  CGImageRef maskRef =  CGImageSourceCreateImageAtIndex(source, 0, NULL);
  CFRelease(source);

  NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:maskRef];
  CGImageRelease(maskRef);

  return [newRep representationUsingType:NSJPEGFileType
                              properties:@{ NSImageCompressionFactor: @(quality) }];
}



static NSMutableArray *contextStack = nil;
static NSMutableArray *imageContextStack = nil;


void UIGraphicsPushContext(CGContextRef ctx)
{
  if (!contextStack) {
    contextStack = [[NSMutableArray alloc] initWithCapacity:1];
  }

  if ([NSGraphicsContext currentContext]) {
    [contextStack addObject:[NSGraphicsContext currentContext]];
  }

  [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:(void *)ctx flipped:YES]];
}

void UIGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale)
{
  if (scale == 0.f) {
    scale = RCTScreenScale();
  }

  const size_t width = ceil(size.width * scale);
  const size_t height = ceil(size.height * scale);

  if (width > 0 && height > 0) {
    if (!imageContextStack) {
      imageContextStack = [[NSMutableArray alloc] initWithCapacity:1];
    }

    [imageContextStack addObject:[NSNumber numberWithFloat:scale]];

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, width, height, 8, 4*width, colorSpace, (opaque? kCGImageAlphaNoneSkipFirst : kCGImageAlphaPremultipliedFirst));
    CGContextConcatCTM(ctx, CGAffineTransformMake(1, 0, 0, -1, 0, height));
    CGContextScaleCTM(ctx, scale, scale);
    CGColorSpaceRelease(colorSpace);
    UIGraphicsPushContext(ctx);
    CGContextRelease(ctx);
  }
}


CGContextRef UIGraphicsGetCurrentContext()
{
  return [[NSGraphicsContext currentContext] graphicsPort];
}

NSImage *UIGraphicsGetImageFromCurrentImageContext()
{
  if ([imageContextStack lastObject]) {
    CGImageRef theCGImage = CGBitmapContextCreateImage(UIGraphicsGetCurrentContext());
    NSImage *image = [[NSImage alloc]
                      initWithCGImage:theCGImage
                      size:NSSizeFromCGSize(CGSizeMake(CGImageGetWidth(theCGImage), CGImageGetHeight(theCGImage) ))];
    CGImageRelease(theCGImage);
    return image;
  } else {
    return nil;
  }
}

void UIGraphicsPopContext()
{
  if ([contextStack lastObject]) {
    [NSGraphicsContext setCurrentContext:[contextStack lastObject]];
    [contextStack removeLastObject];
  }
}


void UIGraphicsEndImageContext()
{
  if ([imageContextStack lastObject]) {
    [imageContextStack removeLastObject];
    UIGraphicsPopContext();
  }
}

CGImageRef RCTGetCGImageRef(NSImage *image)
{
  return [image CGImageForProposedRect:nil context:nil hints:nil];
}

