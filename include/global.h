#ifndef _global_h_
#define _global_h_

#include "type.h"
#include "const.h"

#ifndef define_global_here
#define extern_flag	extern
#else
#define extern_flag
#endif

extern_flag descriptor_t		g_gdt[gdt_size];
extern_flag gate_t				g_idt[idt_size];
extern_flag tss_t				g_tss;

extern_flag u16_t*				g_screen_cursor;
extern_flag char* 				g_log_cursor;

extern_flag int					g_addr_range_count;
extern_flag addr_range_desc_t	g_addr_range[addr_range_max_count];

extern_flag kernel_image_info_t g_kernel_image;


#endif
