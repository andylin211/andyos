$(bin_dir):
	if not exist "$(bin_dir)" ( mkdir "$(bin_dir)" )

$(obj_dir): $(bin_dir)
	if not exist "$(obj_dir)" ( mkdir "$(obj_dir)" )