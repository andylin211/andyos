section loader align=16 vstart=0x8000
directory_address 		equ 0x7e00
kernel_address			equ 0x9000
loader_address			equ 0x8000
ring0_code_selector 	equ 8
ring0_data_selector	 	equ 16	
kernel_image_image_base_addr	equ		0x6000
kernel_image_code_base_addr		equ 	0x6004
kernel_image_data_base_addr 	equ		0x6008
kernel_image_code_offset_addr 	equ		0x600c
kernel_image_code_size_addr	 	equ		0x6010
kernel_image_data_offset_addr 	equ		0x6014
kernel_image_data_size_addr	 	equ		0x6018

%macro 					break 0 		
	xor 	eax, eax
	jmp 	$-2
%endmacro

loader_entry:
	; cs now equals to 0 ;
	mov 	ax, cs
	mov 	ds, ax
	mov 	es, ax
	mov 	fs, ax
	mov 	ss, ax
	mov 	ax, 0xb800
	mov 	gs, ax

	mov 	sp, 08000h
	mov 	bp, sp
	
	; clear() ;
	call 	clear_screen16

	call	read_memory_info

	; print("loading kernel...") ;
	push 	str_loading_kernel
	call 	print_string16
	add 	sp, 2

	; load() ;
	call 	load_kernel

	jmp 	enter_protect_mode


read_memory_info:
;
; int 15h
; ax = 0xe820
; bx = offset (initially 0)
; cx = 20 (size to read, maybe ignored)
; edx = 0x534d4150 ("SMAP")
; es:di -> to memory
; -->
; cf = 0 for ok
; eax = 0x534d4150
; ecx = 0x20 (actual read)
; ebx = next offset !!! important
;
mem_desc_count	equ 0x7efc

	push	ebx
	push	ecx
	push	edx
	push	edi

	mov		dword [mem_desc_count], 0
	xor     ebx, ebx
	mov     edi, 0x7f00
.loop:
	mov     eax, 0x0e820
	mov     ecx, 20
	mov     edx, 0x534d4150
	int		15h
	jc      .fail
	add     di, 20
	inc     dword [mem_desc_count]
	cmp     ebx, 0
	jne     .loop
	jmp     .ok
.fail:
	mov     dword [mem_desc_count], 0
.ok:
	
	pop		edi
	pop		edx
	pop		ecx
	pop		ebx
	ret

enter_protect_mode:
	cli
	lgdt	[gdt_ptr]					;	init gdt
	in		al, 0x92					;
	or		al, 2						;
	out		0x92, al					;	open a20
	mov		eax, cr0					;
	or		eax, 1						;
	mov		cr0, eax					;	set pe bit
	jmp		dword ring0_code_selector:(loader32_entry-loader_entry+loader_address)

; descriptor(base, limit, attr) ;
%macro descriptor	3
	dw	%2 & 0xFFFF
	dw	%1 & 0xFFFF
	db	(%1 >> 16) & 0xFF
	dw	((%2 >> 8) & 0xF00) + (%3 & 0xF0FF)
	db	(%1 >> 24) & 0xFF
%endmacro

; (H->L:||G|DB|0|AVL|+|0000|+|P|DPL2|S|+|TYPE4||) ;
ring0_code32 		equ ((1100b<<12)+(1001b<<4)+0xA) ; 0xA exec/read
ring0_data32 		equ ((1100b<<12)+(1001b<<4)+0x2) ; 0x2 read/write

; gdt ;
gdt:
	descriptor	0, 0, 0
	descriptor	0, 0xFFFFF, ring0_code32
	descriptor	0, 0xFFFFF, ring0_data32
gdt_end:

gdt_len 				equ (gdt_end - gdt)
gdt_limit				equ (gdt_len - 1)
gdt_ptr:
	dw		gdt_limit
	dd		gdt

