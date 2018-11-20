include ../include/env_prev.mk

.PHONY: debug
debug:
	bochsdbg -q

.PHONY: clean
clean:
	rm -rf $(debug_dir)Logs
	rm -f $(debug_dir)_tinyos.vhd
	rm -f $(debug_dir)tinyos.vbox-prev
