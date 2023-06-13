@tool
class_name PlaytestTelemetryMainScreen
extends Control

@onready var time_slider: HSlider = $HSplitContainer/VBoxContainer/HBoxContainer/HSlider
@onready var load_button: Button = $HSplitContainer/VBoxContainer/HBoxContainer/LoadButton
@onready var load_file_dialog: FileDialog = $HSplitContainer/VBoxContainer/LoadFileDialog
@onready var session_list: ItemList = $HSplitContainer/VBoxContainer/SessionList
@onready var property_list: ItemList = $HSplitContainer/VBoxContainer/PropertyList
@onready var viewport: PlaytestTelemetryViewport = $HSplitContainer/SubViewportContainer
@onready var transform3d_visualization: MultiMeshInstance3D = $HSplitContainer/SubViewportContainer/SubViewport/Transform3DVisualization
@onready var play_button: Button = $HSplitContainer/VBoxContainer/HBoxContainer/PlayButton

const play_icon: Texture2D = preload("res://addons/PlaytestTelemetry/Play.svg")
const pause_icon: Texture2D = preload("res://addons/PlaytestTelemetry/Pause.svg")

var dirty: bool = false
var last_playback_position: float = -1.0
var playback_speed: float = 0.0
var tracks: Array[Dictionary]

class PropertyMetadata:
	var path: String
	var node_id: String
	var name: StringName

const month_names: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

func _on_load_file_dialog_files_selected(paths: PackedStringArray) -> void:
	var sessions: Array
	for path in paths:
		var gzipped: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var rawJSON: PackedByteArray = gzipped.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
		var data: Array = JSON.parse_string(rawJSON.get_string_from_utf8())
		sessions.append_array(data)
	session_list.clear()
	var properties: Dictionary
	var transform3d_count: int = 0
	var max_duration: float = 0.0
	for session in sessions:
		for node_id in session["nodes"]:
			var node: Dictionary = session["nodes"][node_id]
			for property_name in node:
				var metadata: PropertyMetadata = PropertyMetadata.new()
				metadata.path = "%s.%s" % [node_id, property_name]
				metadata.node_id = node_id
				metadata.name = property_name
				properties[metadata.path] = metadata
				var track: Dictionary = node[property_name]
				if track["type"] == TYPE_TRANSFORM3D:
					transform3d_count += 1
		var duration: float = session["in_game_duration"]
		max_duration = max(max_duration, duration)
		var duration_seconds: int = int(duration)
		var hours: int = duration_seconds / 3600
		var minutes: int = (duration_seconds % 3600) / 60
		var seconds: int = duration_seconds % 60
		var duration_string: String
		if hours > 0:
			duration_string = "%dh%dm%ds" % [hours, minutes, seconds]
		else:
			duration_string = "%dm%ds" % [minutes, seconds]
		var date_dict: Dictionary = Time.get_date_dict_from_unix_time(session["start"])
		session_list.add_item("%s | %s %d | %s" % [duration_string, month_names[date_dict["month"]-1], date_dict["day"], session["device"]["id"]])
		session_list.set_item_metadata(session_list.item_count-1, session)
		session_list.select(session_list.item_count-1, false)
	var sorted_properties: Array[PropertyMetadata]
	for property_path in properties:
		var metadata: PropertyMetadata = properties[property_path]
		sorted_properties.append(metadata)
	sorted_properties.sort_custom(_sort_property_metadata)
	property_list.clear()
	for property_metadata in sorted_properties:
		property_list.add_item(property_metadata.path)
		property_list.set_item_metadata(property_list.item_count-1, property_metadata)
	transform3d_visualization.multimesh.instance_count = transform3d_count
	transform3d_visualization.multimesh.visible_instance_count = 0
	dirty = true
	
	time_slider.editable = true
	time_slider.max_value = max_duration
	time_slider.value = 0.0
	playback_speed = 0.0
	play_button.disabled = time_slider.value >= time_slider.max_value
	play_button.icon = play_icon
	play_button.grab_focus()

func _sort_property_metadata(a: PropertyMetadata, b: PropertyMetadata) -> bool:
	return a.path < b.path

func _on_load_button_pressed() -> void:
	load_file_dialog.show()