load_kernel:
	push 	bp
	mov 	bp, sp
	push 	bx
	push 	cx
	push 	dx

	; kernel offset and size ;
	mov 	dx, [ds:directory_address+0x18]
	mov 	cx, [ds:directory_address+0x1c]

	; print("sector: 0x%x", sector_index) ;
	push 	str_from_sector
	call 	print_string16
	add 	sp, 2

	push 	dx
	call 	print_digit16
	add 	sp, 2

	call 	new_line16

	; print("count: 0x%x", size) ;
	push 	str_sector_count
	call 	print_string16
	add 	sp, 2

	push 	cx
	call 	print_digit16
	add 	sp, 2	

	call 	new_line16

	mov 	bx, kernel_address
.next_sector:
	; hd_read_one_sector() ;
	push 	0x0000 	; high
	push 	bx 		; low
	push 	dx 		; sector index
	call 	hd_read_one_sector
	add 	sp, 6	

	; update address and read ;
	add 	bx, 512
	inc 	dx

	; print('.') ;
	push 	'.'
	call 	print_char16
	add 	sp, 2

	; next or break ;
	loop 	.next_sector

	call 	new_line16

	pop 	dx
	pop 	cx
	pop 	bx
	pop 	bp
	ret

strlen16:
;
; word strlen16(string_address)
; @return length of string in byte
;
	push 	bp
	mov 	bp, sp
	push 	bx
	push 	cx
	push 	dx

	mov 	si, [bp+4]
	mov 	cx, [bp+4]
.next_byte:
	lodsb
	test 	al, al
	jnz 	.next_byte
.reach_zero:
	mov 	ax, si
	sub 	ax, cx
	dec 	ax

	pop 	dx
	pop 	cx
	pop 	bx
	pop 	bp
	ret

four_bits_to_char16:
;
; byte four_bits_to_char16(byte_4bits)
; @return char
;
	push 	bp
	mov 	bp, sp

	xor 	ax, ax
	mov 	al, [bp+4]
	and 	al, 0x0F
	cmp 	al, 0x0A
	jae 	.char
.digit:
	add 	al, '0'
	jmp 	.byte_ready
.char:
	add 	al, 'A'
	sub 	al, 0x0A
.byte_ready:

	pop 	bp
	ret

digit_to_string16:
;
; void digit_to_string16(digit, string_address)
;
	push 	bp
	mov 	bp, sp
	push 	cx
	push 	es

	mov 	ax, ds
	mov 	es, ax
	mov 	di, [bp+6]

	mov 	cx, 16
.next_4bits:
	mov 	ax, [bp+4]
	sub 	cx, 4
	shr 	ax, cl
	push 	ax
	call 	four_bits_to_char16
	add 	sp, 2
	stosb
	test 	cx, cx
	jnz 	.next_4bits

	xor 	al, al
	stosb
	
	pop 	es
	pop 	cx
	pop 	bp
	ret	

update_cursor16:
;
; void update_cursor(void)
; 光标
; 	0x3d4 -- 索引寄存器的端口号, 写入一个值来指定某个寄存器
;		0x0e -- 光标位置高8位
; 		0x0f -- 光标位置低8位
; 	0x3d5 -- 读写端口
;
	push 	dx
	mov 	dx,	0x3d4
	mov 	al, 0x0e
	out 	dx, al
	mov 	dx, 0x3d5
	mov 	al, [cursor_high]
	out 	dx, al

	mov 	dx,	0x3d4
	mov 	al, 0x0f
	out 	dx, al
	mov 	dx, 0x3d5
	mov 	al, [cursor_low]
	out 	dx, al
	pop 	dx
	ret 

print_char16:
;
; void print_char16(ascii)
; 		
	push 	bp
	mov 	bp, sp
	push 	di
	push 	bx

	mov 	bl, [cursor_low]
	mov 	bh, [cursor_high]
	mov 	al, [bp+4]
	cmp 	al, 0x0d	; /r
	je 		.carriage_return
	cmp 	al, 0x0a
	je 		.line_feed
	mov 	di, bx
	shl 	di, 1
	mov 	ah, 0x07
	mov 	[gs:di], ax
	inc 	bx
	jmp 	.exit0 
.carriage_return:
	mov 	ax, bx
	mov 	bl, 80
	div 	bl
	mul 	bl
	mov 	bx, ax
	jmp 	.exit0
.line_feed:
	add 	bx, 80
