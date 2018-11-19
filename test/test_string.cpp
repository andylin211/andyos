#include "..\include\t_string.h"
#include "tinyutest.h"

/*
* int t_memset(void* addr, u8_t val, int size)
*
* case:
*	val = 'a', size = 10
* except:
*	addr = 0
*	size = 0
*	size = -1
*/

TEST(string, t_memset_vala_size10)
{
	char buffer[256] = { 0 };
	EXPECT(10 == t_memset(buffer, 'a', 10));
	EXPECT('a' == buffer[0]);
	EXPECT('a' == buffer[9]);
	EXPECT(0 == buffer[10]);
}

TEST(string, t_memset_addr_null)
{
	EXPECT(0 == t_memset(0, 'a', 10));
}

TEST(string, t_memset_size_zero)
{
	char buffer[256] = { 0 };
	EXPECT(0 == t_memset(buffer, 'a', 0));
}

TEST(string, t_memset_size_negtive_one)
{
	char buffer[256] = { 0 };
	EXPECT(0 == t_memset(buffer, 'a', -1));
}

/*
* int t_memcpy(void* dst, void* src, int size)
*
* case:
*	1. dst == src
*	2. overlapped when src < dst
*	3. overlapped when dst < src
*	4. not overlapped
*	5. size = 0
*	6. size = -1
*	7. src = 0
*	8. dst = 0
*/

TEST(string, t_memcpy_dst_equal_to_src)
{
	char buffer[256] = { 0 };
	EXPECT(0 == t_memcpy(buffer, buffer, 10));
}

TEST(string, t_memcpy_overlapped_src_lower_than_dst)
{
	char buffer[256] = "0123456789abcdef";
	EXPECT(10 == t_memcpy(&buffer[5], buffer, 10));
	EXPECT('0' == buffer[5]);
	EXPECT('9' == buffer[14]);
}

TEST(string, t_memcpy_overlapped_src_larger_than_dst)
{
	char buffer[256] = "0123456789abcdef";
	EXPECT(10 == t_memcpy(buffer, &buffer[5], 10));
	EXPECT('5' == buffer[0]);
	EXPECT('e' == buffer[9]);
}

TEST(string, t_memcpy_not_overlapped)
{
	char buffer[256] = "0123456789abcdef";
	EXPECT(5 == t_memcpy(buffer, &buffer[5], 5));
	EXPECT('5' == buffer[0]);
	EXPECT('9' == buffer[4]);
}

TEST(string, t_memcpy_size_zero)
{
	char buffer[256] = "0123456789abcdef";
	EXPECT(0 == t_memcpy(buffer, &buffer[5], 0));
}

TEST(string, t_memcpy_size_negtive_one)
{
	char buffer[256] = "0123456789abcdef";
	EXPECT(0 == t_memcpy(buffer, &buffer[5], -1));
}

TEST(string, t_memcpy_src_null)
{
	char buffer[256] = "0123456789abcdef";
	EXPECT(0 == t_memcpy(buffer, 0, 10));
}

TEST(string, t_memcpy_dst_null)
{
	char buffer[256] = "0123456789abcdef";
	EXPECT(0 == t_memcpy(0, buffer, 10));
}

/*
* int t_strlen(char* str);
*
* case:
*	1. str = "abc"
*	2. str = 0
*	3. str empty
*/
TEST(string, t_strlen_str_abc)
{
	char str[256] = "abc";
	EXPECT(3 == t_strlen(str));
}

TEST(string, t_strlen_str_null)
{
	EXPECT(0 == t_strlen(0));
}

TEST(string, t_strlen_str_empty)
{
	char str[256] = "";
	EXPECT(0 == t_strlen(str));
}

/*
* int t_strcpy(char* dst, char* src);
* case:
*	1. dst = 0
*	2. src = 0
*	3. src = dst
*	4. src empty
*	5. src dst ok
*/
TEST(string, t_strcpy_dst_null)
{
	char src[256] = "";
	EXPECT(0 == t_strcpy(0, src));
}

TEST(string, t_strcpy_src_null)
{
	char dst[256] = "";
	EXPECT(0 == t_strcpy(dst, 0));
}

TEST(string, t_strcpy_src_equals_to_dst)
{
	char dst[256] = "";
	EXPECT(0 == t_strcpy(dst, dst));
}

TEST(string, t_strcpy_src_empty)
{
	char src[256] = "";
	char dst[256] = { 0 };
	EXPECT(0 == t_strcpy(dst, src));
}

TEST(string, t_strcpy_src_dst_ok)
{
	char src[256] = "abc";
	char dst[256] = { 0 };
	EXPECT(3 == t_strcpy(dst, src));
	EXPECT(0 == strcmp("abc", dst));
}