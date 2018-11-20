# top_dir 		= $(realpath .)/
top_dir			= c:/tinyos/
include ./include/env_prev.mk

.PHONY: all
all: clean build hd

.PHONY: build
build:
	make all top_dir=$(top_dir) -C $(boot_dir)
	make all top_dir=$(top_dir) -C $(kernel_dir)

.PHONY: clean
clean:
	make clean top_dir=$(top_dir) -C $(boot_dir)
	make clean top_dir=$(top_dir) -C $(kernel_dir)
	make clean top_dir=$(top_dir) -C $(debug_dir)
	rm -f $(debug_dir)_tinyos.vhd

.PHONY: hd
hd:
	echo f | xcopy /f /y "$(debug_dir)tinyos.vhd" "$(debug_dir)_tinyos.vhd"
	hdmaker.exe "$(debug_dir)_tinyos.vhd" "$(bin_dir)boot.bin" "$(bin_dir)loader.bin" "$(bin_dir)kernel.exe"

.PHONY: debug
debug:
	make debug -C $(debug_dir)



#
#run:
#	bochs -q
#vbox:
#	Virtualbox C:\Users\andycylin\tiny\tinyos\tinyos.vbox
#


