extends Resource
class_name JsonMapDefinition

var json_path: String = ""
var _data: Dictionary = {}

func _init(path: String = ""):
	if path:
		load_file(path)

func load_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return false
	_data = json.data
	json_path = path
	return true

func is_valid() -> bool:
	return not _data.is_empty()

func get_data() -> Dictionary:
	return _data

func get_id() -> String:
	return _data.get("id", "unknown")

func get_display_name() -> String:
	return _data.get("display_name", "Unnamed Map")

func get_description() -> String:
	return _data.get("description", "")

func get_map_size() -> Vector2:
	var s: Dictionary = _data.get("map_size_px", {})
	return Vector2(s.get("x", 1600), s.get("y", 900))

func get_ground_color() -> Color:
	return parse_color(_data.get("ground_color", "#8B7355"))

func get_shapes() -> Array:
	return _data.get("shapes", [])

func get_barriers() -> Array:
	return _data.get("barriers", [])

func get_deployment_zones() -> Dictionary:
	return _data.get("deployment_zones", {})

func get_biomes() -> Array:
	return _data.get("biomes", [])

func get_sand_bags() -> Array:
	return _data.get("sand_bags", [])

static func parse_color(hex: String) -> Color:
	var h := hex.trim_prefix("#")
	if h.length() == 6:
		h = "ff" + h
	return Color(h.hex_to_int())

static func zone_fill_color(side_name: String) -> Color:
	return Color(0, 0.5, 1, 0.25) if side_name == "attacker" else Color(1, 0.2, 0.2, 0.25)

static func zone_border_color(side_name: String) -> Color:
	return Color(0, 0.5, 1, 0.5) if side_name == "attacker" else Color(1, 0.2, 0.2, 0.5)

static func biome_color(biome_type: String) -> Color:
	match biome_type:
		"water": return Color(0.29, 0.56, 0.85)
		"sand":  return Color(0.83, 0.65, 0.42)
		"grass": return Color(0.49, 0.78, 0.31)
		_:       return Color(0.49, 0.78, 0.31)

func generate_scene() -> Node2D:
	var root := Node2D.new()
	root.name = get_id()

	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.make_current()
	root.add_child(cam)

	var map_size := get_map_size()
	var ground_color := get_ground_color()

	var ground := Polygon2D.new()
	ground.name = "Ground"
	ground.color = ground_color
	ground.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(map_size.x, 0),
		Vector2(map_size.x, map_size.y),
		Vector2(0, map_size.y)
	])
	root.add_child(ground)

	for s in get_shapes():
		var n := _build_polygon(s, false)
		if n:
			root.add_child(n)

	for b in get_barriers():
		var n := _build_polygon(b, true)
		if n:
			root.add_child(n)

	for b in get_biomes():
		var n := _build_biome_polygon(b)
		if n:
			root.add_child(n)

	for s in get_sand_bags():
		var n := _build_sand_bag_polygon(s)
		if n:
			root.add_child(n)

	var zones := get_deployment_zones()
	for side_name in ["attacker", "defender"]:
		var zd: Dictionary = zones.get(side_name, {})
		if zd.is_empty():
			continue
		var zone := Polygon2D.new()
		zone.name = side_name.capitalize() + "DeployZone"
		var zx: float = zd.get("x", 0)
		var zy: float = zd.get("y", 0)
		var zw: float = zd.get("w", 200)
		var zh: float = zd.get("h", 300)
		zone.polygon = PackedVector2Array([
			Vector2(0, 0), Vector2(zw, 0), Vector2(zw, zh), Vector2(0, zh)
		])
		zone.position = Vector2(zx, zy)
		zone.color = zone_fill_color(side_name)
		zone.z_index = 7
		root.add_child(zone)

	return root

static func _build_polygon(data: Dictionary, is_barrier: bool) -> Polygon2D:
	var t: String = data.get("type", "rect")
	var col: Color = parse_color(data.get("color", "#ffffff"))
	var rot: float = data.get("rotation", 0.0)
	var x: float = data.get("x", 0)
	var y: float = data.get("y", 0)

	var node := Polygon2D.new()
	node.position = Vector2(x, y)
	node.rotation = deg_to_rad(rot)

	if is_barrier:
		node.name = "Barrier"
		col = Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, col.a)
		node.antialiased = true
	else:
		node.name = "Shape"

	node.color = col

	if t == "rect":
		var w: float = data.get("w", 100)
		var h: float = data.get("h", 100)
		node.polygon = PackedVector2Array([
			Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)
		])
	elif t == "circle":
		var radius: float = data.get("radius", 50)
		var sides := 32
		var pts: PackedVector2Array = []
		for i in sides:
			var a := (i as float) / sides * TAU
			pts.append(Vector2(cos(a), sin(a)) * radius)
		node.polygon = pts

	return node

static func _build_biome_polygon(data: Dictionary) -> Polygon2D:
	var node := Polygon2D.new()
	node.name = "Biome"
	var t: String = data.get("type", "grass")
	var x: float = data.get("x", 0)
	var y: float = data.get("y", 0)
	var w: float = data.get("w", 100)
	var h: float = data.get("h", 100)
	node.position = Vector2(x, y)
	node.color = biome_color(t)
	node.z_index = data.get("layer", 1)
	node.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)
	])
	return node

static func _build_sand_bag_polygon(data: Dictionary) -> Polygon2D:
	var node := Polygon2D.new()
	node.name = "SandBag"
	var x: float = data.get("x", 0)
	var y: float = data.get("y", 0)
	var w: float = data.get("w", 40)
	var h: float = data.get("h", 40)
	node.position = Vector2(x, y)
	node.color = Color(0.82, 0.71, 0.55)
	node.z_index = data.get("layer", 1)
	node.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)
	])
	return node
