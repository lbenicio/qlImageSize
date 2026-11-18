#import "ImageDecoder.h"
#import <ImageIO/ImageIO.h>
#import "bpg_decode.h"

@implementation ImageDecoder

+ (NSBitmapImageRep *)bitmapRepresentationAtURL:(NSURL *)url
{
	CGImageRef image = NULL;
	if ([[url.pathExtension lowercaseString] isEqualToString:@"bpg"])
	{
		image = decode_bpg_at_path((__bridge CFStringRef)url.path, NULL);
	}
	else
	{
		CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
		if (source != NULL)
		{
			image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
			CFRelease(source);
		}
	}

	if (image == NULL)
		return nil;

	NSBitmapImageRep *representation = [[NSBitmapImageRep alloc] initWithCGImage:image];
	CGImageRelease(image);
	return representation;
}

+ (CGImageRef)thumbnailRepresentationAtURL:(NSURL *)url maximumPixelSize:(NSInteger)maximumPixelSize
{
	if ([[url.pathExtension lowercaseString] isEqualToString:@"bpg"])
		return decode_bpg_at_path((__bridge CFStringRef)url.path, NULL);

	CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
	if (source == NULL)
		return NULL;

	NSDictionary *options = @{
		(id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
		(id)kCGImageSourceCreateThumbnailWithTransform: @YES,
		(id)kCGImageSourceThumbnailMaxPixelSize: @(MAX(1, maximumPixelSize)),
		(id)kCGImageSourceShouldCache: @NO,
	};
	CGImageRef image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
	CFRelease(source);
	return image;
}

@end
