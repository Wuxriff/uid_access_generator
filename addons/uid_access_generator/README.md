# UID Access Generator

> Based on the code and ideas of [Anvil](https://github.com/AhmedGD1/Anvil) by
> [AhmedGD1](https://github.com/AhmedGD1). This project would not exist without
> that work - huge thanks for the idea.

> AI tools and machine translation were used while developing this addon, both
> for the code and for the documentation you are reading. Everything has been
> reviewed and tested, but wording may occasionally read as translated.

A Godot 4.7+ editor plugin that turns asset folders into strongly-typed
`StringName` constants, so you reference assets by autocompleted identifiers
instead of magic strings.

```gdscript
# before - typo-prone, no autocomplete, fails silently
play("main_theme")

# after - autocompletes, a typo is a parse error
play(MyAssets.MAIN_THEME)
```

It also emits a `UIDS` table, so a constant can be loaded directly. UIDs survive
the file being moved or renamed, unlike a hardcoded path.

Works in the standard (non-.NET) Godot build, and can be used from C# projects.

## Install

1. Copy the `addons/uid_access_generator` folder into your project's `addons/`.
2. Enable **UID Access Generator** in **Project → Project Settings → Plugins**.

## Usage

### 1. Create the manifest

**Project → Tools → UAG: Create Config**

This writes a `UAGConfig` resource to `res://uid_access_generator.tres` and opens
it in the inspector. The manifest is the single source of truth - nothing scans
your source code.

### 2. Add a target per folder

Press **Add Target** in the inspector, then fill it in:

| Property | Meaning |
| --- | --- |
| `folder` | `res://` folder to scan. |
| `class_name_override` | Name of the generated global class, e.g. `MyAssets`. |
| `recursive` | Scan subfolders and flatten everything into one class. |
| `generate_uids` | Emit the `UIDS` dictionary + `get_uid_of()`. |
| `generate_enum` | Emit an `Id` enum + `NAMES` lookup for inspector dropdowns. |
| `generate_enum_names` | Emit the `ENUM_NAMES` string for `PROPERTY_HINT_ENUM`. |

### 3. Generate

**Project → Tools → Generate UAG IDs**

Each target produces one file at
`res://addons/uid_access_generator/generated/<snake_case_name>.uaggen.gd`.
Every run is a full rebuild: old generated files are deleted first, so removing
a target or an asset never leaves stale constants behind.

Read the Output panel afterwards - skipped files and rejected targets are
reported there as warnings.

### 4. Use the constants

```gdscript
var id := MyAssets.SOME_ASSET                   # StringName
var res := load(MyAssets.UIDS[MyAssets.SOME_ASSET])
```

## What gets generated

For a folder containing `some_asset.tres` and `other_asset.tres`:

```gdscript
class_name MyAssets

const OTHER_ASSET := &"other_asset"
const SOME_ASSET := &"some_asset"

const UIDS: Dictionary[StringName, StringName] = {
	MyAssets.OTHER_ASSET: &"uid://bxyz...",
	MyAssets.SOME_ASSET: &"uid://cabc...",
}
static func get_uid_of(id: StringName) -> StringName: ...

enum Id {
	OTHER_ASSET = 0,
	SOME_ASSET = 1,
}
const NAMES: Array[StringName] = [&"other_asset", &"some_asset"]
static func get_name_of(id: Id) -> StringName: ...
static func get_id_of(value: StringName) -> int: ...

const ENUM_NAMES := "other_asset,some_asset"
```

Constants are sorted by name, so regenerating produces a stable diff regardless
of filesystem ordering.

## Inspector dropdowns

The `Id` enum gives a native dropdown:

```gdscript
@export var id: MyAssets.Id

func _ready() -> void:
	play(MyAssets.get_name_of(id))
```

The string-hint form is also available:

```gdscript
@export_enum(MyAssets.ENUM_NAMES) var id: String
```

Trade-off: `Id` values are positional, so inserting a file in the middle shifts
the numbers of everything after it. If you serialise the choice into saved
scenes and expect the asset set to change, prefer `ENUM_NAMES` or store the
`StringName` itself.

## Settings

**Project Settings → `uid_access_generator/generator/valid_extensions`**

Defaults to `.wav .ogg .mp3 .tscn .tres .glb .blend .fbx`. Entries may be written
with or without the leading dot and are matched case-insensitively. Files whose
extension is not listed are ignored; `.import` and `.uid` sidecars always are.

The manifest location is configurable at
`uid_access_generator/generator/config_path`.

Settings still equal to their default are intentionally not written into
`project.godot` by the engine - only values you actually change are persisted.

## Naming rules

File names become `SCREAMING_SNAKE_CASE` constants: `some-asset.tres` →
`SOME_ASSET`. Separators (spaces, dashes, dots) become underscores, and a name
starting with a digit is prefixed with `_` (`01_intro.ogg` → `_01_INTRO`), since
identifiers cannot start with a number. The constant's *value* is always the
untouched file name.

Leading and trailing whitespace in `folder` and `class_name_override` is trimmed
automatically (as is a trailing slash on the folder), so a name pasted with a
stray space still works. A space *inside* the name is an error, and the warning
names the offending character.

Three edge cases produce warnings rather than silent breakage:

- **Duplicate names** (possible when `recursive` flattens subfolders): the first
  match wins, later ones are skipped and named in the warning.
- **A name containing a comma**: excluded from `ENUM_NAMES` only, because it
  would corrupt the hint string. It still gets its constant and enum entry.
- **A file with no UID yet**: left out of `UIDS`. The editor assigns UIDs on
  import, so rescan and regenerate.

## Notes

- Generated files are overwritten on every run - never hand-edit them.
- The output folder must **not** contain a `.gdignore`. That would hide the
  scripts from Godot and their `class_name` would never register.
- Two targets declaring the same `class_name_override` are rejected, since
  duplicate global class names are a project-wide error.

## Credits

The concept - generating typed identifiers for assets instead of referencing
them by string - comes from [Anvil](https://github.com/AhmedGD1/Anvil) by
[AhmedGD1](https://github.com/AhmedGD1), and parts of this plugin grew out of
that code. Thank you for the idea.

## License

MIT
