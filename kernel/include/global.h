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

extern_flag pcb_t*				g_proc_running;
extern_flag pcb_t				g_pcb[2];

extern_flag char				g_kernel_stack[kernel_stack_size];
extern_flag char*				g_kernel_stack_top;

extern_flag u32_t				g_ticks;
extern_flag u32_t				g_reenter;

extern_flag void*               g_irq_table[nr_irq];
extern_flag void*               g_syscall_table[nr_syscall];

extern_flag u16_t*				g_screen_cursor;

extern_flag int					g_addr_range_count;
extern_flag addr_range_desc_t	g_addr_range[addr_range_max_count];

extern_flag kernel_image_info_t g_kernel_image;


#endif
