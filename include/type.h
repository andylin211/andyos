#ifndef _type_h_
#define _type_h_

#include "const.h"

typedef unsigned char 	u8_t;
typedef unsigned short 	u16_t;
typedef unsigned long 	u32_t;
typedef u32_t			bool;
#define true			-1
#define false			0

//__attribute__((__packed__))

#pragma pack (1)
typedef struct _descriptor_t
{
	u16_t 	limit_low;
	u16_t 	base_low;
	u8_t 	base_mid;
	u8_t 	attr1;
	u8_t 	limit_high_attr2;
	u8_t 	base_high;
}descriptor_t;

typedef struct _gdt_ptr_t
{
	u16_t	limit;
	u32_t	address;
}gdt_ptr_t, idt_ptr_t;

typedef struct _gate_t
{
	u16_t 	entry_low;
	u16_t 	selector;		/* ring0_code_selector */
	u16_t 	attr; 			/* (10001110b<<8) P-DPL-S TYPE(386 int gate) */
	u16_t 	entry_high;
}gate_t;

typedef struct _tss_t
{
	u32_t	back_link;
	u32_t	esp0;
	u32_t	ss0;
	u32_t	other_regs[22];	/* not interested */
	u16_t	debug_trap;		/* 0 */
	u16_t	io_base;		/* 104 */
	u8_t	end_of_io;		/* 0xff */
}tss_t;

typedef struct _stack_frame_t
{
	u32_t	gs;
	u32_t	fs;
	u32_t	es;
	u32_t	ds;
	u32_t	edi;
	u32_t	esi;
	u32_t	ebp;
	u32_t	kernel_esp;	// popad will ignore it
	u32_t	ebx;
	u32_t	edx;
	u32_t	ecx;
	u32_t	eax;
	u32_t	eip;
	u32_t	cs;
	u32_t	eflags;
	u32_t	esp;
	u32_t	ss;
}stack_frame_t;

typedef struct _pcb_t
{
	stack_frame_t	regs;
	char*			regs_top;
	void*			entry;
	u32_t			pid;
	char			name[16];
	char*			stack_top;
	char			stack[user_stack_size];
}pcb_t;

typedef struct _addr_range_desc_t
{
	u32_t	base;
	u32_t	base_high;
	u32_t	length;
	u32_t	length_high;
	u32_t	type;
}addr_range_desc_t;

typedef u32_t pde_t;

typedef u32_t pte_t;

typedef enum _page_type
{
	page_reserved = 0,
	page_free,
	page_used,
}page_type;

typedef struct _physical_page_t
{
	page_type type;
}physical_page_t;

typedef struct _kernel_image_info_t
{
	u32_t image_base;
	u32_t code_base;
	u32_t data_base;
	u32_t code_offset;
	u32_t code_size;
	u32_t data_offset;
	u32_t data_size;
}kernel_image_info_t;

#pragma pack ()


#endif