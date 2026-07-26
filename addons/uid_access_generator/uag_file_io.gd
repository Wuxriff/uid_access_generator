@tool
class_name UAGFileIO
extends RefCounted

## Writes generated scripts and keeps the editor's filesystem cache in sync.
##
## The output folder must never contain a [code].gdignore[/code]: that would
## hide the generated scripts from Godot and their [code]class_name[/code]
## would never register.

const GENERATED_DIR := "res://addons/uid_access_generator/generated"
const GENERATED_SUFFIX := ".uaggen.gd"


## Deletes every previously generated script, so each run is a full rebuild
## and stale entries cannot survive. Files not ending in [constant GENERATED_SUFFIX]
## are left untouched.
static func clear_generated() -> void:
	if not DirAccess.dir_exists_absolute(GENERATED_DIR):
		return

	var dir := DirAccess.open(GENERATED_DIR)
	if dir == null:
		push_error("UAG: cannot open '%s' (error %d)." % [GENERATED_DIR, DirAccess.get_open_error()])
		return

	for file_name in DirAccess.get_files_at(GENERATED_DIR):
		if not file_name.ends_with(GENERATED_SUFFIX):
			continue
		var error := dir.remove(file_name)
		if error != OK:
			push_error("UAG: failed to delete '%s' (error %d)." % [file_name, error])


## Writes [param content] as the generated script for [param base_file_name].
## Returns [code]true[/code] on success.
static func save_generated(base_file_name: String, content: String) -> bool:
	if not _ensure_dir():
		return false

	var file_name := base_file_name.get_basename() + GENERATED_SUFFIX
	var path := GENERATED_DIR.path_join(file_name)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("UAG: cannot write '%s' (error %d)." % [path, FileAccess.get_open_error()])
		return false

	file.store_string(content)
	file.close()
	return true


static func _ensure_dir() -> bool:
	if DirAccess.dir_exists_absolute(GENERATED_DIR):
		return true

	var error := DirAccess.make_dir_recursive_absolute(GENERATED_DIR)
	if error != OK:
		push_error("UAG: cannot create '%s' (error %d)." % [GENERATED_DIR, error])
		return false
	return true


## Makes the editor pick up newly created scripts so their global
## [code]class_name[/code] entries register without a restart.
static func refresh_filesystem() -> void:
	if not Engine.is_editor_hint():
		return

	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem == null:
		return

	# A full scan is required for newly created files; update_file() alone
	# does not register a brand-new global class.
	filesystem.scan()
