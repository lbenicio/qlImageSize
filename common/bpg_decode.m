//
//  bpg_decode.m
//  qlImageSize
//
//  Created by @Nyx0uf on 30/12/14.
//  Copyright (c) 2014 Nyx0uf. All rights reserved.
//


#import "bpg_decode.h"
#import "libbpg.h"
#include <stdint.h>

static const size_t kMaximumBPGDimension = 100000;
static const size_t kMaximumBPGPixelCount = 20000000;

static void _release_bpg_rgb_data(void* info, const void* data, size_t size)
{
	(void)info;
	(void)size;
	free((void*)data);
}

#ifdef NYX_QL_SUPPORT_BPG_DECODE
CF_RETURNS_RETAINED CGImageRef decode_bpg_at_path(CFStringRef filepath, image_infos* infos)
{
	// Read file
	uint8_t* buffer = NULL;
	const size_t file_size = read_file(filepath, &buffer);
	if (0 == file_size)
	{
		free(buffer);
		return NULL;
	}

	// Decode image
	BPGDecoderContext* bpg_ctx = bpg_decoder_open();
	if (bpg_ctx == NULL)
	{
		free(buffer);
		return NULL;
	}
	int ret = bpg_decoder_decode(bpg_ctx, buffer, (int)file_size);
	free(buffer);
	if (ret < 0)
	{
		bpg_decoder_close(bpg_ctx);
		return NULL;
	}

	// Get image infos
	BPGImageInfo img_info_s, *img_info = &img_info_s;
	if (bpg_decoder_get_info(bpg_ctx, img_info) < 0)
	{
		bpg_decoder_close(bpg_ctx);
		return NULL;
	}
	const size_t w = (size_t)img_info->width;
	const size_t h = (size_t)img_info->height;
	if (w == 0 || h == 0 || w > kMaximumBPGDimension || h > kMaximumBPGDimension ||
		w > kMaximumBPGPixelCount / h)
	{
		bpg_decoder_close(bpg_ctx);
		return NULL;
	}

	// Choose output colorspace (RGB / RGBA)
	const size_t num_c = img_info->has_alpha ? 4 : 3;
	if (w > SIZE_MAX / num_c)
	{
		bpg_decoder_close(bpg_ctx);
		return NULL;
	}
	const size_t stride = num_c * w;
	if (h > SIZE_MAX / stride)
	{
		bpg_decoder_close(bpg_ctx);
		return NULL;
	}
	const size_t img_size = stride * h;
	uint8_t* rgb_buffer = (uint8_t*)malloc(img_size);
	if (rgb_buffer == NULL)
	{
		bpg_decoder_close(bpg_ctx);
		return NULL;
	}
	size_t idx = 0;
	if (bpg_decoder_start(bpg_ctx, img_info->has_alpha ? BPG_OUTPUT_FORMAT_RGBA32 : BPG_OUTPUT_FORMAT_RGB24) < 0)
	{
		free(rgb_buffer);
		bpg_decoder_close(bpg_ctx);
		return NULL;
	}
	for (size_t y = 0; y < h; y++)
	{
		if (bpg_decoder_get_line(bpg_ctx, rgb_buffer + idx) < 0)
		{
			free(rgb_buffer);
			bpg_decoder_close(bpg_ctx);
			return NULL;
		}
		idx += stride;
	}
	bpg_decoder_close(bpg_ctx);

	if (infos != NULL)
	{
		infos->width = w;
		infos->height = h;
		infos->filesize = file_size;
	}

	// Create CGImage
	CGDataProviderRef data_provider = CGDataProviderCreateWithData(NULL, rgb_buffer, img_size, _release_bpg_rgb_data);
	if (data_provider == NULL)
	{
		free(rgb_buffer);
		return NULL;
	}
	CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
	CGImageRef img_ref = CGImageCreate(w, h, 8, 8 * num_c, stride, color_space, kCGBitmapByteOrderDefault | ((img_info->has_alpha) ? kCGImageAlphaPremultipliedLast : kCGImageAlphaNone), data_provider, NULL, true, kCGRenderingIntentDefault);
	CGColorSpaceRelease(color_space);
	CGDataProviderRelease(data_provider);
	return img_ref;
}
#endif /* NYX_QL_SUPPORT_BPG_DECODE */

#ifdef NYX_MD_SUPPORT_BPG_DECODE
bool get_bpg_informations_for_filepath(CFStringRef filepath, image_infos* infos)
{
	// Read file
	uint8_t* buffer = NULL;
	const size_t size = read_file(filepath, &buffer);
	if (0 == size)
	{
		free(buffer);
		return false;
	}

	// Decode image
	BPGDecoderContext* bpg_ctx = bpg_decoder_open();
	if (bpg_ctx == NULL)
	{
		free(buffer);
		return false;
	}
	int ret = bpg_decoder_decode(bpg_ctx, buffer, (int)size);
	free(buffer);
	if (ret < 0)
	{
		bpg_decoder_close(bpg_ctx);
		return false;
	}

	// Get image infos
	BPGImageInfo img_info_s, *img_info = &img_info_s;
	if (bpg_decoder_get_info(bpg_ctx, img_info) < 0)
	{
		bpg_decoder_close(bpg_ctx);
		return false;
	}
	infos->width = (size_t)img_info->width;
	infos->height = (size_t)img_info->height;
	infos->has_alpha = (uint8_t)img_info->has_alpha;
	infos->bit_depth = (uint8_t)img_info->bit_depth;
	colorspace_t cs = colorspace_unknown;
	const BPGColorSpaceEnum color_space = (BPGColorSpaceEnum)img_info->color_space;
	switch (color_space)
	{
		case BPG_CS_RGB:
			cs = colorspace_rgb;
			break;
		case BPG_CS_YCbCr:
			cs = colorspace_ycbcr;
			break;
		case BPG_CS_YCgCo:
			cs = colorspace_ycgco;
			break;
		case BPG_CS_YCbCr_BT709:
			cs = colorspace_bt709;
			break;
		case BPG_CS_YCbCr_BT2020:
			cs = colorspace_bt2020;
			break;
		default:
			cs = colorspace_unknown;
	}
	infos->colorspace = cs;
	bpg_decoder_close(bpg_ctx);

	return true;
}
#endif /* NYX_MD_SUPPORT_BPG_DECODE */
