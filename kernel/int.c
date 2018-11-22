#include "include/global.h"
#include "include/t_stdio.h"
#include "include/t_string.h"
#include "include/basic.h"

static void __declspec(naked) restart2()
{
	__asm {
		mov 	eax, [g_reenter]
		dec 	eax
		mov 	[g_reenter], eax
		pop		gs
		pop		fs
		pop		es
		pop		ds
		popad
		add		esp, 4
		iretd
	}
}

void __declspec(naked) restart()
{
	g_tss.esp0 = g_proc_running->regs_top;
	__asm {
		mov		esp, [g_proc_running]
		jmp 	restart2
	}
}

static void __declspec(naked) save()
{
	__asm
	{
		cld 								// set df to a known value
		pushad
		push    ds
		push    es
		push    fs
		push    gs
		mov		ax, ss
		mov		ds, ax
		mov		es, ax
		mov 	eax, [g_reenter]
		inc 	eax
		mov 	[g_reenter], eax
		cmp 	eax, 0
		jne 	reenter// reentered
		
		mov		esi, esp 					// esi -> regs
		mov     esp, [g_kernel_stack_top]	// switch stack
		push    restart 					// magic! ret will use this
		mov		eax, [esi+ret_offset]
		mov		[esp-4], eax
		mov		eax, [esi+eax_offset]		// recover eax, esi
		mov		esi, [esi+esi_offset]
		jmp     [esp-4]						// goto ret addr (pushed by calling save())

	reenter:
		push 	restart2
		jmp 	[esp + ret_offset + 4]
	}
}


static void schedule(void)
{
	g_proc_running->ticks--;
	if (g_proc_running->ticks > 0)
		return;

	g_proc_running->ticks = g_proc_running->priority;
	g_proc_running = (g_proc_running == g_pcb) ? &g_pcb[1] : g_pcb;
}

static void disable_clock(void)
{
	char flag = in_byte(int_m_ctlmask);
	flag |= 0x01;
	out_byte(int_m_ctlmask, flag);
}

static void enable_clock(void)
{
	char flag = in_byte(int_m_ctlmask);
	flag &= 0xfe;
	out_byte(int_m_ctlmask, flag);
}

static void blink(u32_t i)
{
	char* p = (char*)(screen_init_cursor + 2 * i + 1);
	u8_t fg = *p & 0x7;
	fg++;

	*p = (*p & 0xf8) | fg;
}

void __declspec(naked) clock_handler(void)
{
	save(); 	// magic! 
	disable_clock();
	eoi();
	__asm sti
	g_ticks++;
	blink(0);
	schedule();
	__asm int 0x80
	__asm cli
	enable_clock();
	__asm ret 	// magic! this routine return to restart
}

void __declspec(naked) syscall_handler(void)
{
	save();
	blink(3);
	__asm ret
}


void init_idt(void)
{
	int i = 0;
	idt_ptr_t idt_ptr = { 0 };

	t_printf("idt: 0x%x\r\n", (u32_t)(void*)&g_idt);
	
	/* zero */
	for (i = 0; i < idt_size; i++)
		t_memset(&g_idt[i], 0, sizeof(gate_t));

	/* set */
	set_gate(&g_idt[clock_int_no], (u32_t)(void*)clock_handler, gate_attr);
	set_gate(&g_idt[syscall_int_no], (u32_t)(void*)syscall_handler, syscall_attr);
	t_printf("clock_handler: 0x%x, syscall_handler: 0x%x\r\n", clock_handler, syscall_handler);

	/* set ptr */
	idt_ptr.address = (u32_t)(void*)&g_idt;
	idt_ptr.limit = sizeof(gate_t) * idt_size - 1;

	__asm lidt[idt_ptr]
}
