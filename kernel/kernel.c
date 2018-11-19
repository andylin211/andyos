#define define_global_here
#include "global.h"
#include "mm.h"

static stack_frame_t sf;

static void _declspec(naked) testA(void)
{
/*	char* p = 0;
	u8_t fg = 0;
	*/
	__asm {
		xor eax, eax
			xor eax, eax
			xor eax, eax
			xor eax, eax
			jmp $
	}/*	for (;;)
	{
		p = (char*)(screen_init_cursor + 3);
		fg = *p & 0x7;
		fg++;

		*p = (*p & 0xf8) | fg;
	}*/
}

static void _declspec(naked) goto_ring3(void)
{
	sf.eflags = 0x202;
	sf.eip = (u32_t)(void*)testA;
	sf.cs = ring3_code_selector;
	sf.ss = ring3_data_selector;
	sf.esp = 0x400;

	
	__asm
	{
		lea		eax, [sf + 68]
		mov		[g_tss + 4], eax
		lea		eax, [sf]
		mov		esp, eax
		pop		gs
		pop		fs
		pop		es
		pop		ds
		popad
		iretd
	}
}

// ----------------

void out_byte(u16_t port, u8_t val)
{
	__asm
	{
		mov 	al, [val]
		mov 	dx, [port]
		out 	dx, al
		nop
		nop
	}
}

static void eoi(void)
{
	out_byte(int_m_ctl, 0x20);
}

static void blink(void)
{
	char* p = (char*)(screen_init_cursor+1);
	u8_t fg = *p & 0x7;
	fg++;

	*p = (*p & 0xf8) | fg;
}

static void _declspec(naked) clock_handler(void)
{
	// t_printf(".");
	__asm
	{
		pushad
		push	ds
		push	es
		push	fs
		push	gs
	}
	blink();
	eoi();

	__asm
	{
		lea		eax, [sf + 68]
		mov[g_tss + 4], eax
		mov		esp, sf
		pop		gs
		pop		fs
		pop		es
		pop		ds
		popad
		iretd
	}
}

static void set_descriptor(descriptor_t* desc, u32_t base, u32_t limit, u16_t attr)
{
	desc->base_low = base & 0xffff;
	desc->limit_low	= limit & 0xffff;
	desc->base_mid = (base >> 16) & 0xff;
	desc->attr1 = attr & 0xff;
	desc->limit_high_attr2 = ((limit >> 16) & 0xf) | ((attr >> 8) & 0xf0);
	desc->base_high = (base >> 24) & 0xff;
}