.exit0:
	mov 	[cursor_low], bx
	call 	update_cursor16
	

	pop 	bx
	pop 	di
	pop 	bp
	ret 

print_string16:
;
; void print_string16(string_address)
; @note 
; 	string ends with 0
;
	push 	bp
	mov 	bp, sp
	push 	cx

	; strlen16() ;
	mov 	ax, [bp+4]
	push 	ax
	call 	strlen16
	add 	sp, 2

	mov 	si, [bp+4]
	mov 	cx, ax
.next_char:
	lodsb
	push 	ax
	call 	print_char16
	add 	sp, 2
	loop 	.next_char

	pop 	cx
	pop 	bp
	ret

print_digit16:
;
; void print_digit16(digit)
; 
	push 	bp
	mov 	bp, sp
	sub 	sp, 6

	push 	sp
	mov		ax,	[bp+4]
	push 	ax
	call 	digit_to_string16
	add 	sp, 4

	mov		ax,	bp
	sub 	ax, 6
	push 	ax
	call 	print_string16
	add 	sp, 2

	add 	sp, 6
	pop 	bp
	ret

new_line16:
	push 	0x0d
	call 	print_char16
	add 	sp, 2
	push 	0x0a
	call 	print_char16
	add 	sp, 2
	ret

clear_screen16:
	mov 	ah, 0x00
    mov 	al, 0x03
    int 	10h
    ret

hd_read_one_sector:
;
; word hd_read_one_sector(sector_index, address_low, address_high)
; @return 0 if succeed, 1 if fail
;
; 参考
;
; 软盘
; 	al=扇区数, ah=中断子功能号 (2=读扇区,3=写扇区)
;   {cl的6,7位,ch}=磁道号, {cl的低6位}=扇区号
;   dh=磁头号, dl=驱动器号(0=软盘,80h=硬盘)
;   es:bx=数据缓冲区的地址
;
; 硬盘	
; 	LBA28逻辑扇区编码方式
; 	主硬盘控制器端口号: 0x1f0, 0x1f1, ..., 0x1f7
; 		0x1f2 -- 需要读取的扇区数量（变）, 8位端口, 最大255, 0表示读256个扇区
;			eg:	 
;				mov dx, 0x1f2 \ mov	al, 0x01 \ out	dx, al
;		0x1f3,0x1f4,0x1f5,0x1f6 -- 28位太长, 需要4个端口, {0,7}{8,15}{16,23}{24,27}, 
;			  					-- 0x1f6端口特殊({5,7}<-0111b表示LBA模式, {4}<-0或1表示主盘或者从盘) 
;			eg:
;				mov	dx, 0x1f3 \ mov al, 0x02 \ out dx, al
;				inc	dx \ xor al, al \ out dx, al
;				inc	dx \ out dx, al
;				inc	dx \ mov al, 0xe0 \ out dx, al
;		0x1f7 -- 命令端口, 读/写, 0x20/?
;			  -- 也是状态端口, {7}=1表示busy, {4}=1表示data ready
;			eg:
;				mov dx, 0x1f7 \ mov al, 0x20 \ out dx, al		
;			eg:
;				mov dx, 0x1f7
;			 	.wait:
;				int al, dx \ and al, 0x88 \ cmp al, 0x08
;				jnz .wait
;		0x1f1 -- 错误端口
;		0x1f0 -- 数据端口, 16位端口, 
;			eg:
;				mov cx, 256 \ mov dx, 1f0
;				.readw:
;				in ax, dx \ mov [bx], ax \ add bx, 2 
;				loop .readw
;				
	push 	bp
	mov 	bp, sp
	push 	bx
	push 	cx
	push 	dx
	push 	es

	; read 1 sector ;
	mov 	dx, 0x1f2
	mov 	al, 0x01
	out 	dx, al 

	; read 2nd secotr ; 
	mov 	dx, 0x1f3
	mov 	byte al, [bp+4]
	out 	dx, al
	inc 	dx
	xor 	al, al
	out 	dx, al
	inc 	dx
	out 	dx, al
	inc 	dx
	mov 	al, 0xe0
	out 	dx, al

	; do read ;
	mov 	dx, 0x1f7
	mov 	al, 0x20
	out 	dx, al

	; wait ;
