extends CanvasLayer

class_name MapCreator

@onready var _canvas: MapCreatorCanvas = %Canvas

@onready var _name_edit: LineEdit = %NameEdit
@onready var _desc_edit: LineEdit = %DescEdit
@onready var _map_w_spin: SpinBox = %MapWidth
@onready var _map_h_spin: SpinBox = %MapHeight
@onready var _zone_spins: Dictionary = {
	"attacker": {"x": %AttackerX, "y": %AttackerY, "w": %AttackerW, "h": %AttackerH},
	"defender": {"x": %DefenderX, "y": %DefenderY, "w": %DefenderW, "h": %DefenderH}
}

@onready var _biome_type: OptionButton = %BiomeType
@onready var _menu_panel: Control = %Scroll
@onready var _biome_layer: OptionButton = %BiomeLayer
@onready var _sand_bag_layer: OptionButton = %SandBagLayer

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

	for side_name in ["attacker", "defender"]:
		for field in ["x", "y", "w", "h"]:
			_zone_spins[side_name][field].value_changed.connect(_update_zone.bind(side_name, field))

	_canvas.data_changed.connect(_on_canvas_data_changed)

	%AddBiome.pressed.connect(_on_add_biome)
	%DeleteBiome.pressed.connect(_on_delete_biome)
	%AddSandBag.pressed.connect(_on_add_sand_bag)
	%DeleteSandBag.pressed.connect(_on_delete_sand_bag)

	_biome_type.clear()
	_biome_type.add_item("Water")
	_biome_type.add_item("Sand")
	_biome_type.add_item("Grass")

	_biome_layer.clear()
	_sand_bag_layer.clear()
	for i in range(1, 7):
		_biome_layer.add_item("Layer " + str(i))
		_sand_bag_layer.add_item("Layer " + str(i))
	_biome_layer.item_selected.connect(_on_biome_layer_changed)
	_sand_bag_layer.item_selected.connect(_on_sand_bag_layer_changed)

	_canvas.selection_changed.connect(_on_selection_changed)

	_layout_menu()
	get_viewport().size_changed.connect(_layout_menu)

	_new_map()


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

	var zones: Dictionary = data.get("deployment_zones", {})
	for side_name in ["attacker", "defender"]:
		var zd: Dictionary = zones.get(side_name, {})
		for field in ["x", "y", "w", "h"]:
			if _zone_spins.has(side_name) and _zone_spins[side_name].has(field):
				_zone_spins[side_name][field].value = zd.get(field, 0)

	_sync_layer_ui()

	_updating_ui = false


func _sync_layer_ui():
	if _updating_ui:
		return
	_updating_ui = true

	var biome_idx := _canvas.get_selected_biome_idx()
	if biome_idx >= 0:
		_biome_layer.select(_canvas.get_selected_biome_layer() - 1)
		_biome_layer.disabled = false
		_sand_bag_layer.disabled = true
	else:
		var sand_bag_idx := _canvas.get_selected_sand_bag_idx()
		if sand_bag_idx >= 0:
			_sand_bag_layer.select(_canvas.get_selected_sand_bag_layer() - 1)
			_sand_bag_layer.disabled = false
			_biome_layer.disabled = true
		else:
			_biome_layer.disabled = true
			_sand_bag_layer.disabled = true

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

func _update_zone(value: float, side: String, field: String):
	if _updating_ui:
		return
	_canvas.update_deployment_zone(side, field, value)

func _on_add_biome() -> void:
	var sel := _biome_type.selected
	if sel < 0:
		return
	var t: String = _biome_type.get_item_text(sel)
	_canvas.add_biome(t.to_lower())

func _on_delete_biome() -> void:
	var idx := _canvas.get_selected_biome_idx()
	if idx >= 0:
		_canvas.delete_biome(idx)

func _on_add_sand_bag() -> void:
	_canvas.add_sand_bag()

func _on_delete_sand_bag() -> void:
	var idx := _canvas.get_selected_sand_bag_idx()
	if idx >= 0:
		_canvas.delete_sand_bag(idx)

func _layout_menu() -> void:
	_menu_panel.anchor_left = 0.75
	_menu_panel.anchor_right = 1.0
	_menu_panel.anchor_top = 0.0
	_menu_panel.anchor_bottom = 1.0
	_menu_panel.offset_left = 0
	_menu_panel.offset_right = 0
	_menu_panel.offset_top = 0
	_menu_panel.offset_bottom = 0

func _on_selection_changed(_drag_idx: int) -> void:
	_sync_layer_ui()

func _on_biome_layer_changed(item_idx: int) -> void:
	if _updating_ui:
		return
	var biome_idx := _canvas.get_selected_biome_idx()
	if biome_idx >= 0:
		_canvas.set_biome_layer(biome_idx, item_idx + 1)

func _on_sand_bag_layer_changed(item_idx: int) -> void:
	if _updating_ui:
		return
	var sand_bag_idx := _canvas.get_selected_sand_bag_idx()
	if sand_bag_idx >= 0:
		_canvas.set_sand_bag_layer(sand_bag_idx, item_idx + 1)
