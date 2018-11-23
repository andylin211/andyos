section mbr align=16 vstart=0x7c00
boot_entry:
    mov     ax, cs
    mov     ds, ax
    mov     ss, ax
    mov     sp, 07c00h
    jmp     load_loader

load_loader:
; load loader.bin to address 0x8000
;

directory_address     equ 0x7e00
loader_addresss        equ 0x8000

    ; read directory sector ;
    push     0x0000 ; high
    push     directory_address ; low
    push     0x0001 ; sector index
    call     hd_read_one_sector
    add     sp, 6

    ; loader offset and size ;
    mov     dx, [ds:directory_address+0x08]
    mov     cx, [ds:directory_address+0x0c]

    mov     bx, loader_addresss
.next_sector:
    ; hd_read_one_sector() ;
    push     0x0000     ; high
    push     bx         ; low
    push     dx         ; sector index
    call     hd_read_one_sector
    add     sp, 6    

    ; update address and read ;
    add     bx, 512
    inc     dx
    loop     .next_sector

    ; jump to loader ;
    jmp     0:0x8000

hd_read_one_sector:
;
; word hd_read_one_sector(sector_index, address_low, address_high)
; @return 0 if succeed, 1 if fail
;
; 参考
;
; 软盘
;     al=扇区数, ah=中断子功能号 (2=读扇区,3=写扇区)
;   {cl的6,7位,ch}=磁道号, {cl的低6位}=扇区号
;   dh=磁头号, dl=驱动器号(0=软盘,80h=硬盘)
;   es:bx=数据缓冲区的地址
;
; 硬盘    
;     LBA28逻辑扇区编码方式
;     主硬盘控制器端口号: 0x1f0, 0x1f1, ..., 0x1f7
;         0x1f2 -- 需要读取的扇区数量（变）, 8位端口, 最大255, 0表示读256个扇区
;            eg:     
;                mov dx, 0x1f2 \ mov    al, 0x01 \ out    dx, al
;        0x1f3,0x1f4,0x1f5,0x1f6 -- 28位太长, 需要4个端口, {0,7}{8,15}{16,23}{24,27}, 
;                                  -- 0x1f6端口特殊({5,7}<-0111b表示LBA模式, {4}<-0或1表示主盘或者从盘) 
;            eg:
;                mov    dx, 0x1f3 \ mov al, 0x02 \ out dx, al
;                inc    dx \ xor al, al \ out dx, al
;                inc    dx \ out dx, al
;                inc    dx \ mov al, 0xe0 \ out dx, al
;        0x1f7 -- 命令端口, 读/写, 0x20/?
;              -- 也是状态端口, {7}=1表示busy, {4}=1表示data ready
;            eg:
;                mov dx, 0x1f7 \ mov al, 0x20 \ out dx, al        
;            eg:
;                mov dx, 0x1f7
;                 .wait:
;                int al, dx \ and al, 0x88 \ cmp al, 0x08
;                jnz .wait
;        0x1f1 -- 错误端口
;        0x1f0 -- 数据端口, 16位端口, 
;            eg:
;                mov cx, 256 \ mov dx, 1f0
;                .readw:
;                in ax, dx \ mov [bx], ax \ add bx, 2 
;                loop .readw
;                
    push     bp
    mov     bp, sp
    push     bx
    push     cx
    push     dx
    push     es

    ; read 1 sector ;
    mov     dx, 0x1f2
    mov     al, 0x01
    out     dx, al 

    ; read 2nd secotr ; 
    mov     dx, 0x1f3
    mov     byte al, [bp+4]
    out     dx, al
    inc     dx
    xor     al, al
    out     dx, al
    inc     dx
    out     dx, al
    inc     dx
    mov     al, 0xe0
    out     dx, al

    ; do read ;
    mov     dx, 0x1f7
    mov     al, 0x20
    out     dx, al

    ; wait ;
.wait_for_data:
    in         al, dx
    and     al, 0x89
    cmp     al, 0x08
    je         .data_is_ready
    and     al, 0x01
    test     al, al
    jnz        .error_occur
    jmp     .wait_for_data
.data_is_ready:

    ; copy ;
    mov     cx, 256
    mov     bx, [bp+8]
    mov     es, bx
    mov     bx, [bp+6]
    mov     dx, 0x1f0
.read_next_word:
    in         ax, dx
    mov     word [es:bx], ax
    add     bx, 2
    loop     .read_next_word

    ; return ;
    xor     ax, ax
    jmp     .exit0
.error_occur:
    mov     ax, 0x01
.exit0:

    pop     es
    pop     dx
    pop     cx
    pop     bx
    pop     bp
    ret 

fill_with_zero:
    times     510-(fill_with_zero - boot_entry) db 0

end_with_0xaa55:
    dw         0xaa55
