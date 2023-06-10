@tool
extends EditorPlugin

const AUTOLOAD_NAME = "PlaytestTelemetry"

const main_screen_scene: PackedScene = preload("res://addons/PlaytestTelemetry/MainScreen.tscn")
var main_screen: PlaytestTelemetryMainScreen

func _enter_tree():
	# The autoload can be a scene or script file.
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/PlaytestTelemetry/PlaytestTelemetry.gd")
	_add_custom_project_setting("playtest_telemetry/url", "http://localhost:8000/upload", TYPE_STRING, PROPERTY_HINT_PLACEHOLDER_TEXT, "https://example.com/upload")
	_add_custom_project_setting("playtest_telemetry/api_key", "testkey", TYPE_STRING, PROPERTY_HINT_PLACEHOLDER_TEXT, "ABCD1234")
	_add_custom_project_setting("playtest_telemetry/version", "1.0.0", TYPE_STRING, PROPERTY_HINT_PLACEHOLDER_TEXT, "1.0.0")

	var error: int = ProjectSettings.save()
	if error:
		push_error("Encountered error %d when saving project settings." % error)
	
	main_screen = main_screen_scene.instantiate()
	# Add the main panel to the editor's main viewport.
	get_editor_interface().get_editor_main_screen().add_child(main_screen)
	# Hide the main panel. Very much required.
	_make_visible(false)

func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME)
	main_screen.queue_free()
	main_screen = null

func _add_custom_project_setting(name: String, default_value: Variant, type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> void:
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

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	main_screen.visible = visible

func _get_plugin_name() -> String:
	return "Telemetry"
	
func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("WorldEnvironment", "EditorIcons")
