#define define_global_here
#include "include/global.h"
#include "include/mm.h"
#include "include/t_string.h"
#include "include/t_stdio.h"
#include "include/basic.h"
#include "include/8259a.h"
#include "include/int.h"
#include "include/proc.h"
#include "include/clock.h"
#include "include/syscall.h"


static void init_tss(void)
{
	t_memset(&g_tss, 0, sizeof(tss_t));

	g_tss.io_base = sizeof(tss_t) - 1;
	g_tss.end_of_io = 0xff;
	g_tss.ss0 = ring0_data_selector;

	__asm
	{
		mov		ax, tss_selector
		ltr		ax
	}
}

static void init_gdt(void)
{
	int i = 0;
	gdt_ptr_t gdt_ptr = { 0 };

	/* zero */
	for (i = 0; i < gdt_size; i++)
		t_memset(&g_gdt[i], 0, sizeof(descriptor_t));
	
	/* set */
	set_descriptor(&g_gdt[ring0_code_index], 0, 0xfffff, ring0_code_attr);
	set_descriptor(&g_gdt[ring0_data_index], 0, 0xfffff, ring0_data_attr);
	set_descriptor(&g_gdt[ring3_code_index], 0, 0xfffff, ring3_code_attr);
	set_descriptor(&g_gdt[ring3_data_index], 0, 0xfffff, ring3_data_attr);	
	set_descriptor(&g_gdt[tss_index], (u32_t)(void*)&g_tss, sizeof(tss_t) - 1, tss_attr);

	/* set ptr */
	gdt_ptr.address = (u32_t)(void*)&g_gdt;
	gdt_ptr.limit = sizeof(descriptor_t) * gdt_size - 1;

	__asm lgdt[gdt_ptr]
}

static void init_global(void)
{
	u16_t* p = (u16_t*)log_start_address;
	g_screen_cursor = (u16_t*)(2 * (u32_t)*p + screen_init_cursor);

	g_ticks = 0;
	g_reenter = 0;

	g_kernel_stack_top = g_kernel_stack + kernel_stack_size;

	g_addr_range_count = (int)*(u32_t*)(addr_range_start_addr - 4);

	t_memcpy(g_addr_range, (void*)addr_range_start_addr, sizeof(addr_range_desc_t) * g_addr_range_count);

	g_kernel_image = *(kernel_image_info_t*)0x6000;

	t_printf("---- tinyos kernel ----\r\n");
}

static void debug_helper(void)
{
	t_printf("[0x%x,0x%x,0x%x][0x%x,0x%x][0x%x,0x%x]\r\n",
		g_kernel_image.image_base,
		g_kernel_image.code_base,
		g_kernel_image.data_base,
		g_kernel_image.code_offset,
		g_kernel_image.code_size,
		g_kernel_image.data_offset,
		g_kernel_image.data_size
		);
	
	t_printf("gdt: 0x%x, idt: 0x%x, tss: 0x%x\r\n", 
		(u32_t)(void*)&g_gdt, 
		(u32_t)(void*)&g_idt,
		(u32_t)(void*)&g_tss);
		
	t_printf("restart: 0x%x\r\n", restart);
}

int main(void)
{	
	init_global();

	init_gdt();

	init_idt();

	init_tss();

	init_virtual_memory_mapping();

	init_process();

	init_8259a();

	init_clock();

	init_syscall();

	debug_helper();

	restart();
}
