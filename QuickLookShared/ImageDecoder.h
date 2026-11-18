#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImageDecoder : NSObject
+ (nullable NSBitmapImageRep *)bitmapRepresentationAtURL:(NSURL *)url;
+ (nullable CGImageRef)thumbnailRepresentationAtURL:(NSURL *)url maximumPixelSize:(NSInteger)maximumPixelSize CF_RETURNS_RETAINED;
@end

NS_ASSUME_NONNULL_END
