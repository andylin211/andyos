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
%define	TSS_ESP0	4
%define STACKTOP	4*18
%define	ESI			20	;4sreg+edi	= 5
%define	EAX			44	;4sreg+2e?i+2e?p+3eb|d|cx = 11
%define	RETADR		48	;pop 4sreg+popad = 12
%define	LDT_SEL		72	;pop 4sreg+popad 1retadr 5important regs = 18
%define	LDTS		76	;after ldt_sel
%define	PID			100	;ldt_sel then skip (4+3*8=28) is 100
%define	FLAG		104	;after pid
%define	PMSG		108	;after flag
%define	QUEUE		112	;after msg
%define	NEXT		116	;after queue
%define	RECVFROM	120	;after next
%define	SENDTO		124	;after recvfrom
%define	HASINTMSG	128	;after sendto
%define	SYSCALL		0x80
%define	SOURCE		0x0
%define	TYPE		0x4
%define	INT1		0x8
%define	INT2		0xC
%define	INT3		0x10
%define	INT4		0x14
%define	SIZE_MSG	24
%define	FLAG_SEND	1
%define	FLAG_RECV	2
%define	PROC_ANY	0
%define	PROC_INT	0
%define	SYS_SEND	0
%define	SYS_RECV	1
%define	SRC_INT		0
%define	TYPE_INT	0
%define	PID_ANY		0xFFFFFFFF
%define	PID_INT		0xFFFFFFFE
