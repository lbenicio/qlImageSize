//
//  GetMetadataForFile.m
//  qlImageSize
//
//  Created by @Nyx0uf on 20/12/14.
//  Copyright (c) 2014 Nyx0uf. All rights reserved.
//


#import "tools.h"
#import <ImageIO/ImageIO.h>
#include <stdint.h>

#ifdef NYX_MD_SUPPORT_BPG_DECODE
#import "bpg_decode.h"
#endif

#ifdef NYX_MD_SUPPORT_NETPBM_DECODE
#import "netpbm_decode.h"
#endif


Boolean GetMetadataForFile(void* thisInterface, CFMutableDictionaryRef attributes, CFStringRef contentTypeUTI, CFStringRef pathToFile);
bool GetImageInfos(CFStringRef pathToFile, NSMutableDictionary* attrs, bool (*infos_fn_ptr)(CFStringRef, image_infos*));
bool GetWebPImageInfos(CFStringRef pathToFile, NSMutableDictionary* attrs);

static const uint64_t kMaximumImageDimension = 100000;
static const uint64_t kMaximumImagePixelCount = 100000000;


Boolean GetMetadataForFile(__unused void* thisInterface, CFMutableDictionaryRef attributes, __unused CFStringRef contentTypeUTI, CFStringRef pathToFile)
{
	@autoreleasepool
	{
		NSString* extension = [[(__bridge NSString*)pathToFile pathExtension] lowercaseString];

#ifdef NYX_MD_SUPPORT_BPG_DECODE
		if ([extension isEqualToString:@"bpg"])
		{
			return GetImageInfos(pathToFile, (__bridge NSMutableDictionary*)attributes, &get_bpg_informations_for_filepath);
		}
#endif
#ifdef NYX_MD_SUPPORT_WEBP_DECODE
		if ([extension isEqualToString:@"webp"])
		{
			return GetWebPImageInfos(pathToFile, (__bridge NSMutableDictionary*)attributes);
		}
#endif
#ifdef NYX_MD_SUPPORT_NETPBM_DECODE
		if ([extension isEqualToString:@"ppm"] || [extension isEqualToString:@"pgm"] || [extension isEqualToString:@"pbm"])
		{
			return GetImageInfos(pathToFile, (__bridge NSMutableDictionary*)attributes, &get_netpbm_informations_for_filepath);
		}
#endif
	}

	return TRUE;
}

bool GetWebPImageInfos(CFStringRef pathToFile, NSMutableDictionary* attrs)
{
	NSURL* url = [NSURL fileURLWithPath:(__bridge NSString*)pathToFile];
	CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
	if (source == NULL)
		return FALSE;

	CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
	CFRelease(source);
	if (properties == NULL)
		return FALSE;

	int64_t width = 0, height = 0;
	CFNumberRef widthNumber = CFDictionaryGetValue(properties, kCGImagePropertyPixelWidth);
	CFNumberRef heightNumber = CFDictionaryGetValue(properties, kCGImagePropertyPixelHeight);
	const bool hasDimensions = widthNumber != NULL && heightNumber != NULL &&
		CFNumberGetValue(widthNumber, kCFNumberSInt64Type, &width) &&
		CFNumberGetValue(heightNumber, kCFNumberSInt64Type, &height);
	if (!hasDimensions || width <= 0 || height <= 0 ||
		(uint64_t)width > kMaximumImageDimension || (uint64_t)height > kMaximumImageDimension ||
		(uint64_t)width > kMaximumImagePixelCount / (uint64_t)height)
	{
		CFRelease(properties);
		return FALSE;
	}

	CFBooleanRef alpha = CFDictionaryGetValue(properties, kCGImagePropertyHasAlpha);
	attrs[(NSString*)kMDItemPixelWidth] = @(width);
	attrs[(NSString*)kMDItemPixelHeight] = @(height);
	attrs[(NSString*)kMDItemPixelCount] = @(width * height);
	attrs[(NSString*)kMDItemHasAlphaChannel] = (alpha != NULL && CFBooleanGetValue(alpha)) ? @YES : @NO;
	attrs[(NSString*)kMDItemBitsPerSample] = @8;
	attrs[(NSString*)kMDItemColorSpace] = @"RGB";
	CFRelease(properties);
	return TRUE;
}

bool GetImageInfos(CFStringRef pathToFile, NSMutableDictionary* attrs, bool (*infos_fn_ptr)(CFStringRef, image_infos*))
{
	image_infos infos;
	memset(&infos, 0, sizeof(image_infos));
	bool ret = infos_fn_ptr(pathToFile, &infos);

	if (!ret || infos.width == 0 || infos.height == 0 ||
		infos.width > kMaximumImageDimension || infos.height > kMaximumImageDimension ||
		infos.width > kMaximumImagePixelCount / infos.height)
		return FALSE;

	attrs[(NSString*)kMDItemPixelWidth] = @(infos.width);
	attrs[(NSString*)kMDItemPixelHeight] = @(infos.height);
	attrs[(NSString*)kMDItemPixelCount] = @(infos.height * infos.width);
	attrs[(NSString*)kMDItemHasAlphaChannel] = (!infos.has_alpha) ? @NO : @YES;
	attrs[(NSString*)kMDItemBitsPerSample] = @(infos.bit_depth);
	attrs[(NSString*)kMDItemColorSpace] = @(colorspace_string(infos.colorspace));

	return TRUE;
}
