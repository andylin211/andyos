#include "include/global.h"
#include "include/t_stdio.h"
#include "include/t_string.h"
#include "include/basic.h"
#include "include/8259a.h"


static void __declspec(naked) restart2()
{
	__asm 
	{
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
	__asm 
	{
		mov		esp, [g_proc_running]
		lea 	eax, [esp + reg_top_offset]
		mov 	[g_tss + tss_esp0], eax
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
		push 	eax
		mov		eax, [esi+eax_offset]		// recover eax, esi
		mov		esi, [esi+esi_offset]
		ret									// goto ret addr (pushed by calling save())

	reenter:
		push 	restart2
		mov 	eax, [esp + ret_offset + 4]
		push 	eax
		ret
	}
}

static void blink(u32_t i)
{
	char* p = (char*)(screen_init_cursor + 2 * i + 1);
	u8_t fg = *p & 0x7;
	fg++;

	*p = (*p & 0xf8) | fg;
}

static void __declspec(naked) syscall_handler(void)
{
	__asm 
	{
		call 	save
		push 	3
		call 	blink
		add 	esp, 4
		ret
	}
}
	
#define hwint_master(irq) \
void __declspec(naked) hwint##irq(void)	\
{										\
	__asm{ call	save					}\
	__asm{ in	al, int_m_ctlmask 		}\
	__asm{ or 	al, 1 << irq			}\
	__asm{ out	int_m_ctlmask, al		}\
	__asm{ mov 	al, 0x20				}\
	__asm{ out	int_m_ctl, al 			}\
	__asm{ sti							}\
	__asm{ push irq						}\
	__asm{ call [g_irq_table + 4 * irq]	}\
	__asm{ pop 	ecx						}\
	__asm{ cli							}\
	__asm{ in  	al, int_m_ctlmask		}\
	__asm{ and 	al, ~ (1 << irq)		}\
	__asm{ out 	int_m_ctlmask, al		}\
	__asm{ ret							}\
}

hwint_master(0) 
hwint_master(1) 
hwint_master(2) 
hwint_master(3) 
hwint_master(4) 
hwint_master(5) 
hwint_master(6) 
hwint_master(7) 


#define hwint_slave(irq) \
void __declspec(naked) hwint##irq(void)	\
{										\
	__asm{ call	save					}\
	__asm{ in	al, int_s_ctlmask 		}\
	__asm{ or 	al, 1 << (irq-8)		}\
	__asm{ out	int_s_ctlmask, al		}\
	__asm{ mov 	al, 0x20				}\
	__asm{ out	int_m_ctl, al 			}\
	__asm{ nop 							}\
	__asm{ nop 							}\
	__asm{ out	int_s_ctl, al 			}\
	__asm{ sti							}\
	__asm{ push irq						}\
	__asm{ call [g_irq_table + 4 * irq]	}\
	__asm{ pop 	ecx						}\
	__asm{ cli							}\
	__asm{ in  	al, int_s_ctlmask		}\
	__asm{ and 	al, ~ (1 << (irq-9))	}\
	__asm{ out 	int_s_ctlmask, al		}\
	__asm{ ret 							}\
}

hwint_slave(8) 
hwint_slave(9) 
hwint_slave(10) 
hwint_slave(11) 
hwint_slave(12) 
hwint_slave(13) 
hwint_slave(14) 
hwint_slave(15) 

static void* hwints[NR_IRQ] = {
	hwint0, 
	hwint1, 
	hwint2, 
	hwint3, 
	hwint4, 
	hwint5, 
	hwint6, 
	hwint7, 
	hwint8, 
	hwint9, 
	hwint10, 
	hwint11, 
	hwint12, 
	hwint13, 
	hwint14, 
	hwint15
};

void init_idt(void)
{
	int i = 0;
	idt_ptr_t idt_ptr = { 0 };
	

	t_printf("idt: 0x%x\r\n", (u32_t)(void*)&g_idt);
	
	/* zero */
	for (i = 0; i < idt_size; i++)
		t_memset(&g_idt[i], 0, sizeof(gate_t));

	/* set */
	for (i = 0; i< NR_IRQ; i++) 
		set_gate(&g_idt[clock_int_no + i], (u32_t)(void*)hwints[i], gate_attr);

	// set_gate(&g_idt[clock_int_no], (u32_t)(void*)hwints[0], gate_attr);

	set_gate(&g_idt[syscall_int_no], (u32_t)(void*)syscall_handler, syscall_attr);
	t_printf("save: 0x%x, clock_handler: 0x%x, syscall_handler: 0x%x\r\n", save, hwint0, syscall_handler);

	/* set ptr */
	idt_ptr.address = (u32_t)(void*)&g_idt;
	idt_ptr.limit = sizeof(gate_t) * idt_size - 1;

	__asm lidt[idt_ptr]
}