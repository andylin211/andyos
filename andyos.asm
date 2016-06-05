org	0x10000
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
	mov		ax, 0x1000
	mov		ds, ax
	lgdt	[ds:gdt_ptr-0x10000]		;	init gdt
	in		al, 0x92					;
	or		al, 2						;
	out		0x92, al					;	open a20
	mov		eax, cr0					;
	or		eax, 1						;
	mov		cr0, eax					;	set pe bit
	jmp		dword 8:0x10200				;	goto kernel
ERROR:
	jmp $
times 510-($-$$) db 0
dw 0xaa55
;===========================global code==================================
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
%define ADDR		($-$$+0x10000)
%define	TSS_ESP0	4
%define STACKTOP	4*18
%define	ESI			20	;4sreg+edi	= 5
%define	EAX			44	;4sreg+2e?i+2e?p+3eb|d|cx = 11
%define	RETADR		48	;pop 4sreg+popad = 12
%define	LDT_SEL		72	;pop 4sreg+popad 1retadr 5important regs = 18
%define	PID			92	;ldt then skip (4+2*8=20) is 92
%define	FLAG		96	;after pid
%define	MSG			100	;after flag
%define	QUEUE		104	;after msg
%define	NEXT		108	;after queue
%define	SYSCALL		0x80
;============================================================================
BITS 32
_kernel:
	mov		ax, 16
	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		gs, ax
	mov		ss, ax
	mov		esp, 0x10000
	mov		ax, 24
	ltr		ax							;	init tss
	lidt	[idt_ptr]					;	init idt
	call	_init_clock					;	init_clock()
	call	_init_cursor				;	init_cursor()
	call	_init_8259a					;	init_8259a()
	call	_init_keyboard
	jmp		_restart
_init_clock:
	mov		al, 0x34
	out		0x43, al
	mov		ax, 11931	;1193182
	out		0x40, al
	shr		ax, 8
	out		0x40, al
	ret
_init_cursor:
	mov		al, 0xE	;high
	mov		dx, 0x3D4
	out		dx, al
	mov		ax, 80*25
	shr		ax, 8
	mov		dx, 0x3D5
	out		dx, al
	mov		al, 0xF	;low
	mov		dx, 0x3D4
	out		dx, al
	mov		ax, 80*25
	mov		dx, 0x3D5
	out		dx, al
	ret
_init_8259a:
	mov		al, 0x11	;ICW1
	out		0x20, al
	nop
	nop
	out		0xA0, al
	nop
	nop
	mov		al, 0x20	;ICW2
	out		0x21, al
	nop
	nop
	mov		al, 0x28
	out		0xA1, al
	nop
	nop
	mov		al, 0100b	;ICW3
	out		0x21, al
	nop
	nop
	mov		al, 0x2
	out		0xA1, al
	nop
	nop
	mov		al, 0x1		;ICW4
	out		0x21, al
	nop
	nop
	out		0xA1, al
	nop
	nop
	mov		al, 0xFC	;OCW1
	out		0x21, al
	nop
	nop
	mov		al, 0xFF
	out		0xA1, al
	nop
	nop
	ret
_init_keyboard:
	mov		dword [p_head], buf
	mov		dword [p_tail], buf
	mov		dword [p_count], 0
	ret
;-----------------------save() restart() schedule()------------------------------
;save to PCB
;use kernel stack
;update ds
_save:
	pushad         					;	save 8+4 regs to PCB of current process
	push    ds   					; 
	push    es  					; 
	push    fs 						; 
	push    gs 						;
	mov		esi, esp				;	!esi
	mov     esp, 0x10000			;	1. use kernel stack
	push    _restart    			;	2. push 'ret'
	mov		ax, ss					;	
	mov		ds, ax					;	3. update ds
	mov		eax, [esi+RETADR]		;	!eax
	mov		[esp-4], eax			;
	mov		eax, [esi+EAX]			;	~eax
	mov		esi, [esi+ESI]			;	~esi
	jmp     [esp-4]					;	goto instruction next to save()
