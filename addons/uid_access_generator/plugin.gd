@tool
extends EditorPlugin

## Entry point: registers the Tools menu items and drives the generation pass.

const MENU_GENERATE := "Generate UAG IDs"
const MENU_CREATE_CONFIG := "UAG: Create Config"

const UAGInspectorPlugin := preload("uag_inspector_plugin.gd")

var _inspector_plugin: EditorInspectorPlugin


func _enter_tree() -> void:
	UAGSettings.initialize()
	add_tool_menu_item(MENU_GENERATE, _on_generate_pressed)
	add_tool_menu_item(MENU_CREATE_CONFIG, _on_create_config_pressed)

	_inspector_plugin = UAGInspectorPlugin.new()
	add_inspector_plugin(_inspector_plugin)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_GENERATE)
	remove_tool_menu_item(MENU_CREATE_CONFIG)

	if _inspector_plugin != null:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null


func _on_generate_pressed() -> void:
	var config_path := UAGSettings.get_config_path()

	if not ResourceLoader.exists(config_path):
		push_error(
			"UAG: no config at '%s'. Run Project > Tools > %s first."
			% [config_path, MENU_CREATE_CONFIG]
		)
		return

	var config := ResourceLoader.load(config_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if config == null or not config is UAGConfig:
		push_error("UAG: '%s' is not a UAGConfig resource." % config_path)
		return

	var targets := (config as UAGConfig).get_valid_targets()
	if targets.is_empty():
		push_warning("UAG: no valid targets in '%s'; nothing generated." % config_path)
		return

	print("UAG: starting ID generation...")

	# Full rebuild: wipe first so removed targets leave nothing behind.
	UAGFileIO.clear_generated()

	var valid_extensions := UAGSettings.get_valid_extensions()
	if valid_extensions.is_empty():
		push_warning(
			"UAG: '%s' is empty, so no file will match."
			% UAGSettings.EXTENSIONS_SETTING
		)

	var written := 0
	var total_constants := 0

	for target in targets:
		var entries := UAGScanner.scan_target(target, valid_extensions)
		var content := UAGGenerator.build_script(target, entries)

		if UAGFileIO.save_generated(target.get_output_file_name(), content):
			written += 1
			total_constants += entries.size()
			print("UAG: generated %s (%d ids)." % [target.get_class_name(), entries.size()])

	UAGFileIO.refresh_filesystem()
	print("UAG: done - %d script(s), %d id(s) total." % [written, total_constants])


func _on_create_config_pressed() -> void:
	var config_path := UAGSettings.get_config_path()

	if ResourceLoader.exists(config_path):
		push_warning("UAG: config already exists at '%s'; left untouched." % config_path)
		EditorInterface.edit_resource(ResourceLoader.load(config_path))
		return

	var config := UAGConfig.new()
	var error := ResourceSaver.save(config, config_path)
	if error != OK:
		push_error("UAG: failed to create config at '%s' (error %d)." % [config_path, error])
		return

	UAGFileIO.refresh_filesystem()
	print("UAG: created config at '%s'. Add targets in the inspector." % config_path)
	EditorInterface.edit_resource(ResourceLoader.load(config_path))
