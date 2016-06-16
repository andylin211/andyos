;user(data+stack+code:here)
;==========================
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
last_ticks:
	dd		0
str_gdt:
	db		"gdt:      "
	len_gdt			equ	$-str_gdt
str_gdt_ptr:
	db		"gdt_ptr:  "
	len_gdt_ptr		equ	$-str_gdt_ptr
str_idt:
	db		"idt:      "
	len_idt		equ	$-str_idt
str_idt_ptr:
	db		"idt_ptr:  "
	len_idt_ptr		equ	$-str_idt_ptr
str_tss:
	db		"tss:      "
	len_tss		equ	$-str_tss
str_current:
	db		"current:  "
	len_current		equ	$-str_current
str_proc_table:
	db		"proc_tabl:"
	len_proc_table	equ	$-str_proc_table
str_proc_ticks:	
	db		"proc_tick:"
	len_proc_ticks	equ	$-str_proc_ticks
str_proc_print:
	db		"proc_prin:"
	len_proc_print	equ	$-str_proc_print
str_proc_keybd:
	db		"proc_keyb:"
	len_proc_keybd	equ	$-str_proc_keybd
str_proc_user:
	db		"proc_user:"
	len_proc_user	equ	$-str_proc_user
str_debug_start:
	db		"dbg_start:"
	len_debug_start	equ	$-str_debug_start
str_clock_handler:
	db		"clk_handl:"
	len_clock_handler	equ	$-str_clock_handler
str_keyboard_handler:
	db		"key_handl:"
	len_keyboard_handler	equ	$-str_keyboard_handler
str_sys_sendrecv:	
	db		"sendrecv: "
	len_sys_sendrecv	equ	$-str_sys_sendrecv
str_code_ticks:	
	db		"code_tick:"
	len_code_ticks	equ	$-str_code_ticks
str_code_print:
	db		"code_prnt:"
	len_code_print	equ	$-str_code_print
str_code_keybd:
	db		"code_keyb:"
	len_code_keybd	equ	$-str_code_keybd
str_code_user:
	db		"code_user:"
	len_code_user	equ	$-str_code_user
str_ticks:
	db		"ticks:    "
	len_ticks	equ	$-str_ticks
	times	1024	db 0
stacktop_user:
code_user:
	mov		ax, 0xF
	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		gs, ax
	push	dword 'a'
	call	_print_char
	add		esp, 4
	push	dword 'b'
	call	_print_char
	add		esp, 4
	push	dword 'c'
	call	_print_char
	add		esp, 4
	push	dword 'd'
	call	_print_char
	add		esp, 4
	push	dword 'e'
	call	_print_char
	add		esp, 4
	push	dword 'f'
	call	_print_char
	add		esp, 4
	;call	_print_info	
	jmp		$
.loop:
	call	_get_ticks
	mov		dword [last_ticks], eax
	mov		edi, eax
	;PRINTF_STR_U32	str_ticks, len_ticks, edi, 0x8
.wait:
	call	_get_ticks
	mov		ebx, dword [last_ticks]
	add		ebx, 100
	cmp		eax, ebx
	jae		.loop
	jmp		.wait
_print_info:
;	PRINTF_STR_U32	str_gdt, len_gdt, gdt, 0xA
;	PRINTF_STR_U32	str_gdt_ptr, len_gdt_ptr, gdt_ptr, 0xA
;	PRINTF_STR_U32	str_idt, len_idt, idt, 0xA
;	PRINTF_STR_U32	str_idt_ptr, len_idt_ptr, idt_ptr, 0xA
;	PRINTF_STR_U32	str_tss, len_tss, tss, 0xA
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
	push	ebp
	mov		ebp, esp
	sub		esp, SIZE_MSG	;msg
	push	eax
	push	ebx
	push	ecx
	push	edx
	mov		eax, [ebp+8]
	mov		dword [ebp-SIZE_MSG+SOURCE], 0xC
	mov		dword [ebp-SIZE_MSG+INT1], eax
	mov		eax, 0
	mov		ebx, 12
	mov		ecx, 4
	mov		edx, ebp
	sub		edx, 24
	int		SYSCALL
	pop		edx
	pop		ecx
	pop		ebx
	pop		eax
	add		esp, SIZE_MSG
	pop		ebp
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