;update ldt and tss for current process
;recover current process from PCB
restart		equ	ADDR
_restart:
	mov		eax, [current]			;	
	mov		esp, [proc_table+eax]	;	u32 proc = *(proc_table+ *current );
	lldt	[esp+LDT_SEL] 			;	lldt( *(proc+LDT_SEL) );
	lea		eax, [esp+STACKTOP]		;	
	mov	dword [tss+TSS_ESP0], eax	;	*(tss+TSS_ESP0) = proc+STACKTOP;
	pop	gs							;	recover 4+8 regs from PCB of current process
	pop	fs
	pop	es
	pop	ds
	popad
	add		esp, 4					;	skip retval
	iretd							;	goto process routine
;update global 'current'
_schedule:
	mov		eax, [current]
	mov		esi, [proc_table+eax]	;	u32 proc = *(proc_table+*current);
.loop:								;	do {
	cmp		esi, LAST_PROC			;		if (proc != LAST_PROC){		//u32 proc = esi
	je		.last					;	
	add		eax, 4					;			offset += 4;			//u32 offset = eax
	mov		esi, [proc_table+eax]	;			proc = *(proc_table+offset);
	jmp		.check					;		}
.last:								;		else {
	xor		eax, eax				;			offset = 0;
	mov		esi, [proc_table]		;			porc = *proc_table;
.check:								;		}
	cmp		dword [esi+FLAG], 0		;	} while (*(proc+FLAG) != 0)
	jne		.loop					;
	mov		[current], eax			;	*current = offset;
	ret
;-----------------clock_handler() and keyboard_handler() and sys_sendrecv()--------
clock_handler	equ	ADDR
shinning			equ	0xB8000+80*25*2-2
_clock_handler:
	call	_save					;	save();					//save to PCB, turn to kernel stack
	mov		al, 0x20				;	out_byte(EOI);
	out		0x20, al				;
	inc		dword [ticks]			;	*ticks++;
	inc		word [shinning]			;	*shinning++;
	call	_schedule				;	schedule();				//update 'current'
	ret								;	return;
;
keyboard_handler	equ	ADDR
_keyboard_handler:
	call	_save					;	save();
	mov		al, 0x20				;	out_byte(EOI);
	out		0x20, al				;
	in		al, 0x60				;	u8 scan_code = in_byte(0x60);
	inc		word [shinning-2]		;	*shinning++;
	cmp		dword [p_count], BUFLEN	;	if (*p_count < BUFLEN) {
	jae		.full					;
	mov		ebx, [p_head]			;
	mov		[ebx], al				;		*(*p_head) = scan_code;
	inc		dword [p_head]			;		*p_head++;
	cmp		dword [p_head], (buf+BUFLEN);	if (*p_head == buf + BUFLEN) {
	jne		.notend
	mov		dword [p_head], buf		;			*p_head = buf;
.notend:							;		}
	inc		dword [p_count]			;		*p_count++;
.full:								;	}
	ret								;	return;
