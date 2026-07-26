@tool
class_name UAGConfig
extends Resource

## Manifest listing every folder the generator should turn into a constants script.
##
## Create one via [b]Project → Tools → UAG: Create Config[/b] (or manually as
## a new [UAGConfig] resource) and save it at [constant DEFAULT_PATH].
## Add a [UAGTarget] per asset folder, then run
## [b]Project → Tools → Generate UAG IDs[/b].

## Where the plugin looks for the manifest.
const DEFAULT_PATH := "res://uid_access_generator.tres"

## One entry per generated script.
@export var targets: Array[UAGTarget] = []


## Returns the targets that are safe to generate, pushing a warning for each
## one that is skipped. Two targets that would generate the same global class
## name are rejected, since duplicate class names are a project-wide error.
func get_valid_targets() -> Array[UAGTarget]:
	var valid: Array[UAGTarget] = []
	var seen_class_names := {}
	var index := -1

	for target in targets:
		index += 1

		if target == null:
			push_warning("UAG: target #%d is empty, skipping." % index)
			continue

		var problems := target.validate()
		if not problems.is_empty():
			push_warning(
				"UAG: target #%d ('%s') skipped: %s"
				% [index, target.get_class_name(), ", ".join(problems)]
			)
			continue

		var target_class := target.get_class_name()
		if seen_class_names.has(target_class):
			push_warning(
				"UAG: target #%d skipped: class name '%s' is already used by target #%d."
				% [index, target_class, seen_class_names[target_class]]
			)
			continue

		seen_class_names[target_class] = index
		valid.append(target)

	return valid
