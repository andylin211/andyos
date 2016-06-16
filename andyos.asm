org		0x10000		;especially for kernel, not boot
%include "boot.asm"
;===============global constants and variables==============================
%include "macro.asm"
%include "global.asm"
;===============processes here==============================================
bits	32
%include "ticks.asm"
%include "print.asm"
%include "keybd.asm"
%include "user.asm"
;===============kernel here=================================================
stacktop_kernel		equ	0x10000
kernel:
	mov		ax, 16
	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		gs, ax
	mov		ss, ax
	mov		esp, stacktop_kernel
	mov		ax, 24
	ltr		ax							;	init tss
	lidt	[idt_ptr]					;	init idt
	call	.initclock					;	init_clock()
	call	.init8259a					;	init_8259a()
	jmp		restart
.initclock:
	mov		al, 0x34
	out		0x43, al					;	out_byte(0x43, 0x34)
	mov		ax, 11931	;1193182
	out		0x40, al					;	out_byte(0x40, (11931&0xFF))
	shr		ax, 8
	out		0x40, al					;	out_byte(0x40, (11931>>8)&0xFF)
	ret
.init8259a:
	mov		al, 0x11					;ICW1			
	out		0x20, al					;	out_byte(0x20, 0x11)
	nop
	nop
	mov		al, 0x20					;ICW2(start IRQ no)
	out		0x21, al					;	out_byte(0x21, 0x20)
	nop
	nop
	mov		al, 0100b					;ICW3(no.3 -> slave)
	out		0x21, al					;	out_byte(0x21, 0100b)
	nop
	nop
	mov		al, 0x1						;ICW4(80x86,normal EOI)
	out		0x21, al					;	out_byte(0x21, 0x1)
	nop
	nop
	mov		al, 0xFC					;OCW1(enable clock keybd)
	out		0x21, al					;	out_byte(0x21, 0xFC)
	nop
	nop
	ret
;1. save to PCB
;2. use kernel stack
;3. update ds
save:
	pushad         					;	save 8+4 regs to PCB of current process
	push    ds   					; 
	push    es  					; 
	push    fs 						; 
	push    gs 						;
	mov		esi, esp				;	!esi
	mov     esp, stacktop_kernel	;	1. use kernel stack
	push    restart    				;	2. push 'ret'
	mov		ax, ss					;	
	mov		ds, ax					;	3. update ds
	mov		eax, [esi+RETADR]		;	!eax
	mov		[esp-4], eax			;
	mov		eax, [esi+EAX]			;	~eax
	mov		esi, [esi+ESI]			;	~esi
	jmp     [esp-4]					;	goto instruction next to save()
;1. update ldt and tss for current process
;2. recover current process from PCB
restart:
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
;1. update global 'current'
schedule:
	push	eax
	push	esi
	mov		eax, [current]			;	u32	offset = current;
	mov		esi, [proc_table+eax]	;	u32 proc = proc_table[offset];
.loop:								;	do {
	cmp		esi, LAST_PROC			;		if (proc != LAST_PROC){		//u32 proc = esi
	je		.last					;	
	add		eax, 4					;			offset += 4;			//u32 offset = eax
	mov		esi, [proc_table+eax]	;			proc = proc_table[offset];
	jmp		.check					;		}
.last:								;		else {
	xor		eax, eax				;			offset = 0;
	mov		esi, [proc_table]		;			proc = proc_table;
.check:								;		}
	cmp		dword [esi+FLAG], 0		;	} while (proc[FLAG] != 0)
	jne		.loop					;
	mov		[current], eax			;	current = offset;
	pop		esi
	pop		eax
	ret
;-----------------clock_handler() and keyboard_handler() and sys_sendrecv()--------
clock_handler:
pshinning			equ	0xB8000+80*25*2-2
	call	save					;	save();					//save to PCB, turn to kernel stack
	mov		al, 0x20				;	out_byte(EOI);
	out		0x20, al				;
	inc		dword [pticks]			;	ticks++;
	inc		word [pshinning]		;	shinning++;
	call	schedule				;	schedule();				//update 'current'
	ret								;	return;
;
keyboard_handler:
	call	save					;	save();
	mov		al, 0x20				;	
	out		0x20, al				;	out_byte(EOI);
	inc		word [pshinning-2]		;	shinning++;
	in		al, 0x60				;	u8 scan_code = in_byte(0x60);
	cmp		dword [pcount], buflen	;	if (count < buflen) {
	jae		.full					;
	mov		ebx, [pphead]			;
	mov		[ebx], al				;		*phead = scan_code;
	inc		dword [pphead]			;		phead++;
	cmp		dword [pphead], (pbuf+buflen);	if (phead == pbuf + BUFLEN) {
	jne		.notend
	mov		dword [pphead], pbuf		;			phead = pbuf;
.notend:							;		}
	inc		dword [pcount]			;		count++;
.full:								;	}
	ret								;	return;
