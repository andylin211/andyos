	mov ax, 1000h
	mov es, ax
	mov bx,	0		;es:bx
	mov ch, 0		;trk
	mov cl, 1		;sctr
	mov dh, 0		;head
	mov dl, 0		;floppya
LOOP:
	mov	ah, 2
	mov al, 8		;count
	int 13h
	cmp ax, 8
	jne	ERROR		;if read-error; then error
	inc	ch			;trk++
	cmp	ch, 16 		
	je	NEXT_64K	;if ch=16; then next64k
	cmp ch, 32		
	je	NEXT_64K 	;if ch=32; then next64k
	cmp ch, 40	
	je	FINISH		;if ch=40; then finish
	add	bx, 1000h	;bx+=512*8
	jmp	LOOP
NEXT_64K:
	mov ax, es
	add ax, 1000h
	mov es, ax
	xor bx, bx
	jmp LOOP
FINISH:
	jmp	1000h:512
ERROR:
	jmp $
times 510-($-$$) db 0
dw 0xaa55
	jmp _start
	nop
;------------------macro-----------------
%macro DESCRIPTOR	3	;base limit attr
	dw	%2 & 0xFFFF
	dw	%1 & 0xFFFF
	db	(%1 >> 16) & 0xFF
	dw	((%2 >> 8) & 0xF00) + (%3 & 0xF0FF)
	db	(%1 >> 24) & 0xFF
%endmacro
%macro GATE	3	;selector offset
	dw	%2 & 0xFFFF
	dw	%1
	dw	%3		;(P,DPL,S,TYPE=1110:386int_gate)
	dw	(%2 >> 16) & 0xFFFF
%endmacro
%define IO_DELAY	times 5 nop
%define ADDR		(0x10000+($-$$))
%define	TSS_ESP0	4
%define	TSS_SS0		8
%define STACKTOP	4*17
%define	GS			0
%define	FS			4
%define	ES			8
%define	DS			12
%define	EDI			16
%define	ESI			20
%define	EBP			24
%define	ESP			28
%define	EBX			32
%define	EDX			36
%define	ECX			40
%define	EAX			44
%define	EIP			48
%define	CS			52
%define	EFLAGS		56
%define	ESP			60
%define	SS			64
%define	LDT_SEL		68
%define	PID			88
%define	FLAG		92
%define	MSG			96
%define	QUEUE		100
%define	NEXT		104
;==================global variables================
;--------------------gdt,idt,tss---------------------
gdt		equ	ADDR
	DESCRIPTOR	0, 0, 0	;(H->L:||G|DB|0|AVL|+|0000|+|P|DPL2|S|+|TYPE4||)
	DESCRIPTOR	0, 0xFFFFF, ((1100b<<12)+(1001b<<4)+0xA);0xA exec/read
	DESCRIPTOR	0, 0xFFFFF, ((1100b<<12)+(1001b<<4)+0x2);0x2 read/write
	DESCRIPTOR	tss, 104, 	((1000b<<4)+0x9)	;0x9 avail 386 tss
	DESCRIPTOR	ldt_ticks, 16,	((1000b<<4)+0x2)	;0x2 ldt
	DESCRIPTOR	ldt_print, 16,	((1000b<<4)+0x2)	;0x2 ldt
	DESCRIPTOR	ldt_user, 16, 	((1000b<<4)+0x2)
gdt_ptr equ	ADDR
	dw		(8*7-1)
	dd		gdt
idt			equ ADDR
	%rep	32	
		GATE 0, 0, 0
	%endrep
	GATE		8, clock_handler, 	(10001110b<<8)
	GATE		8, sys_sendrecv, 	(11101110b<<8)
idt_ptr		equ ADDR
	dw		(8*34-1)
	dd		idt
tss			equ	ADDR
	times	25 dd 0	;1backlink 6esp/ss 17regs ldt
	dw		0	;debug trap
	dw		104	;I/O base
	db		0xFF;end of I/O
