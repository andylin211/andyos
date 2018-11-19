#include "..\include\t_stdio.h"
#include "tinyutest.h"

char buf[256];
char* pbuf;

extern "C" void print_char(char ch)
{
	*pbuf = ch;
	pbuf++;
}


/*
* void t_printf(char* format, ...);
*
* case:
*	1. raw string
*	2. %c
*	3. %s
*	4. %x
*	5. %d
*	6. mix
*	7. null
*	8. empty
*/

TEST(stdio, t_printf_raw_string)
{
	memset(buf, 0, 256);
	pbuf = buf;
	t_printf("hello world!");
	EXPECT(0 == strcmp("hello world!", buf));
}

TEST(stdio, t_printf_char)
{
	memset(buf, 0, 256);
	pbuf = buf;
	t_printf("hello %corld!", 'w');
	EXPECT(0 == strcmp("hello world!", buf));
}

TEST(stdio, t_printf_string)
{
	memset(buf, 0, 256);
	pbuf = buf;
	t_printf("hello %s!", "world");
	EXPECT(0 == strcmp("hello world!", buf));
}

TEST(stdio, t_printf_hex)
{
	memset(buf, 0, 256);
	pbuf = buf;
	t_printf("hello world! 0x%x", 0x123abc);
	EXPECT(0 == strcmp("hello world! 0x123abc", buf));
}

TEST(stdio, t_printf_decimal)
{
	memset(buf, 0, 256);
	pbuf = buf;
	t_printf("hello world! %d", 314159);
	EXPECT(0 == strcmp("hello world! 314159", buf));
}

TEST(stdio, t_printf_mix)
{
	memset(buf, 0, 256);
	pbuf = buf;
	t_printf("%s %c %d %x haha!", "What", 'a', 425623423, 0xfe123);
	EXPECT(0 == strcmp("What a 425623423 fe123 haha!", buf));
}

TEST(stdio, t_printf_null)
{
	memset(buf, 0, 256);
	pbuf = buf;
	t_printf(0);
	EXPECT(0 == buf[0]);
}

TEST(stdio, t_printf_empty)
{
	memset(buf, 0, 256);
	pbuf = buf;
	t_printf("");
	EXPECT(0 == buf[0]);
}

