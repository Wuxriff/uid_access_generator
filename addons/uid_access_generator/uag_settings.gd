@tool
class_name UAGSettings
extends RefCounted

## Registers and reads the plugin's Project Settings entries.

const EXTENSIONS_SETTING := "uid_access_generator/generator/valid_extensions"
const CONFIG_PATH_SETTING := "uid_access_generator/generator/config_path"

const DEFAULT_EXTENSIONS: PackedStringArray = [
	".wav", ".ogg", ".mp3", ".tscn", ".tres",
	".glb", ".blend", ".fbx",
]


## Creates the settings with their defaults if absent, and always re-registers
## their property info (which is not persisted across editor restarts, so this
## must run on every [code]_enter_tree[/code]).
##
## Note: values still equal to their initial value are deliberately not written
## to [code]project.godot[/code] by the engine. That is why the defaults must be
## re-applied here on every launch rather than relied upon to persist; only a
## value the user actually changed ends up in the file.
static func initialize() -> void:
	_ensure_setting(EXTENSIONS_SETTING, DEFAULT_EXTENSIONS)
	ProjectSettings.add_property_info({
		"name": EXTENSIONS_SETTING,
		"type": TYPE_PACKED_STRING_ARRAY,
	})

	_ensure_setting(CONFIG_PATH_SETTING, UAGConfig.DEFAULT_PATH)
	ProjectSettings.add_property_info({
		"name": CONFIG_PATH_SETTING,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.tres,*.res",
	})


static func _ensure_setting(path: String, default_value: Variant) -> void:
	if not ProjectSettings.has_setting(path):
		ProjectSettings.set_setting(path, default_value)
	ProjectSettings.set_initial_value(path, default_value)


## Extensions considered generatable, normalised to lowercase and guaranteed
## to start with a dot, so users may write either "ogg" or ".ogg".
static func get_valid_extensions() -> PackedStringArray:
	var raw: PackedStringArray = DEFAULT_EXTENSIONS
	if ProjectSettings.has_setting(EXTENSIONS_SETTING):
		raw = ProjectSettings.get_setting(EXTENSIONS_SETTING)

	var normalised := PackedStringArray()
	for extension in raw:
		var value := String(extension).strip_edges().to_lower()
		if value.is_empty():
			continue
		if not value.begins_with("."):
			value = "." + value
		if not normalised.has(value):
			normalised.append(value)

	return normalised


static func get_config_path() -> String:
	if ProjectSettings.has_setting(CONFIG_PATH_SETTING):
		var path := String(ProjectSettings.get_setting(CONFIG_PATH_SETTING)).strip_edges()
		if not path.is_empty():
			return path
	return UAGConfig.DEFAULT_PATH