;---------------process----------------------------
current		equ ADDR
	dd		8
proc_table	equ ADDR
	dd		proc_ticks
	dd		proc_print
	dd		proc_user
LAST_PROC	equ	proc_user
;----------------proc_ticks-------------------------
proc_ticks	equ ADDR
	times	12 dd 0	;defg-s and 8 common regs
	dd		0		;eip
	dd		0x7		;cs
	dd		0x202	;eflags
	dd		0x1000;esp
	dd		0xF		;ss
	dd		32		;ldt_selector
ldt_ticks	equ	ADDR
	DESCRIPTOR	code_ticks, LEN_CODE_TICKS-1, ((0100<<12)+(1111b<<4)+0xA)	;D/B.P.DPL.S.
	DESCRIPTOR	0xF000, (0x1000-1), ((0100<<12)+(1111b<<4)+0x2)
	dd		0		;pid
	dd		0		;flag
	dd		0		;msgbody
	dd		0		;queue
	dd		0		;next
;----------------proc_print-------------------------
proc_print	equ ADDR
	times	12 dd 0	;defg-s and 8 common regs
	dd		0		;eip
	dd		0x7		;cs
	dd		0x202	;eflags
	dd		0x10000;esp
	dd		0xF		;ss
	dd		40		;ldt_selector
ldt_print		equ	ADDR
	DESCRIPTOR	code_print, LEN_CODE_PRINT-1, ((0100<<12)+(1111b<<4)+0xA)	;D/B.P.DPL.S.
	DESCRIPTOR	0xB8000, (0x10000-1), ((0100<<12)+(1111b<<4)+0x2)
	dd		4		;pid
	dd		0		;flag
	dd		0		;msgbody
	dd		0		;queue
	dd		0		;next
;----------------proc_user-------------------------
proc_user	equ ADDR
	times	12 dd 0	;defg-s and 8 common regs
	dd		0		;eip
	dd		0x7		;cs
	dd		0x202	;eflags
	dd		0x1000;esp
	dd		0xF		;ss
	dd		48		;ldt_selector
ldt_user		equ	ADDR
	DESCRIPTOR	code_user, LEN_CODE_USER-1, ((0100<<12)+(1111b<<4)+0xA)	;D/B.P.DPL.S.
	DESCRIPTOR	0xE000, (0x1000-1), ((0100<<12)+(1111b<<4)+0x2)
	dd		8		;pid
	dd		0		;flag
	dd		0		;msgbody
	dd		0		;queue
	dd		0		;next
;==================global code=====================
[BITS 16]
_start:
	mov		ax, 0x1000
	mov		ds, ax
	lgdt	[ds:(gdt_ptr-0x10000)]
	cli
	in		al, 0x92
	or		al, 2
	out		0x92, al
	mov		eax, cr0
	or		eax, 1
	mov		cr0, eax
	jmp		dword 8:protect_entry
[BITS 32]
protect_entry	equ	 ADDR
_protect_entry:
	mov		ax, 16
	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		gs, ax
	mov		ss, ax
	mov		esp, 0x10000
;global tss idt
	mov		ax, 24
	ltr		ax
	lidt	[idt_ptr]
;clock interrupt rate -> 100Hz
	mov		al, 0x34
	out		0x43, al
	mov		ax, 11931	;1193182
	out		0x40, al
	shr		ax, 8
	out		0x40, al
;hardware interrupt
	mov		al, 0x11	;ICW1
	out		0x20, al
	IO_DELAY
	out		0xA0, al
	IO_DELAY
	mov		al, 0x20	;ICW2
	out		0x21, al
	IO_DELAY
	mov		al, 0x28
	out		0xA1, al
	IO_DELAY
	mov		al, 0100b	;ICW3
	out		0x21, al
	IO_DELAY
	mov		al, 0x2
	out		0xA1, al
	IO_DELAY
	mov		al, 0x1		;ICW4
	out		0x21, al
	IO_DELAY
	out		0xA1, al
	IO_DELAY
	mov		al, 0xFE	;OCW1
	out		0x21, al
	IO_DELAY
	mov		al, 0xFF
	out		0xA1, al
	IO_DELAY
