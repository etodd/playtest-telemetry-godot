@tool
class_name PlaytestTelemetryMainScreen
extends Control

@onready var load_file_dialog: FileDialog = $HBoxContainer/VBoxContainer/LoadFileDialog
@onready var item_list: ItemList = $HBoxContainer/VBoxContainer/ItemList
@onready var viewport: SubViewport = $HBoxContainer/SubViewportContainer/SubViewport

var dirty: bool = false
var playback_speed: float = 0.0

func _on_load_file_dialog_files_selected(paths: PackedStringArray) -> void:
	var sessions: Array
	for path in paths:
		var gzipped: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var rawJSON: PackedByteArray = gzipped.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
		var data: Array = JSON.parse_string(rawJSON.get_string_from_utf8())
		sessions.append_array(data)
	item_list.clear()
	var unix_time: float = Time.get_unix_time_from_system()
	for session in sessions:
		var duration: int = int(session["in_game_duration"])
		var hours: int = duration / 60
		var minutes: int = (duration % 3600) / 60
		var seconds: int = duration % 60
		var durationString: String
		if hours > 0:
			durationString = "%dh%dm%ds" % [hours, minutes, seconds]
		else:
			durationString = "%dm%ds" % [minutes, seconds]
		var daysPast: int = int((unix_time - session["start"]) / (60.0 * 60.0 * 24.0))
		
		item_list.add_item("%s [%d days ago] [%s]" % [durationString, daysPast, session["device"]["id"]])
		item_list.set_item_metadata(item_list.item_count-1, session["id"])
		item_list.select(item_list.item_count-1, false)
	dirty = true

func _on_load_button_pressed() -> void:
	load_file_dialog.show()

func _process(delta: float) -> void:
	if not dirty or not visible:
		return
	var selected: PackedInt32Array = item_list.get_selected_items()
	for index in selected:
		var sessionID: String = item_list.get_item_metadata(index)
	dirty = false

func _on_item_list_multi_selected(index: int, selected: bool) -> void:
	dirty = true
