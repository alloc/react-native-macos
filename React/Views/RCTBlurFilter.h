#import <CoreImage/CoreImage.h>

@interface RCTBlurFilter : CIFilter

- (instancetype)init NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong) CIImage *inputImage;
@property (nonatomic, assign) CGFloat inputRadius;

@end
