#include "include/global.h"
#include "include/t_string.h"

static void blink(u32_t i)
{
	char* p = (char*)(screen_init_cursor + 2 * i + 1);
	u8_t fg = *p & 0x7;
	fg++;

	*p = (*p & 0xf8) | fg;
}

static void testA(void)
{
	char* p = 0;
	u8_t fg = 0;
	for (;;)
	{
		blink(1);
		//__asm int 0x80
	}
}

static void testB(void)
{
	char* p = 0;
	u8_t fg = 0;
	for (;;)
	{
		blink(2);
	}
}

void init_pcb(pcb_t* p, void* entry, char* name, u32_t pid, u32_t priority)
{
	p->entry = entry;
	t_memcpy(p->name, name, t_strlen(name));
	p->pid = pid;
	p->ticks = priority;
	p->priority = priority;
	p->stack_top = p->stack + user_stack_size;
	p->regs.cs = ring3_code_selector;
	p->regs.ss = ring3_data_selector;
	p->regs.esp = (u32_t)(void*)p->stack_top;
	p->regs.eflags = 0x202;
	p->regs.cs = ring3_code_selector;
	p->regs.eip = (u32_t)entry;
	p->regs.ds = ring3_data_selector;
	p->regs.es = ring3_data_selector;
	p->regs.fs = ring3_data_selector;
	p->regs.gs = ring3_data_selector;
}

void init_process()
{
	g_proc_running = g_pcb;
	
	init_pcb(&g_pcb[0], testA, "A", 100, 30);
	init_pcb(&g_pcb[1], testB, "B", 101, 10);
}