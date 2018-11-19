include ../include/env_prev.mk

.PHONY: all
all: $(bin_dir) $(boot_bin) $(loader_bin) 

$(boot_bin): $(boot_src)
	$(asm) -o $(boot_bin) $(boot_src)

$(loader_bin): $(loader_src)
	$(asm) -o $(loader_bin) $(loader_src)

.PHONY: clean
clean:
	rm -rf $(loader_bin) $(boot_bin)

include ../include/env_post.mk