static void init_tss(void)
{
	t_printf("tss: 0x%x\r\n", (u32_t)(void*)&g_tss);

	t_memset(&g_tss, 0, sizeof(tss_t));

	g_tss.io_base = sizeof(tss_t);
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

	t_printf("gdt: 0x%x\r\n", (u32_t)(void*)&g_gdt);
	
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

static void set_gate(gate_t* gate, u32_t entry)
{
	gate->attr = gate_attr;
	gate->entry_low = entry & 0xffff;
	gate->entry_high = (entry >> 16) & 0xffff;
	gate->selector = ring0_code_selector;
}

static void init_idt(void)
{
	int i = 0;
	idt_ptr_t idt_ptr = { 0 };

	t_printf("idt: 0x%x\r\n", (u32_t)(void*)&g_idt);
	
	/* zero */
	for (i = 0; i < idt_size; i++)
		t_memset(&g_idt[i], 0, sizeof(gate_t));

	/* set */
	set_gate(&g_idt[clock_int_no], (u32_t)(void*)clock_handler);
	// t_printf("idt: 0x%x -> 0x%x\r\n", clock_int_no, (u32_t)(void*)clock_handler);

	/* set ptr */
	idt_ptr.address = (u32_t)(void*)&g_idt;
	idt_ptr.limit = sizeof(gate_t) * idt_size - 1;

	__asm lidt[idt_ptr]
}

/*
* 8259a master port is 20h and 21h
* 		slave port is a0h and a1h
* 
* icw: initialization control word
* ocw: operation control word
*/

/*
* icw1 (20h or a0h)
* icw1{0} = 1 (need icw4)
* icw1{1} = 0 (slave 8259a)
* icw1{2} = 0 (8 byte interrupt vector)
* icw1{3} = 0 (edge triggered mode)
* icw1{4} = 1 (must 1)
* icw1{7..5} = 0 (must 0)
*	eg: out_byte(0x20, 0x11);
* 
* icw2 (21h or a1h)
* icw2{2..0}	= 0 (80x86 arch)
* icw2{7..3}	= 0x20 (irq0 start from 0x20)
*	eg: out_byte(0x21, 0x20);
* 
* icw3 (21h, master)
* icw3	= 00000100b (irq2 connects to slave)
* 	eg: out_byte(0x21, 0x04);
*
* icw3 (a1h, slave)
* icw3{2..0}	= 0x2 (slave's irq2 connects to master)
* icw3{7..3}	= 0
* 
* icw4 (21h or a1h)
* icw4{0}		= 1 (80x86 mode)
* icw4{1} 	= 0 (normal eoi)
* icw4{3..2}	= 0 (buffer mode)
* icw4{4}		= 0 (sequence mode)
* icw4{7..5}	= 0 (not used)
* 	eg: out_byte(0x21, 0x01); 
*
* ocw1 (21h, a1h)
* ocw1{7..0}	= 11111110b (1 for disable)
* 	eg: out_byte(0x21, 0xfe) //enable clock only
*
* ocw2 (20h, a0h)
* ocw2{5}		= 1 (send end of interrupt to device!)
* 	eg: out_byte(0x20, 0x20)
*/

static void init_8259a(void)
{
	out_byte(int_m_ctl, 0x11); 
	out_byte(int_s_ctl, 0x11);		// basic 

	out_byte(int_m_ctlmask, 0x20); 	// irq0 is 0x20
	out_byte(int_s_ctlmask, 0x28); 	// irq0 is 0x28
	
	out_byte(int_m_ctlmask, 0x04); 
	out_byte(int_s_ctlmask, 0x02); 	// connect point

	out_byte(int_m_ctlmask, 0x01); 
	out_byte(int_s_ctlmask, 0x01);  // icw4

	out_byte(int_m_ctlmask, 0xfe);	// enable clock
	out_byte(int_s_ctlmask, 0xff); 	// disable all
}

static void init_clock(void)
{
	out_byte(timer_mode, rate_generator);

	out_byte(timer0, count_down_high);
	out_byte(timer0, count_down_low);
}

static void init_global(void)
{
	int i = 0;

	u16_t* p = (u16_t*)log_start_address;
	g_screen_cursor = (u16_t*)(2 * (u32_t)*p + screen_init_cursor);

	g_log_cursor = (char*)log_start_address;

	t_printf("g_screen_cursor: 0x%x, g_log_cursor: 0x%x\r\n", &g_screen_cursor, &g_log_cursor);

	g_addr_range_count = (int)*(u32_t*)(addr_range_start_addr - 4);
	t_printf("g_addr_range_count: 0x%x\r\n", g_addr_range_count);

	t_memcpy(g_addr_range, (void*)addr_range_start_addr, sizeof(addr_range_desc_t) * g_addr_range_count);
	for (i = 0; i < g_addr_range_count; i++)
	{
		switch (g_addr_range[i].type)
		{
		case addr_range_reserved:
			t_printf("base: 0x%x, length: 0x%x, type=reserved\r\n", g_addr_range[i].base, g_addr_range[i].length);
			break;
		case addr_range_memory:
			t_printf("base: 0x%x, length: 0x%x, type=memory\r\n", g_addr_range[i].base, g_addr_range[i].length);
			break;
		default:
			t_printf("base: 0x%x, length: 0x%x, type=unknown\r\n", g_addr_range[i].base, g_addr_range[i].length);
			break;
		}
	}

	g_kernel_image = *(kernel_image_info_t*)0x6000;
	t_printf("[0x%x,0x%x,0x%x][0x%x,0x%x][0x%x,0x%x]\r\n",
		g_kernel_image.image_base,
		g_kernel_image.code_base,
		g_kernel_image.data_base,
		g_kernel_image.code_offset,
		g_kernel_image.code_size,
		g_kernel_image.data_offset,
		g_kernel_image.data_size
		);
}

static void idle()
{
	for (;;) {
		__asm nop
	}
}

void main(void)
{
	init_global();

	init_gdt();

	init_idt();

	init_tss();

	init_clock();

	init_8259a();

	init_virtual_memory_mapping();

	// __asm sti

	goto_ring3();

	idle();
}
