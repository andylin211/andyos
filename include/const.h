#ifndef _const_h_
#define _const_h_

#define kernel_image_base 		0x400000
#define kernel_image_code_base	0x1000
#define memory_size				0x2000000

#define log_start_address 		0x10000

#define ring0_code_index 		1
#define ring0_data_index	 	2	
#define ring3_code_index 		3
#define ring3_data_index	 	4	
#define ring0_tss_index 		5

#define ring0_code_selector 	8
#define ring0_data_selector	 	16	
#define ring3_code_selector 	24
#define ring3_data_selector	 	32
#define ring0_tss_selector 		40

/* (high->low:|g|db|0|avl|+|0000|+|p|dpl|s|+|type|) */
#define ring0_code_attr			0xc09a	//	((1100b<<12)+(1001b<<4)+0xa)	/* 0xa exec/read */
#define ring0_data_attr			0xc092	//	((1100b<<12)+(1001b<<4)+0x2)	/* 0x2 read/write */
#define ring3_code_attr			0xc0fa	//	((1100b<<12)+(1111b<<4)+0xa)	/* 0xa exec/read */
#define ring3_data_attr			0xc0f2	//	((1100b<<12)+(1111b<<4)+0x2)	/* 0x2 read/write */
#define ring0_tss_attr			0x89	//	((1000b<<4)+0x9) 				/* p-dpl-g 0x9(386 tss) */

#define gate_attr				0x8e00	//	(10001110b << 8)

#define	gdt_size				128
#define	idt_size				128

#define clock_int_no			0x20

/* interrupt */
#define int_m_ctl				0x20
#define int_m_ctlmask			0x21
#define int_s_ctl				0xa0
#define int_s_ctlmask			0xa1

/* timer */
#define timer_mode 				0x43
#define timer0					0x40
#define rate_generator 			0x34
/* count down 1 every clk cycle */
/* for pc, clk_cycle_hz equals to 1193180 */
#define count_down_high			0xff
#define count_down_low 			0xff

/* screen */
#define screen_init_cursor		0xb8000
#define screen_width			80
#define	screen_height			25
#define screen_end_cursor		(0xb8000 + screen_width * screen_height * 2)
#define	cursor_index_port		0x3d4
#define	cursor_set_high_byte	0x0e
#define	cursor_set_low_byte		0x0f
#define cursor_rw_port			0x3d5
/* BL R G B I R G B -> blink bg highlight fg*/
#define white_on_black			0x07

/* address range */
#define addr_range_memory		0x1
#define addr_range_reserved		0x2
#define addr_range_max_count	0x10
#define addr_range_start_addr	0x7f00

/* mm */
#define system_address_start	0x80000000

#define pde_max					0x400
#define pte_max					0x400
#define page_size				0x1000

#endif