#include "global.h"

void clear_screen(void)
{
	g_screen_cursor = (u16_t*)screen_init_cursor;

	t_memset((void*)g_screen_cursor, 0, 80 * 50 * 2);
}

void scroll_screen(void)
{
	g_screen_cursor = (u16_t*)(screen_init_cursor + (screen_height - 1) * screen_width * 2);

	t_memcpy((void*)screen_init_cursor, (void*)(screen_init_cursor + screen_width * 2), screen_height * screen_width * 2);
}

/*
* 	0x3d4 index port
*		0x0e -- set high byte
* 		0x0f -- set low byte
* 	0x3d5 read/write port
*/
void update_cursor(void)
{
	u16_t cursor_offset = ((u32_t)(void*)g_screen_cursor - screen_init_cursor) / 2;

	out_byte(cursor_index_port, cursor_set_high_byte);
	out_byte(cursor_rw_port, (cursor_offset >> 8) & 0xff);

	out_byte(cursor_index_port, cursor_set_low_byte);
	out_byte(cursor_rw_port, cursor_offset & 0xff);
}

void show_log_length(void)
{
	static char buf[256];
	u16_t* p = (u16_t*)(screen_init_cursor + screen_width * 2);
	int size = 0;

	t_ultoa((u32_t)g_log_cursor - log_start_address, buf, 10);
	size = t_strlen(buf);
	
	//__asm jmp $

	while (size)
	{
		size--;
		p--;
		
		*p = (u16_t)((white_on_black << 8) + buf[size]);
	}
}

void print_char(char ch)
{
	u16_t block = (white_on_black << 8) + ch;

	if (ch)
	{
		*g_log_cursor = ch;
		g_log_cursor++;
		show_log_length();
	}

	switch (ch)
	{
	case '\r':
		g_screen_cursor = (u16_t*)(((u32_t)(void*)g_screen_cursor - screen_init_cursor - 1) / (2 * screen_width) * 2 * screen_width + screen_init_cursor);
		break;
	case '\n':
		g_screen_cursor += screen_width;
		break;
	case 0:
		break;
	default:
		*g_screen_cursor = block;
		g_screen_cursor++;
		break;
	}

	if (g_screen_cursor >= (u16_t*)screen_end_cursor)
	{
		//clear_screen();
		scroll_screen();
	}

	update_cursor();
}