.wait_for_data:
	in 		al, dx
	and 	al, 0x89
	cmp 	al, 0x08
	je 		.data_is_ready
	and 	al, 0x01
	test 	al, al
	jnz		.error_occur
	jmp 	.wait_for_data
.data_is_ready:

	; copy ;
	mov 	cx, 256
	mov 	bx, [bp+8]
	mov 	es, bx
	mov 	bx, [bp+6]
	mov 	dx, 0x1f0
.read_next_word:
	in 		ax, dx
	mov 	word [es:bx], ax
	add 	bx, 2
	loop 	.read_next_word

	; return ;
	xor 	ax, ax
	jmp 	.exit0
.error_occur:
	mov 	ax, 0x01
.exit0:

	pop 	es
	pop 	dx
	pop 	cx
	pop 	bx
	pop 	bp
	ret 

; 32-bit code placed here ;
bits 32
align 32
%macro 		pushregs 0
	push 	ebp
	mov 	ebp, esp
	push 	ebx
	push 	ecx
	push 	edx
	push 	edi
	push 	esi	
%endmacro

%macro 		popregs 0
	pop 	esi
	pop 	edi
	pop 	edx
	pop 	ecx
	pop 	ebx
	pop 	ebp
%endmacro

memcpy:
;
; void memcpy(src_address, dest_address, size_in_byte)
;
	pushregs

	mov 	eax, [ebp+8]
	mov 	esi, eax
	mov 	eax, [ebp+12]
	mov 	edi, eax
	mov 	ecx, [ebp+16]
.next_byte:
	lodsb
	stosb
	loop 	.next_byte

	popregs
	ret 

strlen:
;
; long strlen(string_address)
; @return length of string in byte
; string end with 0
;
	pushregs

	mov 	esi, [ebp+8]
	xor 	ecx, ecx
.next_byte:
	inc 	ecx
	lodsb
	test 	al, al
	jnz 	.next_byte
.reach_zero:
	dec 	ecx
	mov 	eax, ecx

	popregs
	ret

strcmp:
;
; long strcmp(src_address, dst_address)
; @return 0 if same
;
	pushregs

	mov 	edi, [ebp+12]
	mov 	esi, [ebp+8]
.next_byte:
	lodsb
	cmp		al, [edi]
	jnz 	.not_same
	inc 	edi
	test 	al, al
	jz 		.same
	jmp 	.next_byte

.same:
	xor 	eax, eax
	jmp 	.exit0
.not_same:
	mov 	eax, 1
.exit0:
	popregs
	ret

four_bits_to_char:
;
; byte four_bits_to_char(byte /* ignore high 4 bits */)
; @return char
;
	pushregs

	mov 	byte al, [ebp+8]
	and 	al, 0x0F
	cmp 	al, 0x0A
	jae 	.char
.digit:
	add 	al, '0'
	jmp 	.byte_ready
.char:
	add 	al, 'A'
	sub 	al, 0x0A
.byte_ready:

	popregs
	ret

digit_to_string:
;
; void digit_to_string(digit, string_address)
;
	pushregs

	mov 	edi, [ebp+12]

	mov 	ecx, 32
.next_4bits:
	mov 	eax, [ebp+8]
	sub 	ecx, 4
	shr 	eax, cl
	push 	eax
	call 	four_bits_to_char
	add 	esp, 4
	stosb
	test 	ecx, ecx
	jnz 	.next_4bits

	xor 	al, al
	stosb
	
	popregs
	ret	

update_cursor:
;
; void update_cursor(void)
; 光标
; 	0x3d4 -- 索引寄存器的端口号, 写入一个值来指定某个寄存器
;		0x0e -- 光标位置高8位
; 		0x0f -- 光标位置低8位
; 	0x3d5 -- 读写端口
;
	pushregs

	push 	dx
	mov 	dx,	0x3d4
	mov 	al, 0x0e
	out 	dx, al
	mov 	dx, 0x3d5
	mov 	al, [cursor_high_phy]
	out 	dx, al

	mov 	dx,	0x3d4
	mov 	al, 0x0f
	out 	dx, al
	mov 	dx, 0x3d5
	mov 	al, [cursor_low_phy]
	out 	dx, al
	pop 	dx

	popregs
	ret

