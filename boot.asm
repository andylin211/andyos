bits	16
boot:
	mov ax, 1000h
	mov es, ax
	mov bx,	0		;es:bx
	mov ch, 0		;trk
	mov cl, 1		;sctr
	mov dh, 0		;head
	mov dl, 0		;floppya
.loop:
	mov	ah, 2
	mov al, 8		;count
	int 13h
	cmp ax, 8
	jne	.error		;if read-error; then error
	inc	ch			;trk++
	cmp	ch, 16 		
	je	.next64k	;if ch=16; then next64k
	cmp ch, 32		
	je	.next64k	;if ch=32; then next64k
	cmp ch, 40	
	je	.finish		;if ch=40; then finish
	add	bx, 1000h	;bx+=512*8
	jmp	.loop
.next64k:
	mov ax, es
	add ax, 1000h
	mov es, ax
	xor bx, bx
	jmp .loop
.error:
	jmp $
.finish:
	mov		ax, 0x1000
	mov		ds, ax
	lgdt	[ds:(gdt_ptr-$$)]		;	init gdt
	in		al, 0x92					;
	or		al, 2						;
	out		0x92, al					;	open a20
	mov		eax, cr0					;
	or		eax, 1						;
	mov		cr0, eax					;	set pe bit
	jmp		dword 8:kernel				;	goto kernel
times 510-($-$$) db 0
	dw 		0xAA55


