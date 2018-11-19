# top_dir 		= $(realpath .)/
top_dir			= c:/tinyos/
include ./include/env_prev.mk

.PHONY: all
all: build hd

.PHONY: build
build:
	make all top_dir=$(top_dir) -C $(boot_dir)
	make all top_dir=$(top_dir) -C $(kernel_dir)

.PHONY: clean
clean:
	make clean top_dir=$(top_dir) -C $(boot_dir)
	make clean top_dir=$(top_dir) -C $(kernel_dir)
	make clean top_dir=$(top_dir) -C $(debug_dir)

.PHONY: hd
hd:
	$(debug_dir)hdmaker.exe "$(debug_dir)tinyos.vhd" "$(bin_dir)boot.bin" "$(bin_dir)loader.bin" "$(bin_dir)kernel.exe"

.PHONY: debug
debug:
	make debug -C $(debug_dir)



#
#run:
#	bochs -q
#vbox:
#	Virtualbox C:\Users\andycylin\tiny\tinyos\tinyos.vbox
#