print_char:
;
; void print_char16(ascii)
; 		
	pushregs

	mov 	bl, [cursor_low_phy]
	mov 	bh, [cursor_high_phy]
	mov 	byte al, [ebp+8]
	cmp 	al, 0x0d	; /r
	je 		.carriage_return
	cmp 	al, 0x0a
	je 		.line_feed

	; display char on screen;
	movzx 	edi, bx
	shl 	edi, 1
	mov 	ah, 0x07	
	add 	edi, 0xb8000
	mov 	[edi], ax

	inc 	bx
	jmp 	.exit0 
.carriage_return:
	mov 	ax, bx
	mov 	bl, 80
	div 	bl
	mul 	bl
	mov 	bx, ax
	jmp 	.exit0
.line_feed:
	add 	bx, 80
.exit0:
	mov 	[cursor_low_phy], bx
	call 	update_cursor
	
	popregs
	ret 

print_string:
;
; void print_string16(string_address)
; @note 
; 	string ends with 0
;
	pushregs

	mov 	esi, [ebp+8]
.next_char:
	lodsb
	test 	al, al
	jz 		.exit0

	push 	eax
	call 	print_char
	add 	esp, 4

	jmp 	.next_char

.exit0:
	popregs
	ret

print_digit:
;
; void print_digit(digit)
; 
	pushregs

	sub 	esp, 12

	push 	esp
	mov		eax, [ebp+8]
	push 	eax
	call 	digit_to_string
	add 	esp, 8

	push	esp
	call 	print_string
	add 	esp, 4

	add 	sp, 12
	
	popregs
	ret

printf:
;
; void printf(char* format, ...)
; @note:
; 	%x -- hex digit
;
; @pseudo code:
; 
;	char buf[256];
; 	char* pbuf = buf;
;	short* pargs = (short*)format;
; 	pargs++;
; 	char* p = format;
;   while (*p != 0) {
;		if (*p == '%' && *(p+1) == 'x') {
;			p+=2; // skip %x
;			digit_to_string(*parg, pbuf);
;			pbuf+= 8;
;			parg++;
;		} else {
;			*pbuf = *p;
;			pbuf++;
;			p++;
;		}
;	}
;
	pushregs

	sub 	esp, 256
	mov 	edi, esp 	; edi -> pbuf
	mov 	ecx, ebp
	add 	ecx, 12 	; ecx -> pargs
	mov 	esi, [ebp+8]; esi -> p

	
.while_loop:
	lodsb
	test 	al, al
	jz 		.exit0

	; if (*p == '%' && *(p+1) == 'x')
	cmp 	al, '%'
	jnz 	.else_block
	mov 	byte al, [esi]
	cmp 	al, 'x'
	jnz 	.else_block
.if_block:
	inc 	esi 	; skip 0x
	push 	esi
	mov 	esi, ecx

	push 	edi
	push 	dword [esi]
	call 	digit_to_string
	add 	esp, 8

	add 	ecx, 4
	pop 	esi
	add 	edi, 8
	jmp 	.while_loop	
.else_block:
	stosb
	jmp 	.while_loop

.exit0:
	xor 	al, al
	stosb

	push 	esp
	call 	print_string
	add 	esp, 4

	add 	esp, 256
	popregs
	ret


loader32_entry:
;
; !!!!!!!!!!!!!!!!
;
	mov 	ax, ring0_data_selector
	mov 	ds, ax
	mov 	es, ax
	mov 	fs, ax
	mov 	gs, ax
	; stack base;
	mov 	ss, ax
	mov 	esp, 0x10000

	call 	map_kernel

	; cursor value !! 放在日志起点好了 ;
	mov 	bx, [cursor_low]
	mov		edi, 0x10000
	mov		[edi], bx

	; image info ;
	mov 	eax, [kernel_image_image_base]
	mov 	[kernel_image_image_base_addr], eax
	
	mov 	eax, [kernel_image_code_base]
	mov 	[kernel_image_code_base_addr], eax

	mov 	eax, [kernel_image_data_base]
	mov 	[kernel_image_data_base_addr], eax

	mov 	eax, [kernel_image_code_offset]
	mov 	[kernel_image_code_offset_addr], eax

	mov 	eax, [kernel_image_code_size]
	mov 	[kernel_image_code_size_addr], eax

	mov 	eax, [kernel_image_data_offset]
	mov 	[kernel_image_data_offset_addr], eax

	mov 	eax, [kernel_image_data_size]
	mov 	[kernel_image_data_size_addr], eax

	mov 	eax, [kernel_image_entry]
	add 	eax, [kernel_image_image_base]
	jmp 	eax

