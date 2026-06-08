extends CanvasLayer

class_name MapCreator

@onready var _canvas: MapCreatorCanvas = %Canvas

@onready var _name_edit: LineEdit = %NameEdit
@onready var _desc_edit: LineEdit = %DescEdit
@onready var _map_w_spin: SpinBox = %MapWidth
@onready var _map_h_spin: SpinBox = %MapHeight
@onready var _ground_picker: ColorPickerButton = %GroundColor

@onready var _zone_spins: Dictionary = {
	"attacker": {"x": %AttackerX, "y": %AttackerY, "w": %AttackerW, "h": %AttackerH},
	"defender": {"x": %DefenderX, "y": %DefenderY, "w": %DefenderW, "h": %DefenderH}
}

var _current_file_path: String = ""
var _is_dirty: bool = false
var _updating_ui: bool = false


func _ready():
	print("MapCreator _ready ran")
	%NewButton.pressed.connect(_on_new_pressed)
	%SaveButton.pressed.connect(_save)
	%SaveAsButton.pressed.connect(_save_as)
	%LoadButton.pressed.connect(_load_dialog)
	%BackButton.pressed.connect(_on_back)

	_name_edit.text_changed.connect(func(t): if _updating_ui: return; _canvas.update_map_property("display_name", t); _mark_dirty())
	_desc_edit.text_changed.connect(func(t): if _updating_ui: return; _canvas.update_map_property("description", t); _mark_dirty())
	_map_w_spin.value_changed.connect(func(_v): _update_map_size())
	_map_h_spin.value_changed.connect(func(_v): _update_map_size())
	_ground_picker.color_changed.connect(func(c): _canvas.update_map_property("ground_color", "#" + c.to_html(false)))

	for side_name in ["attacker", "defender"]:
		for field in ["x", "y", "w", "h"]:
			_zone_spins[side_name][field].value_changed.connect(_update_zone.bind(side_name, field))

	_canvas.data_changed.connect(_on_canvas_data_changed)

	_new_map()

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		var c := get_viewport().gui_get_hovered_control()
		print("hovered: ", c, "  path: ", c.get_path() if c else "NONE")

# ---- Actions ----

func _on_new_pressed() -> void:
	if _is_dirty:
		var dialog := ConfirmationDialog.new()
		dialog.dialog_text = "Discard unsaved changes and create a new map?"
		dialog.ok_button_text = "Discard"
		dialog.exclusive = true
		add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(_new_map)
		dialog.confirmed.connect(dialog.queue_free)
		dialog.canceled.connect(dialog.queue_free)
	else:
		_new_map()

func _new_map():
	_current_file_path = ""
	_canvas.new_map()
	_refresh_all_ui()
	_is_dirty = false

func _mark_dirty():
	_is_dirty = true

static func _sanitize_id(raw: String) -> String:
	var s := raw.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var cleaned := ""
	for ch in s:
		if ch in "abcdefghijklmnopqrstuvwxyz0123456789_":
			cleaned += ch
	return "unnamed" if cleaned.is_empty() else cleaned

func _save():
	if _current_file_path != "":
		var data: Dictionary = _canvas.get_map_data()
		data["id"] = _sanitize_id(_name_edit.text)
		data["display_name"] = _name_edit.text
		data["description"] = _desc_edit.text
		if MapFileManager.save_map(data):
			_current_file_path = MapFileManager.get_user_maps_dir().path_join(data["id"] + ".json")
			_is_dirty = false
		return
	_save_as()

func _save_as():
	var data: Dictionary = _canvas.get_map_data()
	data["id"] = _sanitize_id(_name_edit.text)
	data["display_name"] = _name_edit.text
	data["description"] = _desc_edit.text
	if MapFileManager.save_map(data):
		_current_file_path = MapFileManager.get_user_maps_dir().path_join(data["id"] + ".json")
		_is_dirty = false

func _load_dialog():
	var paths := MapFileManager.get_user_map_paths()
	if paths.is_empty():
		return

	var popup := AcceptDialog.new()
	add_child(popup)
	popup.title = "Load Map"
	popup.dialog_text = "Select a map to load:"

	var vbox := VBoxContainer.new()
	popup.add_child(vbox)

	var list := ItemList.new()
	list.custom_minimum_size = Vector2(300, 200)
	for p in paths:
		var data: Dictionary = MapFileManager.load_map_file(p)
		list.add_item(data.get("display_name", p.get_file()))
	vbox.add_child(list)

	var load_btn := Button.new()
	load_btn.text = "Load Selected"
	vbox.add_child(load_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(popup.hide)
	vbox.add_child(cancel_btn)

	load_btn.pressed.connect(func():
		var idx := list.get_selected_items()
		if idx.size() > 0:
			_load_map_file(paths[idx[0]])
			popup.hide()
	)

	popup.popup_centered()

func _load_map_file(path: String):
	var data: Dictionary = MapFileManager.load_map_file(path)
	if data.is_empty():
		return
	_current_file_path = path
	_canvas.set_map_data(data)
	_refresh_all_ui()
	_is_dirty = false


func _on_back():
	get_parent().pop_menu()


# ---- UI Refresh ----

func _refresh_all_ui():
	_updating_ui = true

	var data: Dictionary = _canvas.get_map_data()
	_name_edit.text = data.get("display_name", "")
	_desc_edit.text = data.get("description", "")
	var ms: Dictionary = data.get("map_size_px", {})
	_map_w_spin.value = ms.get("x", 1600)
	_map_h_spin.value = ms.get("y", 900)
	_ground_picker.color = JsonMapDefinition.parse_color(data.get("ground_color", "#4a7c3f"))

	var zones: Dictionary = data.get("deployment_zones", {})
	for side_name in ["attacker", "defender"]:
		var zd: Dictionary = zones.get(side_name, {})
		for field in ["x", "y", "w", "h"]:
			if _zone_spins.has(side_name) and _zone_spins[side_name].has(field):
				_zone_spins[side_name][field].value = zd.get(field, 0)

	_updating_ui = false


# ---- Canvas Signal Handlers ----

func _on_canvas_data_changed():
	_mark_dirty()
	_refresh_all_ui()


# ---- UI Control Handlers ----

func _update_map_size():
	if _updating_ui:
		return
	var w := _map_w_spin.value
	var h := _map_h_spin.value
	_canvas.update_map_property("map_size_px", {"x": w, "y": h})

func _update_zone(side: String, field: String, value: float):
	if _updating_ui:
		return
	_canvas.update_deployment_zone(side, field, value)
