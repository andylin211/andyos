#include "include/type.h"

int t_memset(void* addr, u8_t val, int size)
{
	int ret = size;
	u8_t* p = (u8_t*)addr;

	if (!p || (size <= 0))
		return 0;

	while (size)
	{
		*p = val;
		p++;
		size--;
	}

	return ret;
}

/*
* same addr:		do nothing
* overlapped:
*	1. dst > src && (src + size) > dst
*	2. dst < src && (dst + size) > src
* not overlapped:	same as overlapped 2
*/
int t_memcpy(void* dst, void* src, int size)
{
	int ret = size;
	u8_t* p = (u8_t*)src;
	u8_t* q = (u8_t*)dst;

	if (!p || !q || (size <= 0))
		return 0;

	/* same addr */
	if (p == q)
		return 0;
	
	/* overlapped 1 */
	if (q > p && (p + size) > q)
	{
		/* reverse copy */
		p = p + size - 1;
		q = q + size - 1;
		while (size)
		{
			*q = *p;
			p--;
			q--;
			size--;
		}
	}
	/* not overlapped or overlapped 2 */
	else 
	{
		while (size)
		{
			*q = *p;
			p++;
			q++;
			size--;
		}
	}

	return ret;
}

int t_strlen(char* str)
{
	int count = 0;

	if (!str)
		return 0;

	while (*str)
	{
		count++;
		str++;
	}

	return count;
}

int t_strcpy(char* dst, char* src)
{
	if (!dst || !src || src == dst || !t_strlen(src))
		return 0;

	if (t_memcpy(dst, src, t_strlen(src) + 1))
		return t_strlen(src);
	
	return 0;
}