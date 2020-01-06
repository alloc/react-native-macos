#import "RCTBlurFilter.h"

@implementation RCTBlurFilter

- (instancetype)init
{
  self = [super init];
  return self;
}

- (NSArray<NSString *> *)inputKeys
{
  return @[@"inputImage", @"inputRadius"];
}

- (CIImage *)outputImage
{
//  CIContext *context = [CIContext context];
//  CGImageRef cgImage = [context createCGImage:_inputImage fromRect:_inputImage.extent];
  CIImage *image = _inputImage; // [CIImage imageWithCGImage:cgImage];
  image = [image imageByClampingToExtent];
  image = [image imageByApplyingGaussianBlurWithSigma:_inputRadius];
  image = [image imageByCroppingToRect:_inputImage.extent];
  return image;
}

@end