;eax=SYS_FLAG(SYS_SEND or SYS_RECV)
;ebx=MY_PID(0,4,8...)
;ecx=THE_PID(0,4,8...or PID_ANY or PID_INT) (PID_ANY PID_INT only for SYS_RECV)
;ebx=pmsg(address of msgbody)
sys_sendrecv:
	call	save						;	save();
	cmp		eax, SYS_SEND				;	if (SYS_FLAG == SYS_SEND) {
	jne		.recv						;
.send:									;
	push	edx							;		pmsg = pmsg;
	push	dword [proc_table+ecx]		;		dst_proc = proc_table[THE_PID];
	push	dword [proc_table+ebx]		;		my_proc = proc_table[MY_PID];
	call	msg_send					;		msg_send(my_proc, dst_proc, pmsg)
	add		esp, 12						;		return;
	ret									;	}
.recv:									;	else {
	push	edx							;		pmsg = pmsg;
	cmp		ecx, PID_ANY				;		if (THE_PID != PID_ANY) {
	je		.any						;			
	cmp		ecx, PID_INT				;			if (THE_PID != PID_INT) {
	je		.int						;	
	push	dword [proc_table+ecx]		;				src_proc = proc_table[THE_PID];
	jmp		.next						;			}
.int:									;			else {
	push	dword PROC_INT				;				src_proc = PROC_INT;
	jmp		.next						;			}
.any:									;		} else {
	push	dword PROC_ANY				;			src_proc = PROC_ANY;
.next:									;		}
	push	dword [proc_table+ebx]		;		my_proc = proc_table[MY_PID];
	call	msg_recv					;		msg_recv(my_proc, src_proc, pmsg);
	add		esp, 12						;		return;
	ret									;	}