;
sys_sendrecv	equ	ADDR
_sys_sendrecv:	;eax(0send,1recv),ebx(me),ecx(the other),edx(msg)
	call	_save						;	save();		//save to PCB, use kernel stack
	cmp		eax, 0						;	if (eax == 0) {
	jne		.recv						;	//if send
.send:									;
	mov		esi, dword [proc_table+ebx]	;		u32 from = esi = *(proc_table+ebx);
	mov		edi, dword [proc_table+ecx]	;		u32 to   = edi = *(proc_table+ecx);
	mov		eax, [edi+FLAG]				;		if ( *(to+FLAG) == 2) {	//is waiting for sender
	cmp		eax, 2						;
	jne		.sendwait					;
	mov		[edi+EAX], edx				;			*(to+EAX) = edx;	//copy msg to ret value
	mov		dword [edi+FLAG], 0			;			*(to+FLAG) = 0;		//set free
	jmp		.ok							;		}
.sendwait:								;		else {
	cmp		dword [edi+QUEUE], 0		;			if ( *(to+QUEUE) != 0) {	
	je	.front						;
	mov		edi, [edi+QUEUE]			;				u32 temp = edi = *(to+QUEUE);
.next:									;
	cmp		dword [edi+NEXT], 0			;				while ( *(temp+NEXT) != 0) {
	je		.tail						;
	mov		edi, [edi+NEXT]				;					temp = *(temp+NEXT);
	jmp		.next						;				}
.tail:									;
	mov		[edi+NEXT], esi				;				*(temp+NEXT) = from;
	jmp		.block						;			}
.front:									;			else {
	mov		[edi+QUEUE], esi			;				*(to+QUEUE) = from;
.block:									;			}
	mov		[esi+MSG], edx				;			*(from+MSG) = edx;
	mov		dword [esi+FLAG], 1			;			*(from+FLAG) = 1;
	mov		dword [esi+NEXT], 0			;			*(from+NEXT) = 0;
	call	_schedule					;			schedule();
	jmp		.ok							;		}
.recv:									;	} else {		//recv
	mov		edi, dword [proc_table+ebx]	;		u32 to = edi = *(proc_table+ebx);
	cmp		dword [edi+QUEUE], 0		;		if ( *(edi+QUEUE) != 0) {
	je		.block2						;
	mov		esi, [edi+QUEUE]			;			u32 from = *(to+QUEUE);				//esi
	mov		ebx, [esi+MSG]				;			
	mov		[edi+EAX], ebx				;			*(to+EAX) = *(from+MSG);
	mov		dword [esi+FLAG], 0			;			*(from+FLAG) = 0;
	mov		eax, [esi+NEXT]				;		
	mov		[edi+QUEUE], eax			;			*(to+QUEUE) = *(from+NEXT);	
	mov		dword [esi+NEXT], 0			;			*(from+NEXT) = 0;
	jmp		.ok							;		}
.block2:								;		else {
	mov		dword [edi+FLAG], 2			;			*(to+FLAG) = 2;
	call	_schedule					;			schedule();
										;		}
.ok:									;	}
	ret									;	return;
;====================process space==========================================================
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
	int		SYSCALL
	mov		eax, 0
	mov		ebx, 0
	mov		ecx, 12
	mov		edx, [ds:0]
	int		SYSCALL
	jmp		.loop
LEN_CODE_TICKS	equ	($-_code_ticks)
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
	call	_update_cursor
	cmp		edi, 80*25*2
	jae		.over
	jmp		.read
.over:
	;mov		ax, (0x700+' ')
	;mov		ecx, 80*25
	xor		edi, edi
	;jmp		.clear

.read:
	mov		eax, 1	;recv
	mov		ebx, 4
	int		SYSCALL
	cmp		al, 0xA	;newline
	je		.newline
	cmp		al, 0x8	;backspace
	je		.backspace
	mov		ah, 0x7
	mov		word [edi], ax
	add		edi, 2
	jmp		.loop
.newline:
	mov		eax, edi
	mov		bl, 160
	div		bl
	inc		al
	mul		bl
	mov		edi, eax
	jmp		.loop
.backspace:
	mov		eax, edi
	mov		bl, 160
	div		bl
	mul		bl
	mov		edi, eax
	jmp		.loop
_update_cursor:
	mov		al, 0xE	;high
	mov		dx, 0x3D4
	out		dx, al
	mov		eax, edi
	shr		ax, 9
	mov		dx, 0x3D5
	out		dx, al
	mov		al, 0xF	;low
	mov		dx, 0x3D4
	out		dx, al
	mov		eax, edi
	shr		eax, 1
	mov		dx, 0x3D5
	out		dx, al
	ret
LEN_CODE_PRINT	equ	($-_code_print)
;----------------------keybd-----------------------
;stack 0xE000~0xEFFF
;0xE000 p_head
;0xE004 p_tail
;0xE008 p_count
;0xE00C~0xE10B buf[0x100|256]
p_head		equ	0xE000
_p_head	equ	0
p_tail		equ	0xE004
_p_tail	equ	0x4
p_count	equ	0xE008
_p_count	equ	0x8
buf		equ	0xE00C
_buf		equ	0xC
BUFLEN	equ	0x100
code_keybd	equ	ADDR
_code_keybd:
	mov		ax, ss
	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		gs, ax
