extends Node

var game_time: float = 0.0
@onready var last_unix_time: float = Time.get_unix_time_from_system()
@onready var unix_time: float = Time.get_unix_time_from_system()
@onready var session: Dictionary = {
	"device": {
		"cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_rendering_device().get_device_name(),
		"os_name": OS.get_name(),
		"os_version": OS.get_version(),
		"os_distro": OS.get_distribution_name(),
		"id": OS.get_unique_id(),
		"memory": OS.get_memory_info(),
		"locale": OS.get_locale(),
		"window_size": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
	},
	"id": _random_string(12),
	"version": ProjectSettings.get_setting("playtest_telemetry/version", "1.0.0"),
	"start": unix_time,
	"nodes": {},
}
@onready var last_paused: bool = get_tree().paused

const FRAME_TIME_INTERVAL: float = 1.0 # seconds
var frame_time_accumulator: float = 0.0 # seconds
var frame_time_timer: float = 0.0 # seconds
var frame_time: float = 0.0 # seconds

class PropertyRef:
	var node_ref: WeakRef
	var name: StringName
	var type: int
	var data: Array
	var last_value: Variant
	var last_changed_unix_time: float
	var time_resolution: float
var property_refs: Array[PropertyRef]

func _ready() -> void:
	if not OS.has_feature("telemetry"):
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	record_properties(self, ["frame_time"])

func record_properties(node: Node, properties: Array[StringName], time_resolution: float = 0.25) -> void:
	if process_mode == Node.PROCESS_MODE_DISABLED:
		return
	for property in node.get_property_list():
		if not properties.has(property["name"]):
			continue
		
		var data: Array = []
		
		var ref: PropertyRef = PropertyRef.new()
		ref.node_ref = weakref(node)
		ref.type = property["type"]
		ref.name = property["name"]
		ref.data = data
		ref.last_changed_unix_time = unix_time
		ref.time_resolution = time_resolution
		property_refs.append(ref)
		
		var nodeTracks: Dictionary = _get_node_tracks(node)
		nodeTracks[ref.name] = {
			"type": ref.type,
			"data": data,
		}

func record_event(node: Node, event: StringName) -> void:
	if process_mode == Node.PROCESS_MODE_DISABLED:
		return
	var nodeTracks: Dictionary = _get_node_tracks(node)
	var track: Dictionary
	if nodeTracks.has("__events"):
		track = nodeTracks["__events"]
	else:
		track = {
			"type": TYPE_STRING_NAME,
			"data": [],
		}
		nodeTracks["__events"] = track
	track["data"].append([game_time, unix_time, _serialize_property(TYPE_STRING_NAME, event)])

func _process(delta: float) -> void:
	last_unix_time = unix_time
	unix_time = Time.get_unix_time_from_system()
	frame_time_accumulator = max(frame_time_accumulator, delta)
	frame_time_timer += delta
	if frame_time_timer > FRAME_TIME_INTERVAL:
		frame_time_timer -= FRAME_TIME_INTERVAL
		frame_time = frame_time_accumulator
		frame_time_accumulator = 0.0
	
	if get_tree().paused:
		if not last_paused:
			record_event(self, "paused")
	else:
		if last_paused:
			record_event(self, "unpaused")
		game_time += delta
	last_paused = get_tree().paused
	
	var i: int = 0
	while i < property_refs.size():
		var ref: PropertyRef = property_refs[i]
		var node: Node = ref.node_ref.get_ref()
		if not node:
			# remove property efficiently
			property_refs[i] = property_refs[property_refs.size()-1]
			property_refs.resize(property_refs.size()-1)
			continue
		i += 1
		var value: Variant = node.get(ref.name)
		var timeDiff: float = unix_time - ref.last_changed_unix_time
		if value == ref.last_value or timeDiff < ref.time_resolution:
			continue
		if timeDiff > ref.time_resolution * 2.0:
			# if a value stays the same for a long time,
			# we don't want to interpolate it to the new value over that whole duration.
			# we want it to stay the same that whole time and then interpolate over one frame.
			# so insert a new data point at the previous frame.
			ref.data.append([game_time - delta, last_unix_time, _serialize_property(ref.type, ref.last_value)])
		ref.data.append([game_time, unix_time, _serialize_property(ref.type, value)])
		ref.last_value = value
		ref.last_changed_unix_time = unix_time

func _serialize_property(type: int, value: Variant) -> Variant:
	match type:
		# primitives
		TYPE_FLOAT, TYPE_INT, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return value
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [value.x, value.y]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return [value.x, value.y, value.z]
		TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_QUATERNION:
			return [value.x, value.y, value.z, value.w]
		TYPE_BASIS:
			var q: Quaternion = value.get_rotation_quaternion()
			return [q.x, q.y, q.z, q.w]
		TYPE_TRANSFORM2D:
			return [value.get_rotation(), value.origin.x, value.origin.y]
		TYPE_TRANSFORM3D:
			var q: Quaternion = value.basis.get_rotation_quaternion()
			return [q.x, q.y, q.z, q.w, value.origin.x, value.origin.y, value.origin.z]
		_:
			push_error("Unsupported telemetry property type", type)
			return null

func _get_node_tracks(node: Node) -> Dictionary:
	var tracks: Dictionary
	if session["nodes"].has(node.get_path()):
		tracks = session["nodes"][node.get_path()]
	else:
		tracks = {}
		session["nodes"][node.get_path()] = tracks
	return tracks

func _notification(what) -> void:
	if process_mode == Node.PROCESS_MODE_DISABLED:
		return
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	
	var modal: PackedScene = load("res://addons/PlaytestTelemetry/Modal.tscn")
	add_child(modal.instantiate())
	
	# user is quitting, end the session
	session["end"] = unix_time
	session["in_game_duration"] = game_time
	
	# upload the session
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	var body: PackedByteArray = JSON.stringify([session], "", true, true).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	var error: Error = http.request_raw(
		ProjectSettings.get_setting("playtest_telemetry/url", "http://localhost:8000/upload"),
		[
			"Content-Type: application/json",
			"Content-Encoding: gzip",
			"Authorization: Bearer %s" % ProjectSettings.get_setting("playtest_telemetry/api_key", "testkey"),
		],
		HTTPClient.METHOD_POST,
		body,
	)
	if error != OK:
		push_error("Error uploading telemetry: %d" % error)
	await http.request_completed
	print("Telemetry uploaded")
	get_tree().quit()

const ascii_letters_and_digits: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
func _random_string(length: int) -> String:
	var result = ""
	for i in range(length):
		result += ascii_letters_and_digits[randi_range(0, ascii_letters_and_digits.length() - 1)]
	return result
