#import "RCTTextUtils.h"
#import <React/RCTUtils.h>

NSRect RCTAlignTextFrame(NSRect frame, NSFont *font, NSString *textAlignVertical)
{
  CGFloat scale = RCTScreenScale();
  if (scale == 0) {
    return frame;
  }
  if ([textAlignVertical isEqualToString:@"center"]) {
    // Center the "x" character slightly below the mid point.
    CGFloat heightDelta = frame.size.height - font.xHeight;
    if (heightDelta > 0) {
      CGFloat offsetTop = (heightDelta / 2.0) + MIN(0, font.xHeight - font.capHeight);
      frame.origin.y = RCTFloorPixelValue(frame.origin.y + offsetTop, scale);
    }
  }
  return frame;
}