.loop:								;do {
	cmp		dword [_p_count], 0		;	if (*p_count > 0) {
	je		.empty					;
	cli								;		cli
	mov		eax, [_p_tail]			;
	sub		eax, 0xE000
	mov		al, [eax]				;		u8 scan_code = *(*p_tail);
	inc		dword [_p_tail]			;		*p_tail++;
	cmp		dword [_p_tail], (_buf+BUFLEN);
	jne		.notend					;		if (*p_tail == buf+BUFLEN) {
	mov		dword [_p_tail], _buf	;			*p_tail = buf;
.notend:							;		}
	dec		dword [_p_count]		;		*p_count--;
	sti								;		sti
	push	eax
	call	_kb_print_u8
	add		esp, 4
	push	dword ' '
	call	_kb_print_char
	add		esp, 4					;	}
.empty:								;}
	jmp		.loop					;while (1)
_kb_print_char:
	push	ebx
	push	ecx
	push	edx
	mov		eax, 0
	mov		ebx, 8
	mov		ecx, 4
	mov		edx, [esp+16]
	int		SYSCALL
	pop		edx
	pop		ecx
	pop		ebx
	ret
_kb_print_u8:
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
	call	_kb_print_char
	add		esp, 4
	mov		al, bl
	loop	.loop
	pop		ecx
	pop		ebx
	ret

LEN_CODE_KEYBD	equ	ADDR-code_keybd
;----------------------user------------------------
%macro	PRINT_STR	2
	push	dword %2
	push	dword %1
	call	_print_string
	add		esp, 8
%endmacro
%macro	PRINT_U32	1
	push	dword '0'
	call	_print_char
	add		esp, 4
	push	dword 'x'
	call	_print_char
	add		esp, 4
	push	dword %1
	call	_print_u32
	add		esp, 4
%endmacro
%macro	PRINTF_STR_U32	4
	push	dword %2
	push	dword %1
	call	_print_string
	add		esp, 8
	push	dword '0'
	call	_print_char
	add		esp, 4
	push	dword 'x'
	call	_print_char
	add		esp, 4
	push	dword %3
	call	_print_u32
	add		esp, 4
	push	%4
	call	_print_char
	add		esp, 4
%endmacro
%define		OFFSET	($-_data_user)
data_user	equ	ADDR
_data_user:
	dd		0	;last_tick
str_gdt:		equ	OFFSET
	db		"gdt:      "
len_gdt			equ	OFFSET-str_gdt
str_gdt_ptr:	equ	OFFSET
	db		"gdt_ptr:  "
len_gdt_ptr		equ	OFFSET-str_gdt_ptr
str_idt:		equ	OFFSET
	db		"idt:      "
len_idt		equ	OFFSET-str_idt
str_idt_ptr:	equ	OFFSET
	db		"idt_ptr:  "
len_idt_ptr		equ	OFFSET-str_idt_ptr
str_tss:		equ	OFFSET
	db		"tss:      "
len_tss		equ	OFFSET-str_tss
str_current:	equ	OFFSET
	db		"current:  "
len_current		equ	OFFSET-str_current
str_proc_table:	equ	OFFSET
	db		"proc_tabl:"
len_proc_table	equ	OFFSET-str_proc_table
str_proc_ticks:	equ	OFFSET
	db		"proc_tick:"
len_proc_ticks	equ	OFFSET-str_proc_ticks
str_proc_print:	equ	OFFSET
	db		"proc_prin:"
len_proc_print	equ	OFFSET-str_proc_print
str_proc_keybd:	equ	OFFSET
	db		"proc_keyb:"
len_proc_keybd	equ	OFFSET-str_proc_keybd
str_proc_user:	equ	OFFSET
	db		"proc_user:"
len_proc_user	equ	OFFSET-str_proc_user
str_debug_start:	equ	OFFSET
	db		"dbg_start:"
len_debug_start	equ	OFFSET-str_debug_start
str_clock_handler:	equ	OFFSET
	db		"clk_handl:"
len_clock_handler	equ	OFFSET-str_clock_handler
str_keyboard_handler:	equ	OFFSET
	db		"key_handl:"
len_keyboard_handler	equ	OFFSET-str_keyboard_handler
str_sys_sendrecv:	equ	OFFSET
	db		"sendrecv: "
len_sys_sendrecv	equ	OFFSET-str_sys_sendrecv
str_code_ticks:	equ	OFFSET
	db		"code_tick:"
len_code_ticks	equ	OFFSET-str_code_ticks
str_code_print:	equ	OFFSET
	db		"code_prnt:"
len_code_print	equ	OFFSET-str_code_print
str_code_keybd:	equ	OFFSET
	db		"code_keyb:"
