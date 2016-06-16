;print(data(0xB8000)-stack-code: here)
;=====================================
pscreen_start		equ		0xB8000
pscreen_end			equ		pscreen_start+80*25*2
	times	1024	db 0
stacktop_print:
code_print:
	mov		ax, 0xF
	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		gs, ax
	mov		ebp, esp
	sub		esp, SIZE_MSG
	mov		ax, (0x700+' ')
	mov		ecx, 80*25
	mov		edi, pscreen_start
.clear:
	mov		[edi], ax
	add		edi, 2
	loop	.clear
	mov		edi, pscreen_start
.loop:
	call	.updatecursor
	cmp		edi, pscreen_end
	jae		.over
	jmp		.read
.over:
	;mov		ax, (0x700+' ')
	;mov		ecx, 80*25
	mov		edi, pscreen_start
	;jmp		.clear

.read:
	mov		eax, SYS_RECV	;recv
	mov		ebx, 4
	mov		ecx, PID_ANY
	mov		edx, ebp
	sub		edx, SIZE_MSG
	int		SYSCALL
	mov		eax, [edx+INT1]
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
	sub		eax, pscreen_start
	mov		bl, 160
	div		bl
	inc		al
	mul		bl
	add		eax, pscreen_start
	mov		edi, eax
	jmp		.loop
.backspace:
	mov		eax, edi
	sub		eax, pscreen_start
	mov		bl, 160
	div		bl
	mul		bl
	add		eax, pscreen_start
	mov		edi, eax
	jmp		.loop
.updatecursor:
	mov		al, 0xE	;high
	mov		dx, 0x3D4
	out		dx, al
	mov		eax, edi
	sub		eax, pscreen_start
	shr		ax, 9
	mov		dx, 0x3D5
	out		dx, al
	mov		al, 0xF	;low
	mov		dx, 0x3D4
	out		dx, al
	mov		eax, edi
	sub		eax, pscreen_start
	shr		eax, 1
	mov		dx, 0x3D5
	out		dx, al
	ret