;first proc to run
	mov		ax, ss
	mov		[tss+TSS_SS0], ax		;ss0
	mov		eax, [current]
	mov		esi, dword [proc_table+eax]
	mov		eax, esi
	add		eax, STACKTOP
	mov		[tss+TSS_ESP0], eax		;push here -> current proc
	mov		ax, word [esi+LDT_SEL]
	lldt	ax						;lldt
;set IF
	sti
;go to proc_user
	push	0xF
	push	0x1000
	push	0x7
	push	0
	retf
clock_handler	equ	ADDR
_clock_handler:
	pushad		;esp no use
	push	ds
	push	es
	push	fs
	push	gs
	mov		ax, ss
	mov		ds, ax
	inc		dword [ticks]
	inc		word [0xB8000+80*25*2-2]
	mov		al, 0x20
	out		0x20, al
	mov		eax, [current]
	mov		esi, [proc_table+eax]
.loop:
	cmp		esi, LAST_PROC
	je		.last
	add		eax, 4
	mov		esi, [proc_table+eax]
	jmp		.check
.last:
	xor		eax, eax
	mov		esi, [proc_table]
.check:
	cmp		dword [esi+FLAG], 0
	je		.ok
	jmp		.loop
.ok:
	mov		[current], eax
	mov		esp, esi				;pop here
	mov		eax, esi
	add		eax, STACKTOP			;next time push here
	mov		dword [tss+TSS_ESP0], eax
	mov		ax, word [esi+LDT_SEL]	;lldt
	lldt	ax
	pop		gs
	pop		fs
	pop		es
	pop		ds
	popad
	iretd
;eax=0(send)1(recv),ebx=pid,ecx=topid
sys_sendrecv	equ	ADDR
_sys_sendrecv:
	pushad
	push	ds
	push	es
	push	fs
	push	gs
	cmp		eax, 0
	je		.send
	jmp		.recv
.send:
	mov		ax, ss
	mov		ds, ax
	mov		esi, dword [proc_table+ebx]	;point to process
	mov		edi, dword [proc_table+ecx]
	mov		eax, [edi+FLAG]
	cmp		eax, 2
	jne		.busy
	mov		[edi+EAX], edx			;copy msg to ret value
	mov		dword [edi+FLAG], 0		;set free
	jmp		.ok
.busy:
	cmp		dword [edi+QUEUE], 0	;if queue empty
	je		.front
	mov		edi, [edi+QUEUE]
.next:
	cmp		dword [edi+NEXT], 0		;if next empty
	je		.tail
	mov		edi, [edi+NEXT]
	jmp		.next
.tail:
	mov		[edi+NEXT], esi
.front:
	mov		[edi+QUEUE], esi
.block:
	mov		[esi+MSG], edx			;save msg
	mov		dword [esi+FLAG], 1		;set sending
	mov		dword [esi+NEXT], 0		;last in queue
	jmp		.schedule
.recv:
	mov		ax, ss
	mov		ds, ax
	mov		edi, dword [proc_table+ebx]		;point to process
	cmp		dword [edi+QUEUE], 0	;if queue empty
	je		.block2
	mov		esi, [edi+QUEUE]		;copy msg, flag, queue
	mov		eax, [esi+MSG]
	mov		[esp+EAX], eax			;ret msg
	mov		dword [esi+FLAG], 0
	mov		eax, [esi+NEXT]			;pop front
	mov		[edi+QUEUE], eax
	mov		dword [esi+NEXT], 0
	jmp		.ok
.block2:
	mov		dword [edi+FLAG], 2
.schedule:
	mov		eax, [current]
	mov		esi, [proc_table+eax]
.sloop:
	cmp		esi, LAST_PROC
	je		.slast
	add		eax, 4
	mov		esi, [proc_table+eax]
	jmp		.scheck
