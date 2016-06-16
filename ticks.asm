pticks:	dd		0
	times	(1024-4)	db 0
stacktop_ticks:

code_ticks:
	jmp		$
	mov		ax, 0xF
	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		gs, ax
	mov		dword [pticks], 0			;	*pticks = 0;
.loop:									;	do	{
	mov		eax, 1	;recv				;
	mov		ebx, 0						;	
	int		SYSCALL						;		sys_sendrecv(RECV, 0, 0, 0)
	mov		eax, 0						;
	mov		ebx, 0						;
	mov		ecx, 12						;	
	cli
	mov		edx, [pticks]				;
	sti
	int		SYSCALL						;		sys_sendrecv(SEND, 0, 12, *pticks)
	jmp		.loop						;	} while (1)


