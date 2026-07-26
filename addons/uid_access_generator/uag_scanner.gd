@tool
class_name UAGScanner
extends RefCounted

## Turns a [UAGTarget] into the concrete list of identifiers to emit.
##
## Targets come from the [UAGConfig] manifest, so this stage only walks the
## filesystem - nothing here parses source code.

## One discovered asset file.
class Entry:
	## File name without directory or extension. This is the runtime value of
	## the generated [StringName].
	var file_name: String

	## Constant identifier, e.g. [code]SOME_ASSET[/code].
	var constant_name: String

	## Full [code]res://[/code] path, kept for diagnostics and UID lookup.
	var source_path: String

	func _init(p_file_name: String, p_constant_name: String, p_source_path: String) -> void:
		file_name = p_file_name
		constant_name = p_constant_name
		source_path = p_source_path

	## Returns this file's [code]uid://[/code] reference, or an empty string if
	## it has none. Assets only get a UID once the editor has imported them, so
	## a freshly copied file can legitimately return "" until the next scan.
	func get_uid() -> String:
		var id := ResourceLoader.get_resource_uid(source_path)
		if id == ResourceUID.INVALID_ID:
			return ""
		return ResourceUID.id_to_text(id)


## Collects every generatable file for [param target], sorted by constant name
## so output is stable across runs and filesystem orderings.
## Returns an empty array if the folder does not exist (an error is pushed).
static func scan_target(target: UAGTarget, valid_extensions: PackedStringArray) -> Array[Entry]:
	var entries: Array[Entry] = []

	var folder := target.get_folder()

	if not DirAccess.dir_exists_absolute(folder):
		push_error("UAG: directory not found at '%s'." % folder)
		return entries

	var seen_constants := {}
	_collect(folder, target.recursive, valid_extensions, seen_constants, entries)

	entries.sort_custom(func(a: Entry, b: Entry) -> bool: return a.constant_name < b.constant_name)
	return entries


static func _collect(
	dir_path: String,
	recursive: bool,
	valid_extensions: PackedStringArray,
	seen_constants: Dictionary,
	entries: Array[Entry]
) -> void:
	for file_name in DirAccess.get_files_at(dir_path):
		# Godot exposes imported assets as their source file here, so the
		# sidecars it writes alongside them are never generation targets.
		if file_name.ends_with(".import") or file_name.ends_with(".uid"):
			continue

		var extension := ".%s" % file_name.get_extension().to_lower()
		if not valid_extensions.has(extension):
			continue

		var base_name := file_name.get_basename()
		var constant_name := to_constant_name(base_name)
		var source_path := dir_path.path_join(file_name)

		if constant_name.is_empty() or not constant_name.is_valid_ascii_identifier():
			push_warning(
				"UAG: '%s' does not yield a valid identifier ('%s') and was skipped."
				% [source_path, constant_name]
			)
			continue

		# First match wins, mirroring the documented recursive-collision rule.
		if seen_constants.has(constant_name):
			push_warning(
				"UAG: skipped duplicate ID '%s' from '%s' (already defined by '%s')."
				% [constant_name, source_path, seen_constants[constant_name]]
			)
			continue

		seen_constants[constant_name] = source_path
		entries.append(Entry.new(base_name, constant_name, source_path))

	if not recursive:
		return

	for sub_dir in DirAccess.get_directories_at(dir_path):
		if sub_dir.begins_with("."):
			continue
		_collect(dir_path.path_join(sub_dir), true, valid_extensions, seen_constants, entries)


## Converts a file name to a GDScript constant identifier:
## [code]some-asset[/code] → [code]SOME_ASSET[/code].
static func to_constant_name(file_name: String) -> String:
	var sanitized := ""
	for character in file_name:
		# Any separator (space, dash, dot...) becomes an underscore so
		# to_snake_case sees a word boundary rather than dropping it.
		sanitized += character if _is_identifier_char(character) else "_"

	var result := sanitized.to_snake_case().to_upper()

	while result.contains("__"):
		result = result.replace("__", "_")
	result = result.lstrip("_").rstrip("_")

	# Identifiers may not start with a digit.
	if not result.is_empty():
		var first_code := result.unicode_at(0)
		if first_code >= 48 and first_code <= 57:
			result = "_" + result

	return result


static func _is_identifier_char(character: String) -> bool:
	if character == "_":
		return true
	var code := character.unicode_at(0)
	var is_digit := code >= 48 and code <= 57      # 0-9
	var is_upper := code >= 65 and code <= 90      # A-Z
	var is_lower := code >= 97 and code <= 122     # a-z
	return is_digit or is_upper or is_lower
