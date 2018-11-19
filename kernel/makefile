include ../include/env_prev.mk

.PHONY: all
all: $(kernel_bin)

$(kernel_bin): $(kernel_obj)
	$(ld) $(ldflags) $^

$(kernel_obj): $(kernel_src) $(obj_dir)
	$(cc) $(cflags) $(kernel_src)

.PHONY: clean
clean:
	rm -rf $(kernel_obj) $(kernel_bin) $(kernel_pdb) $(vc140_pdb)
	rm -rf $(obj_dir)
	rm -rf $(bin_dir)

include ../include/env_post.mk