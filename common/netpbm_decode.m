#import "netpbm_decode.h"

#ifdef NYX_MD_SUPPORT_NETPBM_DECODE

#include <stdint.h>
#include <stdio.h>
#include <sys/stat.h>

static const size_t kMaximumDimension = 100000;
static const size_t kMaximumPixelCount = 100000000;
enum { kMaximumHeaderSize = 65536 };

static bool _is_netpbm_whitespace(uint8_t byte)
{
	return byte == ' ' || byte == '\t' || byte == '\n' || byte == '\r' || byte == '\f' || byte == '\v';
}

static bool _read_netpbm_dimension(const uint8_t* bytes, const size_t size, size_t* index, size_t* value)
{
	while (*index < size)
	{
		if (_is_netpbm_whitespace(bytes[*index]))
		{
			(*index)++;
			continue;
		}

		if (bytes[*index] == '#')
		{
			while (*index < size && bytes[*index] != '\n' && bytes[*index] != '\r')
				(*index)++;
			continue;
		}

		break;
	}

	if (*index >= size || bytes[*index] < '0' || bytes[*index] > '9')
		return false;

	size_t parsed = 0;
	size_t digits = 0;
	while (*index < size && bytes[*index] >= '0' && bytes[*index] <= '9')
	{
		const size_t digit = (size_t)(bytes[*index] - '0');
		if (parsed > (SIZE_MAX - digit) / 10)
			return false;
		parsed = parsed * 10 + digit;
		(*index)++;
		digits++;
	}

	if (digits == 0 || parsed == 0 || parsed > kMaximumDimension)
		return false;
	if (*index >= size || (!_is_netpbm_whitespace(bytes[*index]) && bytes[*index] != '#'))
		return false;

	*value = parsed;
	return true;
}

bool get_netpbm_informations_for_filepath(CFStringRef filepath, image_infos* infos)
{
	NSString* path = (__bridge NSString*)filepath;
	FILE* file = fopen(path.fileSystemRepresentation, "rb");
	if (file == NULL)
		return false;

	struct stat file_info;
	if (fstat(fileno(file), &file_info) != 0 || file_info.st_size < 0)
	{
		fclose(file);
		return false;
	}
	const size_t file_size = (size_t)file_info.st_size;
	uint8_t buffer[kMaximumHeaderSize];
	const size_t size = fread(buffer, 1, sizeof(buffer), file);
	fclose(file);
	if (size < 3)
		return false;

	if (buffer[0] != 'P' || buffer[1] < '1' || buffer[1] > '6' || !_is_netpbm_whitespace(buffer[2]))
		return false;

	size_t index = 2;
	size_t width = 0;
	size_t height = 0;
	const bool has_dimensions = _read_netpbm_dimension(buffer, size, &index, &width) &&
		_read_netpbm_dimension(buffer, size, &index, &height);

	if (!has_dimensions || width > kMaximumPixelCount / height)
		return false;

	infos->width = width;
	infos->height = height;
	infos->filesize = file_size;
	infos->has_alpha = 0;
	infos->bit_depth = 8;
	infos->colorspace = colorspace_rgb;
	return true;
}

#endif /* NYX_MD_SUPPORT_NETPBM_DECODE */
