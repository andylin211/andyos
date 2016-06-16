;keybd(data-stack-code: here)
;============================
;0x00 p_head
;0x04 p_tail
;0x08 p_count
;0x0C~0x10B buf[0x100|256]
pphead:	;pointer
	dd			pbuf
pptail:	;pointer
	dd			pbuf
pcount:	;4B
	dd			0	
pbuf:	;100B
	buflen	equ	100
	times	buflen db 0
pleft_ctrl:
	dd			0
pleft_shift:
	dd			0
pmap:	;0x80 B
	LC	equ	0x1D
	LS	equ	0x2A
	db	1,1,"1234567890-=",0x8,0xA	;01=ESC.0E=\b.0F=\t
	db	"qwertyuiop[]",0xA,1,"as"	;1A=\n,1D=LC,
	db	"dfghjkl;'`",1,'\',"zxcv"	;2A=LS
	db	"bnm,.",'/',1,1,1,' ',1,1,1,1,1,1

	db	1,1,"!@#$%^&*()_+",1,1		;
	db	"QWERTYUIOP{}",1,1,"AS"		;
	db	"DFGHJKL:",'"','~',1,'|',"ZXCV"
	db	"BNM<>",'?',1,1,1,1,1,1,1,1,1,1

	times	1024 db 0
stacktop_keybd:
code_keybd:
	mov		ax, 0xF
	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		gs, ax
.loop:								;do {
	cmp		dword [pcount], 0		;	if (count == 0) {
	je		.loop					;		continue;
									;	}
	cli								;	cli();		//disable clock&keybd intr
	mov		eax, [pptail]			;
	mov		al, [eax]				;	u8 scan_code = *ptail;
	and		eax, 0xFF
	inc		dword [pptail]			;	ptail++;
	cmp		dword [pptail], (pbuf+buflen);
	jne		.notend					;	if (ptail == pbuf+buflen) {
	mov		dword [pptail], pbuf	;		ptail = pbuf;
.notend:							;	}
	dec		dword [pcount]			;	count--;
	sti								;	sti();		/reenable clock&keybd intr
									;
;	push	eax
;	call	_kb_print_u8
;	add		esp, 4
	cmp		al, 0x7F				;	if (scan_code <= 0x7F) {
	ja		.break					;		//make code
	cmp		al, LC					;		if (scan_code == LC) {
	jne		.notLC					;
	mov		dword [pleft_ctrl], 1	;			left_ctrl = 1;
	jmp		.next					;		}
.notLC:								;
	cmp		al, LS					;		else if (scan_code == LS) {
	jne		.notLS					;
	mov		dword [pleft_shift], 1	;			left_shift = 1;
	jmp		.next					;		} else {
.notLS:								;
	cmp		dword [pleft_shift], 0	;				if (left_shift == 1) {
	je		.noshift				;
	mov		al, [pmap+eax+0x40]		;					ch = map[scan_code+0x40];
	jmp		.print					;				} 
.noshift:							;				else {
	mov		al, [pmap+eax]			;					ch = map[scan_code];
.print:								;				}
	push	eax						;				kb_print_char(ch);
	call	_print_char			;			}
	add		esp, 4					;		}
	jmp		.next					;
.break:								;		else {	//break code
	and		eax, 0x7F				;			scan_code &= 0x7F;
	cmp		al, LC					;			if (scan_code == LC) {
	jne		.notLCb					;
	mov		dword [pleft_ctrl], 0	;				left_ctrl = 0;
	jmp		.next					;			
.notLCb:							;			}
	cmp		al, LS					;			else if (scan_code == LS) {
	jne		.next					;
	mov		dword [pleft_shift], 0	;				left_shift= 0;
									;			}	
.next:								;		}
									;	}
	jmp		.loop					;} while (1)