;msg_send(proc_sender, proc_dest, pmsg)
msg_send:
	push	ebp
	mov		ebp, esp
	push	esi
	push	edi
	push	eax
	push	ebx
	push	ecx
	push	edx
	mov		esi, dword [ebp+8]			;	my_proc
	mov		edi, dword [ebp+12]			;	dst_proc
	mov		edx, dword [ebp+16]			;	pmsg
										;	
	cmp		dword [edi+FLAG], FLAG_RECV	;	if ( precv[FLAG] == FLAG_RECV) {	//is waiting for somebody
	jne		.notwaitingforme			;
	cmp		dword [edi+RECVFROM], esi	;		if (( dst_proc[RECVFROM] == my_proc) ||
	je		.waitingforme				;
	cmp		dword [edi+RECVFROM], PROC_ANY;		( dst_proc[RECVFROM] == PROC_ANY) {
	je		.waitingforme				;			
	jmp		.notwaitingforme			;		
.waitingforme:							;	
	push	dword SIZE_MSG				;			
	push	dword [edi+PMSG]			;			tomsg = dst_proc[PMSG];
	push	dword edx					;			msg = edx;
	call	memcpy						;			memcpy(msg, tomsg, sizeof(MSG));
	add		esp, 12						;
	mov		dword [edi+FLAG], 0			;			dst_proc[FLAG] = 0;
	jmp		.return						;			return;
										;		}
.notwaitingforme:						;	} else {
	mov		dword [esi+SENDTO], edi		;		my_proc[SENDTO] = dst_proc;
	mov		dword [esi+FLAG], FLAG_SEND	;		my_proc[FLAG] = FLAG_SEND;
	mov		[esi+PMSG], edx				;		my_proc[PMSG] = pmsg;
	cmp		dword [edi+QUEUE], 0		;		if ( dst_proc[QUEUE] != 0) {	
	je		.queueempty					;
	mov		eax, [edi+QUEUE]			;			temp = precv[QUEUE];
.next:									;
	cmp		dword [eax+NEXT], 0			;			while ( temp[NEXT] != 0) {
	je		.nextempty					;
	mov		eax, [eax+NEXT]				;				temp = temp[NEXT];
	jmp		.next						;			}
.nextempty:								;
	mov		[eax+NEXT], esi				;			temp[NEXT] = psend;
	jmp		.block						;		}
.queueempty:							;		else {
	mov		[edi+QUEUE], esi			;			dst_proc[QUEUE] = my_proc;
.block:									;		}
	call	schedule					;		schedule();
.return:								;	}
	pop		edx
	pop		ecx
	pop		ebx
	pop		eax
	pop		edi
	pop		esi
	pop		ebp
	ret

;msg_recv(proc_recv, proc_from, pmsg)
msg_recv:
	push	ebp
	mov		ebp, esp
	push	esi
	push	edi
	push	eax
	push	ebx
	push	ecx
	push	edx
	mov		edi, [ebp+8]					;	my_proc
	mov		esi, [ebp+12]					;	src_proc
	mov		edx, [ebp+16]					;	pmsg
	xor		eax, eax						;	temp
	xor		ebx, ebx						;	prev
	xor		ecx, ecx						;	copy
											;
	cmp		dword [edi+HASINTMSG], 1		;	if (my_proc[HASINTMSG] == 1) {
	jne		.normalmsg						;	
	cmp		esi, PROC_ANY					;		if ((src_proc == PROC_ANY) ||
	je		.handleintmsg					;		
	cmp		esi, PROC_INT					;				(src_proc==PROC_INT))
	je		.handleintmsg					;		{
.handleintmsg:								;
	sub		esp, SIZE_MSG					;			MESSAGE msg;
	mov		eax, esp						;
	mov		dword [eax+SOURCE], SRC_INT		;			msg[source] = SRC_INT;
	mov		dword [eax+TYPE], TYPE_INT		;			msg[type] = type_INT;
	push	dword SIZE_MSG					;	
	push	dword [edi+PMSG]				;			tomsg = my_proc[PMSG];
	push	eax								;	
	call	memcpy							;			memcpy(msg, tomsg, 24);
	add		esp, (SIZE_MSG+12)				;
	mov		dword [edi+HASINTMSG], 0		;			my_proc[HASINTMSG] = 0;
	jmp		.return							;			return;
											;		}
.normalmsg:									;	}
	cmp		esi, PROC_ANY					;	if (src_proc == PROC_ANY) {
	jne		.certainproc					;		
	cmp		dword [edi+QUEUE], 0			;		if (precv[QUEUE] != 0) {
	je		.copyornot						;
	mov		eax, [edi+QUEUE]				;			temp = my_proc[QUEUE];
	mov		ecx, 1							;			copy = 1;
	jmp		.copyornot						;		}
.certainproc:								;	} else {
	cmp		dword [esi+FLAG], FLAG_SEND		;		if (src_proc[FLAG] == FLAG_SEND) {
	jne		.copyornot						;
	cmp		dword [esi+SENDTO], edi			;			if (src_proc[SENDTO] == my_proc) {
	jne		.copyornot						;				
	mov		ecx, 1							;				copy = 1;
	mov		eax, [edi+QUEUE]				;				temp = my_proc[QUEUE];
.loop:										;
	cmp		eax, esi						;				while (temp != src_proc) {
	je		.break							;					
	mov		ebx, eax						;					prev = temp;
	mov		eax, [eax+NEXT]					;					temp = temp[NEXT];
	jmp		.loop							;				}
.break:										;			}
	jmp		.copyornot						;		}
.copyornot:									;	}	
	cmp		ecx, 1							;	if (copy == 1) {
	jne		.nocopy							;
	cmp		eax, [edi+QUEUE]				;		if (temp == my_proc[QUEUE]) {
	jne		.handlequeue					;
	mov		ecx, [eax+NEXT]					;			
	mov		[edi+QUEUE], ecx				;			my_proc[QUEUE] = temp[NEXT];
	mov		dword [eax+NEXT], 0				;			temp[NEXT] = 0;
	jmp		.docopy							;		}
.handlequeue:								;		else {
	mov		ecx, [eax+NEXT]					;
	mov		[ebx+NEXT], ecx					;			prev[NEXT] = temp[NEXT];
	mov		dword [eax+NEXT], 0				;			temp[NEXT] = 0;
.docopy:									;		}
	push	dword SIZE_MSG					;
	push	edx								;		tomsg = pmsg;(edx)
	push	dword [eax+PMSG]				;		msg = temp[PMSG];
	call	memcpy							;		memcpy(msg, tomsg, sizeof(MSG));
	add		esp, 12							;
	mov		dword [eax+FLAG], 0				;		temp[FLAG] = 0;
	jmp		.return							;	
.nocopy:									;	} else {
	mov		dword [edi+FLAG], FLAG_RECV		;		my_proc[FLAG] = FLAG_RECV;
	mov		[edi+RECVFROM], esi				;		my_proc[RECVFROM] = src_proc;
	call	schedule						;		schedule();
.return:									;	}
	pop		edx
	pop		ecx
	pop		ebx
	pop		eax
	pop		edi
	pop		esi
	pop		ebp
	ret

;memcpy(src, dst, bytes)
memcpy:
	push	ebp
	mov		ebp, esp
	push	esi
	push	edi
	push	eax
	push	ecx
	mov		esi, [ebp+8]
	mov		edi, [ebp+12]
	mov		ecx, [ebp+16]
.loop:
	lodsb
	stosb
	loop	.loop
	pop		ecx
	pop		eax
	pop		edi
	pop		esi
	pop		ebp
	ret

times 512*320-($-$$) db 0
