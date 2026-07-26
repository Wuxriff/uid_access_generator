@tool
extends EditorInspectorPlugin

## Adds an "Add Target" button above the [UAGConfig] target list.
##
## Without it, adding a target means clicking "Add Element", then opening the
## [code]<empty>[/code] dropdown on the new slot and picking "New UAGTarget" -
## the array is typed, so Godot inserts a [code]null[/code] rather than a ready
## resource. This plugin collapses that into one click and guarantees the new
## element is never null.

const UAGTargetScript := preload("uag_target.gd")


func _can_handle(object: Object) -> bool:
	return object is UAGConfig


func _parse_begin(object: Object) -> void:
	var config := object as UAGConfig
	if config == null:
		return

	add_custom_control(_build_toolbar(config))


func _build_toolbar(config: UAGConfig) -> Control:
	var root := VBoxContainer.new()

	var button := Button.new()
	button.text = "Add Target"
	button.icon = _get_editor_icon("Add")
	button.tooltip_text = "Append a new UAGTarget to the list below."
	button.pressed.connect(_on_add_pressed.bind(config))
	root.add_child(button)

	var hint := Label.new()
	hint.text = "One target per asset folder. Generate via Project > Tools."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(1.0, 1.0, 1.0, 0.6)
	root.add_child(hint)

	return root


func _on_add_pressed(config: UAGConfig) -> void:
	var target: UAGTarget = UAGTargetScript.new()

	# Prefill with a name that is already valid, so a freshly added target
	# never trips validation just for being new.
	target.class_name_override = _suggest_class_name(config)

	config.targets.append(target)

	# Mark the resource dirty so the change reaches disk on save, then rebuild
	# the property list so the new element actually shows up.
	config.emit_changed()
	config.notify_property_list_changed()
	_refresh_inspector(config)


## Picks an unused placeholder name like [code]NewTarget2[/code], since two
## targets sharing a class name are rejected at generation time.
func _suggest_class_name(config: UAGConfig) -> String:
	var taken := {}
	for existing in config.targets:
		if existing != null:
			taken[existing.get_class_name()] = true

	var base := "NewTarget"
	if not taken.has(base):
		return base

	var suffix := 2
	while taken.has("%s%d" % [base, suffix]):
		suffix += 1
	return "%s%d" % [base, suffix]


func _refresh_inspector(config: UAGConfig) -> void:
	var inspector := EditorInterface.get_inspector()
	if inspector == null or inspector.get_edited_object() != config:
		return

	# EditorInspector has no explicit refresh; re-editing the same object
	# rebuilds the property list. Deferred so it does not run while the
	# inspector is still processing the button press.
	inspector.edit.call_deferred(config)


func _get_editor_icon(name: StringName) -> Texture2D:
	var theme := EditorInterface.get_editor_theme()
	if theme == null or not theme.has_icon(name, &"EditorIcons"):
		return null
	return theme.get_icon(name, &"EditorIcons")