map_kernel:
;
; 从0x3c处读一个dword[签名位置=0xc0]，跳过签名和文件头，来到可选头[位置=0xc0+4+0x14=0xd8]，
; 读可选头中entry偏移[0x1000]，代码段偏移[0x1000]，数据段偏移[0x2000]，映像基地址[0x40000]，
; 然后可以跳过可选头到节目录[位置=0xd8+0xe0=0x1b8]
; 遍历目录，直到找到.text节和.data节的信息[.text:在0x400长0x200  .data:在0x800长0x200]
; 读.text节数据[offset+size]，写到0x41000[base+offset]
; 读.data节数据[offset+size]，写到0x42000[base+offset]
; 通过far jmp将cs置为0x4000[base]，ip置为0x1000[entry]
;
	pushregs

	push 	str_map_kernel
	call 	printf
	add 	esp, 4

	; check dos header (pe signature) ;
	mov 	esi, [kernel_address + 0x3c]	;0xc0
	add 	esi, kernel_address
	push 	esi
	push 	str_pe_signature
	call 	printf
	add 	esp, 4*2

	; skip file header (section count = ?);
	xor 	eax, eax
	mov 	word ax, [esi + 0x4 + 0x2]
	mov 	[kernel_image_section_count], eax
	add 	esi, (0x4+0x14)				;0xd8=0xc0+0x18
	push 	esi
	push 	eax
	push 	str_skip_file_header
	call 	printf
	add 	esp, 4*3

	; read optional header ;
	mov 	eax, [esi + 0x10]
	mov 	[kernel_image_entry], eax
	mov 	eax, [esi + 0x14]
	mov 	[kernel_image_data_base], eax
	mov 	eax, [esi + 0x18]
	mov 	[kernel_image_code_base], eax
	mov 	eax, [esi + 0x1c]
	mov 	[kernel_image_image_base], eax
	push 	dword [kernel_image_image_base]
	push 	dword [kernel_image_data_base]
	push 	dword [kernel_image_code_base]
	push 	dword [kernel_image_entry]
	push 	dword str_read_info_in_opt
	call 	printf
	add 	esp, 4*5

	; skip opt at section directory ;
	add 	esi, 0xe0
	push 	esi
	push 	str_skip_opt_header
	call 	printf
	add 	esp, 4 * 2

	;84f5

	; read section directory ;
	mov 	ecx, [kernel_image_section_count]
.next_section_entry:
	push 	esi
	push 	str_text_name
	call 	strcmp
	add 	esp, 4 * 2

	test 	eax, eax
	jz 		.find_text

	push 	esi
	push 	str_data_name
	call 	strcmp
	add 	esp, 4 * 2

	test 	eax, eax
	jz 		.find_data	

	add 	esi, 0x28
	loop	.next_section_entry
	jmp 	.read_section_directory_end

.find_text:
	mov 	eax, [esi + 0x0c]
	mov 	[kernel_image_code_base], eax
	mov 	eax, [esi + 0x10]
	mov 	[kernel_image_code_size], eax
	mov 	eax, [esi + 0x14]
	mov 	[kernel_image_code_offset], eax
	add 	esi, 0x28
	loop	.next_section_entry
.find_data:
	mov 	eax, [esi + 0x0c]
	mov 	[kernel_image_data_base], eax
	mov 	eax, [esi + 0x10]
	mov 	[kernel_image_data_size], eax
	mov 	eax, [esi + 0x14]
	mov 	[kernel_image_data_offset], eax
	add 	esi, 0x28
	loop	.next_section_entry