func _process(delta: float) -> void:
	if not visible:
		return
	if dirty:
		var selected_properties: PackedInt32Array = property_list.get_selected_items()
		tracks.resize(0)
		var transform3d_count: int = 0
		var selected_sessions: PackedInt32Array = session_list.get_selected_items()
		for session_index in selected_sessions:
			var session: Dictionary = session_list.get_item_metadata(session_index)
			var color: Color = Color.hex(session["id"].hash() | 0x000000ff)
			for node_id in session["nodes"]:
				var node: Dictionary = session["nodes"][node_id]
				for property_index in selected_properties:
					var property_metadata: PropertyMetadata = property_list.get_item_metadata(property_index)
					if node_id != property_metadata.node_id:
						continue
					if not node.has(property_metadata.name):
						continue
					var track: Dictionary = node[property_metadata.name]
					if track["type"] == TYPE_TRANSFORM3D:
						transform3d_visualization.multimesh.set_instance_color(transform3d_count, color)
						track["__instance_index"] = transform3d_count
						transform3d_count += 1
					tracks.append(track)
		transform3d_visualization.multimesh.visible_instance_count = transform3d_count
		dirty = false
		last_playback_position = -1.0 # ensure we call _track_update at least once initially
	
	if playback_speed != 0.0:
		time_slider.value += delta * playback_speed
	
	if time_slider.value == last_playback_position:
		return
	
	if time_slider.value >= time_slider.max_value:
		playback_speed = 0.0
		play_button.icon = play_icon
		play_button.disabled = true
	else:
		play_button.disabled = false
	
	for track in tracks:
		_track_update(track, time_slider.value)
	
	last_playback_position = time_slider.value

func _on_session_list_multi_selected(index: int, selected: bool) -> void:
	dirty = true

func _on_property_list_multi_selected(index: int, selected: bool) -> void:
	dirty = true

func _on_play_button_pressed():
	if playback_speed == 0.0:
		playback_speed = 1.0
		play_button.icon = pause_icon
	else:
		playback_speed = 0.0
		play_button.icon = play_icon

func _on_shown():
	play_button.grab_focus()

func _track_update(track: Dictionary, playback_position: float) -> void:
	# determine current index in the track
	var index: int = track.get("__index", 0)
	var data: Array = track["data"] # each element of "data" is an array: [game_time: float, unix_time: float, value: variant]
	var current: Array = data[index]
	while playback_position >= current[0] and index < data.size() - 1:
		index += 1
		current = data[index]
	while playback_position < current[0] and index > 0:
		index -= 1
		current = data[index]
	track["__index"] = index
	
	# get current value at that index, interpolating to the next value if necessary
	var type: int = int(track["type"])
	var value: Variant = _deserialize_property(type, current[2])
	if index < data.size() - 1:
		var next: Array = data[index + 1]
		var next_value: Variant = _deserialize_property(type, next[2])
		var lerp_amount: float = (playback_position - current[0]) / (next[0] - current[0])
		match type:
			TYPE_INT, TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I:
				value = lerp(value, next_value, lerp_amount)
			TYPE_BASIS, TYPE_QUATERNION:
				value = value.slerp(next_value, lerp_amount)
			TYPE_TRANSFORM3D:
				value.origin = lerp(value.origin, next_value.origin, lerp_amount)
				value.basis = value.basis.slerp(next_value.basis, lerp_amount)
			TYPE_TRANSFORM2D:
				var rotation: float = lerp(value.get_rotation(), next_value.get_rotation(), lerp_amount)
				var origin: Vector2 = lerp(value.origin, next_value.origin, lerp_amount)
				value = Transform2D(rotation, origin)

	# display the value
	match type:
		TYPE_TRANSFORM3D:
			transform3d_visualization.multimesh.set_instance_transform(track["__instance_index"], value.rotated_local(Vector3.RIGHT, PI*-0.5))

func _deserialize_property(type: int, value: Variant) -> Variant:
	match type:
		# primitives
		TYPE_INT:
			return int(value)
		TYPE_FLOAT, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return value
		TYPE_VECTOR2:
			return Vector2(value[0], value[1])
		TYPE_VECTOR2I:
			return Vector2i(value[0], value[1])
		TYPE_VECTOR3:
			return Vector3(value[0], value[1], value[2])
		TYPE_VECTOR3I:
			return Vector3i(value[0], value[1], value[2])
		TYPE_VECTOR4:
			return Vector4(value[0], value[1], value[2], value[3])
		TYPE_VECTOR4I:
			return Vector4i(value[0], value[1], value[2], value[3])
		TYPE_QUATERNION:
			return Quaternion(value[0], value[1], value[2], value[3])
		TYPE_BASIS:
			return Basis(Quaternion(value[0], value[1], value[2], value[3]))
		TYPE_TRANSFORM2D:
			return Transform2D(value[0], Vector2(value[1], value[2]))
		TYPE_TRANSFORM3D:
			return Transform3D(Basis(Quaternion(value[0], value[1], value[2], value[3])), Vector3(value[4], value[5], value[6]))
		_:
			push_error("Unsupported telemetry property type", type)
			return null
