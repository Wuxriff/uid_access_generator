@tool
class_name UAGTarget
extends Resource

## A single generation target: one asset folder becomes one generated script.
##
## Edit these in the inspector on a [UAGConfig] resource. Each target produces
## exactly one file exposing a global class named [member class_name_override].

## Folder to scan, as a [code]res://[/code] path. Every file inside whose
## extension is in [code]uid_access_generator/generator/valid_extensions[/code]
## becomes a constant.
@export_dir var folder: String = ""

## Name of the generated global class, e.g. [code]MyAssets[/code].
## Must be a valid identifier and must not collide with an existing class name.
## Surrounding whitespace is trimmed automatically; read it via
## [method get_class_name] rather than directly.
@export var class_name_override: String = ""

## When [code]true[/code], subfolders are scanned too and all files are
## flattened into the same class. Duplicate names across subfolders are
## skipped with a warning; the first match wins.
@export var recursive: bool = false

## When [code]true[/code], also emit an [code]Id[/code] enum plus a
## [code]NAMES[/code] lookup array, so exported properties get a real
## inspector dropdown via [code]@export var id: MyAssets.Id[/code].
@export var generate_enum: bool = true

## When [code]true[/code], emit an [code]ENUM_NAMES[/code] string constant
## (comma-joined file names) for use with [code]PROPERTY_HINT_ENUM[/code].
@export var generate_enum_names: bool = true

## When [code]true[/code], emit a [code]UIDS[/code] dictionary mapping each id
## to its [code]uid://[/code] reference, so the constant can actually be loaded:
## [codeblock]
## var res := load(MyAssets.UIDS[MyAssets.SOME_ID])
## [/codeblock]
## Files without a UID are skipped with a warning.
@export var generate_uids: bool = true


## [member folder] with surrounding whitespace removed and any trailing
## slash dropped. Always use this instead of the raw property.
func get_folder() -> String:
	var value := folder.strip_edges()
	if value.length() > len("res://") and value.ends_with("/"):
		value = value.rstrip("/")
	return value


## [member class_name_override] with surrounding whitespace removed. Pasting a
## name with a stray leading or trailing space is a typo, not a configuration
## error, so it is corrected here rather than rejected in [method validate].
func get_class_name() -> String:
	return class_name_override.strip_edges()


## Returns an empty array when this target is usable, or a list of
## human-readable problems describing why it is not.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var target_folder := get_folder()
	var target_class := get_class_name()

	if target_folder.is_empty():
		problems.append("'folder' is empty.")
	elif not target_folder.begins_with("res://"):
		problems.append("'folder' must be a res:// path, got '%s'." % target_folder)

	if target_class.is_empty():
		problems.append("'class_name_override' is empty.")
	elif not target_class.is_valid_ascii_identifier():
		problems.append(
			"'class_name_override' ('%s') is not a valid identifier - %s."
			% [target_class, _describe_identifier_problem(target_class)]
		)
	elif target_class[0] == target_class[0].to_lower():
		problems.append(
			"'class_name_override' ('%s') should start with an uppercase letter."
			% target_class
		)

	return problems


## Explains *why* a name is rejected, since the offending character is often
## invisible when the name is simply echoed back.
static func _describe_identifier_problem(value: String) -> String:
	var first_code := value.unicode_at(0)
	if first_code >= 48 and first_code <= 57:
		return "it starts with a digit"

	var offenders := PackedStringArray()
	for character in value:
		if character == "_":
			continue
		var code := character.unicode_at(0)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		if is_digit or is_upper or is_lower:
			continue
		var label := "space" if character == " " else "'%s'" % character
		if not offenders.has(label):
			offenders.append(label)

	if offenders.is_empty():
		return "only letters, digits and underscores are allowed"
	return "it contains %s" % ", ".join(offenders)


## File name (without directory) of the script this target generates.
func get_output_file_name() -> String:
	return "%s.gd" % get_class_name().to_snake_case()