len_code_keybd	equ	OFFSET-str_code_keybd
str_code_user:	equ	OFFSET
	db		"code_user:"
len_code_user	equ	OFFSET-str_code_user
str_ticks:	equ	OFFSET
	db		"ticks:    "
len_ticks	equ	OFFSET-str_ticks
	times	1024	db 0
LEN_DATA_USER	equ	(ADDR-data_user)
code_user		equ ADDR
_code_user:
	mov		ax, ss
	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		gs, ax
	call	_print_info	
.loop:
	call	_get_ticks
	mov		dword [ds:0], eax
	mov		edi, eax
;	PRINTF_STR_U32	str_ticks, len_ticks, edi, 0x8
.wait:
	call	_get_ticks
	mov		ebx, dword [ds:0]
	add		ebx, 100
	cmp		eax, ebx
	jae		.loop
	jmp		.wait
_print_info:
	PRINTF_STR_U32	str_gdt, len_gdt, gdt, 0xA
	PRINTF_STR_U32	str_gdt_ptr, len_gdt_ptr, gdt_ptr, 0xA
	PRINTF_STR_U32	str_idt, len_idt, idt, 0xA
	PRINTF_STR_U32	str_idt_ptr, len_idt_ptr, idt_ptr, 0xA
	PRINTF_STR_U32	str_tss, len_tss, tss, 0xA
	PRINTF_STR_U32	str_current, len_current, current, 0xA
	PRINTF_STR_U32	str_proc_table, len_proc_table, proc_table, 0xA
	PRINTF_STR_U32	str_proc_ticks, len_proc_ticks, proc_ticks, 0xA
	PRINTF_STR_U32	str_proc_print, len_proc_print, proc_print, 0xA
	PRINTF_STR_U32	str_proc_keybd, len_proc_keybd, proc_keybd, 0xA
	PRINTF_STR_U32	str_proc_user,  len_proc_user,  proc_user, 0xA
	PRINTF_STR_U32	str_clock_handler,  len_clock_handler,  clock_handler, 0xA
	PRINTF_STR_U32	str_keyboard_handler,  len_keyboard_handler,  keyboard_handler, 0xA
	PRINTF_STR_U32	str_sys_sendrecv,  len_sys_sendrecv,  sys_sendrecv, 0xA
	PRINTF_STR_U32	str_code_ticks,  len_code_ticks, code_ticks , 0xA
	PRINTF_STR_U32	str_code_print,  len_code_print, code_print, 0xA
	PRINTF_STR_U32	str_code_keybd,  len_code_keybd, code_keybd, 0xA
	PRINTF_STR_U32	str_code_user,  len_code_user, code_user, 0xA
	ret
_get_ticks:
	mov		eax, 0
	mov		ebx, 12
	mov		ecx, 0
	mov		edx, 0
	int		SYSCALL
	mov		eax, 1
	mov		ebx, 12
	int		SYSCALL
	ret
_print_char:
	push	ebx
	push	ecx
	push	edx
	mov		eax, 0
	mov		ebx, 12
	mov		ecx, 4
	mov		edx, [esp+16]
	int		SYSCALL
	pop		edx
	pop		ecx
	pop		ebx
	ret
_print_string:		;(base,len)
	push	ebp
	mov		ebp, esp
	push	ecx
	push	esi
	mov		ecx, [ebp+12]
	mov		esi, [ebp+8]
.loop:
	mov		al, byte [esi]
	inc		esi
	push	eax
	call	_print_char
	add		esp, 4
	loop	.loop
	pop		esi
	pop		ecx
	pop		ebp
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
;========================================================================

;==================global variables================
;--------------------gdt,idt,tss---------------------
gdt		equ	ADDR
	DESCRIPTOR	0, 0, 0	;(H->L:||G|DB|0|AVL|+|0000|+|P|DPL2|S|+|TYPE4||)
	DESCRIPTOR	0, 0xFFFFF, ((1100b<<12)+(1001b<<4)+0xA);0xA exec/read
	DESCRIPTOR	0, 0xFFFFF, ((1100b<<12)+(1001b<<4)+0x2);0x2 read/write
	DESCRIPTOR	tss, 104, 	((1000b<<4)+0x9)	;0x9 avail 386 tss
	DESCRIPTOR	ldt_ticks, 16,	((1000b<<4)+0x2)	;0x2 ldt
	DESCRIPTOR	ldt_print, 16,	((1000b<<4)+0x2)	;0x2 ldt
	DESCRIPTOR	ldt_keybd, 16, 	((1000b<<4)+0x2)
	DESCRIPTOR	ldt_user, 16, 	((1000b<<4)+0x2)
	%rep	128-8
		DESCRIPTOR 0,0,0
	%endrep