.read_section_directory_end:

	push 	dword [kernel_image_code_base]
	push 	dword [kernel_image_code_size]
	push 	dword [kernel_image_code_offset]
	push 	str_text_section_info
	call 	printf
	add 	esp, 4 * 4

	push 	dword [kernel_image_data_base]
	push 	dword [kernel_image_data_size]
	push 	dword [kernel_image_data_offset]
	push 	str_data_section_info
	call 	printf
	add 	esp, 4 * 4

	; copy code ;
	push 	dword [kernel_image_code_size]	; size
	mov 	ebx, [kernel_image_image_base]
	add 	ebx, [kernel_image_code_base] 	; to memory
	push 	ebx
	mov 	ecx, kernel_address
	add 	ecx, [kernel_image_code_offset]
	push 	ecx								; from file 
	call 	memcpy
	add 	esp, 4 * 3

	push 	ebx
	push 	ecx
	push 	str_copy_code_section
	call 	printf
	add 	esp, 4 * 3

	; copy data ;
	push 	dword [kernel_image_data_size]	; size
	mov 	ebx, [kernel_image_image_base]
	add 	ebx, [kernel_image_data_base] 	; to memory
	push 	ebx
	mov 	ecx, kernel_address
	add 	ecx, [kernel_image_data_offset]
	push 	ecx								; from file 
	call 	memcpy
	add 	esp, 4 * 3

	push 	ebx
	push 	ecx
	push 	str_copy_data_section
	call 	printf
	add 	esp, 4 * 3

	popregs
	ret


;;;;;;;;;;;;;;;;;;;;;;;
; data                ;
;;;;;;;;;;;;;;;;;;;;;;;
%define 	abs_addr_here 		(loader_address + $ - $$)
%define 	CRLF 0dh, 0ah
str_loading_kernel:		db  	"loading kernel...", CRLF, 0
str_from_sector:		db 		"from sector: 0x", 0
str_sector_count:		db 		"sector count: 0x", 0
str_new_line 			equ 	abs_addr_here
						db 		CRLF, 0
str_map_kernel 	 		equ 	abs_addr_here
						db 		"mapping kernel...", CRLF, 0
str_pe_signature		equ 	abs_addr_here
						db 		"pe signature at 0x%x(0xc0?)", CRLF, 0
str_skip_file_header 	equ 	abs_addr_here
						db 		"file header: section count=0x%x, skip, at opt(0xd8?): 0x%x", CRLF, 0
str_read_info_in_opt 	equ 	abs_addr_here
						db		"entry=0x%x, code=0x%x, data=0x%x, image=0x%x", CRLF, 0
str_skip_opt_header 	equ 	abs_addr_here
						db		"skip opt, at section directory(0x1b8?): 0x%x", CRLF, 0
str_text_section_info 	equ 	abs_addr_here
						db 		".text: offset=0x%x, size=0x%x, vaddr=0x%x", CRLF, 0
str_data_section_info 	equ 	abs_addr_here
						db 		".data: offset=0x%x, size=0x%x, vaddr=0x%x", CRLF, 0
str_copy_code_section 	equ 	abs_addr_here
						db 		"copy code from 0x%x to 0x%x", CRLF, 0
str_copy_data_section 	equ 	abs_addr_here
						db 		"copy data from 0x%x to 0x%x", CRLF, 0
str_text_name 			equ 	abs_addr_here
						db		'.text', 0
str_data_name 			equ 	abs_addr_here
						db		'.data', 0
; cursor ;
cursor_low:				db 		0
cursor_low_phy			equ 	cursor_low - $$ + loader_address
cursor_high:			db 		0
cursor_high_phy			equ 	cursor_high - $$ + loader_address
; kernel image variables ;
kernel_image_section_count 	dd 		0		
kernel_image_entry 			dd 		0
kernel_image_code_base		dd 		0
kernel_image_data_base 		dd		0
kernel_image_image_base	 	dd 		0
kernel_image_code_offset 	dd 		0
kernel_image_code_size	 	dd 		0
kernel_image_data_offset 	dd 		0
kernel_image_data_size	 	dd 		0
