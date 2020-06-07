#import "RCTTextUtils.h"
#import "NSFont+LineHeight.h"
#import <React/RCTUtils.h>

NSRect RCTAlignTextFrame(NSRect frame, NSFont *font, NSString *textAlignVertical)
{
  if ([textAlignVertical isEqualToString:@"center"]) {
    CGFloat lineHeight = font.lineHeight;
    CGFloat heightDelta = frame.size.height - lineHeight;
    if (heightDelta > 0) {
      frame.origin.y += (heightDelta / 2) - (lineHeight / 16);
    }
  }
  return frame;
}
