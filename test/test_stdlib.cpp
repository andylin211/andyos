#include "..\include\t_stdlib.h"
#include "tinyutest.h"
#include <limits>
#ifdef max
#undef max
#endif


/*
* char* ultoa(u32_t digit, char* str, int radix);
* 
* case:
*	radix = 10
*		1. digit = 4294967295
*		2. digit = 12
*
*	radix = 16
*		1. digit = 4294967295
*		2. digit = 12
*
* except:
*	radix = 2
*	str = 0
*/

TEST(stdlib, t_ultoa_max_digit_radix10)
{
	char str[256] = { 0 };
	EXPECT(0 == strcmp(t_ultoa(std::numeric_limits<u32_t>::max(), str, 10), "4294967295"));
}

TEST(stdlib, t_ultoa_digit12_radix10)
{
	char str[256] = { 0 };
	EXPECT(0 == strcmp(t_ultoa(12, str, 10), "12"));
}

TEST(stdlib, t_ultoa_max_digit_radix16)
{
	char str[256] = { 0 };
	EXPECT(0 == strcmp(t_ultoa(std::numeric_limits<u32_t>::max(), str, 16), "ffffffff"));
}

TEST(stdlib, t_ultoa_digit12_radix16)
{
	char str[256] = { 0 };
	EXPECT(0 == strcmp(t_ultoa(12, str, 16), "c"));
}

TEST(stdlib, t_ultoa_radix2)
{
	char str[256] = { 0 };
	t_ultoa(12, str, 2);
	EXPECT(0 == str[0]);
}

TEST(stdlib, t_ultoa_str_null)
{
	EXPECT(0 == t_ultoa(12, 0, 16));
}