.slast:
	xor		eax, eax
	mov		esi, [proc_table]
.scheck:
	cmp		dword [esi+FLAG], 0
	je		.sok
	jmp		.sloop
.sok:
	mov		[current], eax
	mov		esp, esi				;pop here
	mov		eax, esi
	add		eax, STACKTOP			;next time push here
	mov		dword [tss+TSS_ESP0], eax
	mov		ax, word [esi+LDT_SEL]	;lldt
	lldt	ax
.ok:
	pop		gs
	pop		fs
	pop		es
	pop		ds
	popad
	iretd
;====================process space=================
;---------------------ticks-------------------------
ticks			equ	0xF000
code_ticks		equ	ADDR
_code_ticks:
	mov		ax, ss
	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		gs, ax
	mov		dword [ds:0], 0
.loop:
	mov		eax, 1	;recv
	mov		ebx, 0
	int		33
	mov		eax, 0
	mov		ebx, 0
	mov		ecx, 8
	mov		edx, [ds:0]
	int		33
	jmp		.loop
LEN_CODE_TICKS	equ	(ADDR-code_ticks)
;---------------------print------------------------
code_print		equ	ADDR
_code_print:
	mov		ax, ss
	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		gs, ax
	mov		ax, (0x700+' ')
	mov		ecx, 80*25
	xor		edi, edi
.clear:
	mov		[edi], ax
	add		edi, 2
	loop	.clear
	xor		edi, edi
.loop:
	cmp		edi, 80*25*2
	ja		.over
	jmp		.read
.over:
	mov		ax, (0x700+' ')
	mov		ecx, 80*25
	xor		edi, edi
	jmp		.clear
.read:
	mov		eax, 1	;recv
	mov		ebx, 4
	int		33
	mov		ah, 0x7
	mov		word [edi], ax
	add		edi, 2
	jmp		.loop
LEN_CODE_PRINT	equ	(ADDR-code_print)
;----------------------user------------------------
code_user		equ ADDR
_code_user:
	mov		ax, ss
	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		gs, ax
.loop:
	call	_get_ticks
	mov		dword [ds:0], eax
	push	eax
	call	_print_u16
	add		esp, 4
.wait:
	call	_get_ticks
	mov		ebx, dword [ds:0]
	add		ebx, 100
	cmp		eax, ebx
	ja		.loop
	jmp		.wait
_get_ticks:
	mov		eax, 0
	mov		ebx, 8
	mov		ecx, 0
	mov		edx, 0
	int		33
	mov		eax, 1
	mov		ebx, 8
	int		33
	ret
_print_char:
	push	ebx
	push	ecx
	push	edx
	mov		eax, 0
	mov		ebx, 8
	mov		ecx, 4
	mov		edx, [esp+16]
	int		33
	pop		edx
	pop		ecx
	pop		ebx
	ret
_print_u8:
	push	ebx
	push	ecx
	mov		bl, byte [esp+12]
	mov		al, bl
	shr		al, 4
	mov		ecx, 2
.loop:
	and		al, 0xF
	cmp		al, 9
	ja		.alpha
	add		al, '0'
	jmp		.next
.alpha:
	sub		al, 10
	add		al, 'A'
.next:
	push	eax
	call	_print_char
	add		esp, 4
	mov		al, bl
	loop	.loop
	pop		ecx
	pop		ebx
	ret
_print_u16:
	mov		ax, word [esp+4]
	shr		eax, 8
	push	eax
	call	_print_u8
	add		esp, 4
	mov		ax, word [esp+4]
	push	eax
	call	_print_u8
	add		esp, 4
	ret
_print_u32:
	mov		eax, dword [esp+4]
	shr		eax, 16
	push	eax
	call	_print_u16
	add		esp, 4
	mov		eax, dword [esp+4]
	push	eax
	call	_print_u16
	add		esp, 4
	ret
LEN_CODE_USER	equ	(ADDR-code_user)
times 512*320-($-$$) db 0
