@tool
extends EditorPlugin

const AUTOLOAD_NAME = "PlaytestTelemetry"

func _enter_tree():
	# The autoload can be a scene or script file.
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/PlaytestTelemetry/PlaytestTelemetry.gd")
	_add_custom_project_setting("playtest_telemetry/url", "http://localhost:8000/upload", TYPE_STRING, PROPERTY_HINT_PLACEHOLDER_TEXT, "https://example.com/upload")
	_add_custom_project_setting("playtest_telemetry/api_key", "testkey", TYPE_STRING, PROPERTY_HINT_PLACEHOLDER_TEXT, "ABCD1234")
	_add_custom_project_setting("playtest_telemetry/version", "1.0.0", TYPE_STRING, PROPERTY_HINT_PLACEHOLDER_TEXT, "1.0.0")
	var error: int = ProjectSettings.save()
	if error:
		push_error("Encountered error %d when saving project settings." % error)

func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME)

func _add_custom_project_setting(name: String, default_value, type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> void:
	if ProjectSettings.has_setting(name):
		return

	var setting_info: Dictionary = {
		"name": name,
		"type": type,
		"hint": hint,
		"hint_string": hint_string
	}

	ProjectSettings.set_setting(name, default_value)
	ProjectSettings.add_property_info(setting_info)
	ProjectSettings.set_initial_value(name, default_value)
