boot_dir 		= $(top_dir)boot/
kernel_dir 		= $(top_dir)kernel/
bin_dir 		= $(top_dir)bin/
obj_dir 		= $(bin_dir)obj/
debug_dir		= $(top_dir)debug/
include_dir		= $(top_dir)include/

boot_src 		= $(boot_dir)boot.asm
boot_bin 		= $(bin_dir)boot.bin
loader_src 		= $(boot_dir)loader.asm
loader_bin 		= $(bin_dir)loader.bin

kernel_src 		= $(wildcard $(kernel_dir)*.c)
kernel_src_notdir	= $(notdir $(kernel_src))
kernel_obj 		= $(patsubst %.c, $(obj_dir)%.obj, $(kernel_src_notdir))
kernel_bin	 	= $(bin_dir)kernel.exe

vc140_pdb 		= $(obj_dir)vc140.pdb
kernel_pdb		= $(bin_dir)kernel.pdb

cc 				= cl.exe
cflags			= /c /Fo"$(obj_dir)" -I$(include_dir) /Zi /Fd:$(vc140_pdb)
ld	 			= link.exe
ldflags 		= /entry:main /nodefaultlib /subsystem:console /out:$(kernel_bin) /PDB:$(kernel_pdb) /DEBUG /INCREMENTAL:NO
asm 			= nasm.exe
asmflags		= -fwin32