gdt_ptr equ	ADDR
	dw		(8*128-1)
	dd		gdt
idt			equ ADDR
	%rep	32	
		GATE 0, 0, 0
	%endrep
	GATE		8, clock_handler, 	(10001110b<<8)
	GATE		8, keyboard_handler, (10001110b<<8)
	%rep	(128-34)
		GATE 0, 0, 0
	%endrep		;int	0x80 for sys_call
	GATE		8, sys_sendrecv, 	(11101110b<<8)	;0x80
	%rep	(128-1)
		GATE 0, 0, 0
	%endrep
idt_ptr		equ ADDR
	dw		(8*256-1)
	dd		idt
tss			equ	ADDR
	dd		0		;backlink
	dd		0		;esp0
	dd		16		;ss0
	times	22 dd 0	;4esp/ss+17regs+1(ldt)
	dw		0	;debug trap
	dw		104	;I/O base
	db		0xFF;end of I/O
;---------------process----------------------------
current		equ ADDR
	dd		12
proc_table	equ ADDR
	dd		proc_ticks
	dd		proc_print
	dd		proc_keybd
	dd		proc_user
LAST_PROC	equ	proc_user
;----------------proc_ticks-------------------------
proc_ticks	equ ADDR
	times	13 dd 0	;defg-s and 8 common regs + retaddr
	dd		0		;eip
	dd		0x7		;cs
	dd		0x3202	;eflags
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
	times	13 dd 0	;defg-s and 8 common regs
	dd		0		;eip
	dd		0x7		;cs
	dd		0x3202	;eflags
	dd		0x1000	;esp
	dd		0xF		;ss
	dd		40		;ldt_selector
ldt_print		equ	ADDR
	DESCRIPTOR	code_print, LEN_CODE_PRINT-1, ((0100<<12)+(1111b<<4)+0xA)	;D/B.P.DPL.S.
	DESCRIPTOR	0xB8000, (0x1000-1), ((0100<<12)+(1111b<<4)+0x2)
	dd		4		;pid
	dd		0		;flag
	dd		0		;msgbody
	dd		0		;queue
	dd		0		;next
;----------------proc_keybd-------------------------
proc_keybd	equ ADDR
	times	13 dd 0	;defg-s and 8 common regs
	dd		0		;eip
	dd		0x7		;cs
	dd		0x3202	;eflags
	dd		0x1000;esp
	dd		0xF		;ss
	dd		48		;ldt_selector
ldt_keybd	equ	ADDR
	DESCRIPTOR	code_keybd, LEN_CODE_KEYBD-1, ((0100<<12)+(1111b<<4)+0xA)	;D/B.P.DPL.S.
	DESCRIPTOR	0xE000, (0x1000-1), ((0100<<12)+(1111b<<4)+0x2)
	dd		8		;pid
	dd		0		;flag
	dd		0		;msgbody
	dd		0		;queue
	dd		0		;next

;----------------proc_user-------------------------
proc_user	equ ADDR
	times	13 dd 0	;defg-s and 8 common regs
	dd		0		;eip
	dd		0x7		;cs
	dd		0x3202	;eflags
	dd		LEN_DATA_USER;esp
	dd		0xF		;ss
	dd		56		;ldt_selector
ldt_user		equ	ADDR
	DESCRIPTOR	code_user, LEN_CODE_USER-1, ((0100<<12)+(1111b<<4)+0xA)	;D/B.P.DPL.S.
	DESCRIPTOR	data_user, LEN_DATA_USER-1, ((0100<<12)+(1111b<<4)+0x2)
	dd		12		;pid
	dd		0		;flag
	dd		0		;msgbody
	dd		0		;queue
	dd		0		;next
;======================================================================
times 512*320-($-$$) db 0
