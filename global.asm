gdt:
	DESCRIPTOR	0, 0, 0	;(H->L:||G|DB|0|AVL|+|0000|+|P|DPL2|S|+|TYPE4||)
	DESCRIPTOR	0, 0xFFFFF, ((1100b<<12)+(1001b<<4)+0xA);0xA exec/read
	DESCRIPTOR	0, 0xFFFFF, ((1100b<<12)+(1001b<<4)+0x2);0x2 read/write
	DESCRIPTOR	(tss-$$)+0x10000, 104, 	((1000b<<4)+0x9)	;0x9 avail 386 tss
	DESCRIPTOR	(proc_ticks+LDTS-$$)+0x10000, 23,	((1000b<<4)+0x2)	;0x2 ldt
	DESCRIPTOR	(proc_print+LDTS-$$)+0x10000, 23,	((1000b<<4)+0x2)	;0x2 proc
	DESCRIPTOR	(proc_keybd+LDTS-$$)+0x10000, 23, 	((1000b<<4)+0x2)
	DESCRIPTOR	(proc_user+LDTS-$$)+0x10000,  23, 	((1000b<<4)+0x2)
	times	2*(128-8)	dd 0
idt:
	times	2*32		dd 0
	GATE		8, (clock_handler-$$)+0x10000, 	(10001110b<<8)
	GATE		8, (keyboard_handler-$$)+0x10000, (10001110b<<8)
	times	2*(128-34)	dd 0
	GATE		8, (sys_sendrecv-$$)+0x10000, 	(11101110b<<8)	;0x80
	times	2*(128-1)	dd 0
tss:
	dd		0		;backlink
	dd		0		;esp0
	dd		16		;ss0
	times	22 dd 0	;4esp/ss+17regs+1(ldt)
	dw		0	;debug trap
	dw		104	;I/O base
	db		0xFF;end of I/O
gdt_ptr:
	dw		(8*128-1)
	dd		gdt
idt_ptr:
	dw		(8*256-1)
	dd		idt
;processes
;=========
proc_ticks:
	times	13 dd 0	;defg-s and 8 common regs + retaddr
	dd		code_ticks		;eip
	dd		0x7				;cs
	dd		0x3202			;eflags
	dd		stacktop_ticks	;esp
	dd		0x17			;ss
	dd		32				;ldt_selector
	DESCRIPTOR	0, 0xFFFFF, ((1100<<12)+(1111b<<4)+0xA)	;G(4K).D/B(32).P.DPL.S.
	DESCRIPTOR	0, 0xFFFFF, ((1000<<12)+(1111b<<4)+0x2)	;data
	DESCRIPTOR	0, 0xFFFFF, ((1100<<12)+(1111b<<4)+0x2)	;stack(32)
	dd		0			;pid
	dd		0			;flag
	dd		0			;pmsg
	dd		0			;queue
	dd		0			;next
	dd		0			;precvfrom
	dd		0			;psendto
	dd		0			;hasintmsg
proc_print:
	times	13 dd 0	;defg-s and 8 common regs
	dd		code_print		;eip
	dd		0x7				;cs
	dd		0x3202			;eflags
	dd		stacktop_print	;esp
	dd		0x17			;ss
	dd		40				;ldt_selector
	DESCRIPTOR	0, 0xFFFFF, ((1100<<12)+(1111b<<4)+0xA)	;G(4K).D/B(32).P.DPL.S.
	DESCRIPTOR	0, 0xFFFFF, ((1000<<12)+(1111b<<4)+0x2)	;data
	DESCRIPTOR	0, 0xFFFFF, ((1100<<12)+(1111b<<4)+0x2)	;stack(32)
	dd		4			;pid
	dd		0			;flag
	dd		0			;pmsg
	dd		0			;queue
	dd		0			;next
	dd		0			;precvfrom
	dd		0			;psendto
	dd		0			;hasintmsg
proc_keybd:
	times	13 dd 0	;defg-s and 8 common regs
	dd		code_keybd		;eip
	dd		0x7				;cs
	dd		0x3202			;eflags
	dd		stacktop_keybd	;esp
	dd		0x17			;ss
	dd		48				;ldt_selector
	DESCRIPTOR	0, 0xFFFFF, ((1100<<12)+(1111b<<4)+0xA)	;G(4K).D/B(32).P.DPL.S.
	DESCRIPTOR	0, 0xFFFFF, ((1000<<12)+(1111b<<4)+0x2)	;data
	DESCRIPTOR	0, 0xFFFFF, ((1100<<12)+(1111b<<4)+0x2)	;stack(32)
	dd		8			;pid
	dd		0			;flag
	dd		0			;pmsg
	dd		0			;queue
	dd		0			;next
	dd		0			;precvfrom
	dd		0			;psendto
	dd		0			;hasintmsg
proc_user:
	times	13 dd 0	;defg-s and 8 common regs
	dd		code_user		;eip
	dd		0x7				;cs
	dd		0x3202			;eflags
	dd		stacktop_user	;esp
	dd		0x17			;ss
	dd		56				;ldt_selector
	DESCRIPTOR	0, 0xFFFFF, ((1100<<12)+(1111b<<4)+0xA)	;G(4K).D/B(32).P.DPL.S.
	DESCRIPTOR	0, 0xFFFFF, ((1000<<12)+(1111b<<4)+0x2)	;data
	DESCRIPTOR	0, 0xFFFFF, ((1100<<12)+(1111b<<4)+0x2)	;stack(32)
	dd		12			;pid
	dd		0			;flag
	dd		0			;pmsg
	dd		0			;queue
	dd		0			;next
	dd		0			;precvfrom
	dd		0			;psendto
	dd		0			;hasintmsg
;process schedule
;================
current:
	dd		12
proc_table:
	dd		proc_ticks
	dd		proc_print
	dd		proc_keybd
	dd		proc_user
LAST_PROC	equ	proc_user


