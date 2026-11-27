extends Node2D
class_name LawnField

const CELL_SIZE := 16.0
const GRID_W := 64
const GRID_H := 96
const FIELD_SIZE := Vector2(GRID_W * CELL_SIZE, GRID_H * CELL_SIZE) # 1024 x 1536
const BORDER_PAD := 96.0

# State encoding per cell:
# _mowed[idx]: 0 = unmowed, 1 = mowed, 2 = blocked (under obstacle)
# _special[idx]: 0 = normal, 1 = golden special grass (2x), 2 = flower special turf (2x)
var _mowed: PackedByteArray = PackedByteArray()
var _special: PackedByteArray = PackedByteArray()

var total_mowable_cells: int = 0
var mowed_cells: int = 0

var _state_img: Image
var _state_tex: ImageTexture
var _minimap_img: Image
var _minimap_tex: ImageTexture
var _dirty_tex: bool = false
var _dirty_minimap: bool = false
var _tex_upload_accum: float = 0.0
var _minimap_upload_accum: float = 0.0

var _lawn_rect: TextureRect
var _shader_mat: ShaderMaterial

func _ready() -> void:
	z_index = 0
	_init_visuals()
	reset_field()

func _init_visuals() -> void:
	_state_img = Image.create(GRID_W, GRID_H, false, Image.FORMAT_RGBA8)
	_state_tex = ImageTexture.create_from_image(_state_img)

	_minimap_img = Image.create(GRID_W, GRID_H, false, Image.FORMAT_RGBA8)
	_minimap_tex = ImageTexture.create_from_image(_minimap_img)

	_lawn_rect = TextureRect.new()
	_lawn_rect.texture = _state_tex
	_lawn_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lawn_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_lawn_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_lawn_rect.position = Vector2.ZERO
	_lawn_rect.size = FIELD_SIZE
	_lawn_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sh: Shader = load("res://shaders/lawn.gdshader")
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = sh
	_shader_mat.set_shader_parameter("grid_size", Vector2(GRID_W, GRID_H))
	_shader_mat.set_shader_parameter("field_size", FIELD_SIZE)
	_shader_mat.set_shader_parameter("fever_strength", 0.0)
	_lawn_rect.material = _shader_mat
	add_child(_lawn_rect)

func get_play_rect() -> Rect2:
	return Rect2(Vector2.ZERO, FIELD_SIZE)

func get_minimap_texture() -> ImageTexture:
	return _minimap_tex

func set_fever_strength(val: float) -> void:
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("fever_strength", clampf(val, 0.0, 1.0))

func reset_field() -> void:
	var count := GRID_W * GRID_H
	_mowed.resize(count)
	_special.resize(count)
	_mowed.fill(0)
	_special.fill(0)
	total_mowable_cells = count
	mowed_cells = 0
	_rebuild_all_images()
	queue_redraw()

func mark_obstacle_circle(world_pos: Vector2, radius: float) -> void:
	var min_x := maxi(0, int(floor((world_pos.x - radius) / CELL_SIZE)))
	var max_x := mini(GRID_W - 1, int(ceil((world_pos.x + radius) / CELL_SIZE)))
	var min_y := maxi(0, int(floor((world_pos.y - radius) / CELL_SIZE)))
	var max_y := mini(GRID_H - 1, int(ceil((world_pos.y + radius) / CELL_SIZE)))
	var r2 := radius * radius
	for cy in range(min_y, max_y + 1):
		var wy := (float(cy) + 0.5) * CELL_SIZE
		for cx in range(min_x, max_x + 1):
			var wx := (float(cx) + 0.5) * CELL_SIZE
			if Vector2(wx, wy).distance_squared_to(world_pos) <= r2:
				var idx := cy * GRID_W + cx
				if _mowed[idx] != 2:
					if _mowed[idx] == 1:
						mowed_cells -= 1
					_mowed[idx] = 2
					_special[idx] = 0
					total_mowable_cells -= 1
					_write_cell_pixel(cx, cy)
	_dirty_tex = true
	_dirty_minimap = true

func spawn_special_patch(center: Vector2, radius_px: float, is_flower_turf: bool = false) -> int:
	var min_x := maxi(1, int(floor((center.x - radius_px) / CELL_SIZE)))
	var max_x := mini(GRID_W - 2, int(ceil((center.x + radius_px) / CELL_SIZE)))
	var min_y := maxi(1, int(floor((center.y - radius_px) / CELL_SIZE)))
	var max_y := mini(GRID_H - 2, int(ceil((center.y + radius_px) / CELL_SIZE)))
	var r2 := radius_px * radius_px
	var spec_val := 2 if is_flower_turf else 1
	var painted := 0
	for cy in range(min_y, max_y + 1):
		var wy := (float(cy) + 0.5) * CELL_SIZE
		for cx in range(min_x, max_x + 1):
			var wx := (float(cx) + 0.5) * CELL_SIZE
			var d2 := Vector2(wx, wy).distance_squared_to(center)
			# Organic jittered edge
			var jitter := 0.85 + 0.30 * fposmod(sin(float(cx * 17 + cy * 31)) * 43758.5, 1.0)
			if d2 <= r2 * jitter:
				var idx := cy * GRID_W + cx
				if _mowed[idx] == 0:
					_special[idx] = spec_val
					_write_cell_pixel(cx, cy)
					painted += 1
	if painted > 0:
		_dirty_tex = true
		_dirty_minimap = true
	return painted

func find_unmowed_spot(min_edge_pad: float, avoid_points: Array, min_avoid_dist: float) -> Vector2:
	for _attempt in range(50):
		var cx := randi_range(int(min_edge_pad / CELL_SIZE), GRID_W - 1 - int(min_edge_pad / CELL_SIZE))
		var cy := randi_range(int(min_edge_pad / CELL_SIZE), GRID_H - 1 - int(min_edge_pad / CELL_SIZE))
		var idx := cy * GRID_W + cx
		if _mowed[idx] != 0:
			continue
		var pos := Vector2((float(cx) + 0.5) * CELL_SIZE, (float(cy) + 0.5) * CELL_SIZE)
		var ok := true
		for ap in avoid_points:
			if pos.distance_to(ap) < min_avoid_dist:
				ok = false
				break
		if ok:
			return pos
	return Vector2(-1.0, -1.0)

func mow_circle(world_pos: Vector2, radius: float) -> Dictionary:
	var normal_cut := 0
	var special_cut := 0
	var min_x := maxi(0, int(floor((world_pos.x - radius) / CELL_SIZE)))
	var max_x := mini(GRID_W - 1, int(ceil((world_pos.x + radius) / CELL_SIZE)))
	var min_y := maxi(0, int(floor((world_pos.y - radius) / CELL_SIZE)))
	var max_y := mini(GRID_H - 1, int(ceil((world_pos.y + radius) / CELL_SIZE)))
	var r2 := radius * radius

	for cy in range(min_y, max_y + 1):
		var wy := (float(cy) + 0.5) * CELL_SIZE
		for cx in range(min_x, max_x + 1):
			var wx := (float(cx) + 0.5) * CELL_SIZE
			if Vector2(wx, wy).distance_squared_to(world_pos) <= r2:
				var idx := cy * GRID_W + cx
				if _mowed[idx] == 0:
					_mowed[idx] = 1
					mowed_cells += 1
					if _special[idx] > 0:
						special_cut += 1
						_special[idx] = 0
					else:
						normal_cut += 1
					_write_cell_pixel(cx, cy)

	var total_cut := normal_cut + special_cut
	if total_cut > 0:
		_dirty_tex = true
		_dirty_minimap = true
	return {
		"normal": normal_cut,
		"special": special_cut,
		"total": total_cut,
	}

func get_mowed_ratio() -> float:
	if total_mowable_cells <= 0:
		return 0.0
	return clampf(float(mowed_cells) / float(total_mowable_cells), 0.0, 1.0)

func get_mowed_sq_meters() -> float:
	# Each cell represents 0.08 m^2 (~480 m^2 total yard)
	return float(mowed_cells) * 0.08

func count_unmowed_special_cells() -> int:
	var c := 0
	for i in range(_mowed.size()):
		if _mowed[i] == 0 and _special[i] > 0:
			c += 1
	return c

func _process(delta: float) -> void:
	if _dirty_tex:
		_tex_upload_accum += delta
		if _tex_upload_accum >= 0.033:
			_state_tex.update(_state_img)
			_dirty_tex = false
			_tex_upload_accum = 0.0
	if _dirty_minimap:
		_minimap_upload_accum += delta
		if _minimap_upload_accum >= 0.10:
			_minimap_tex.update(_minimap_img)
			_dirty_minimap = false
			_minimap_upload_accum = 0.0

func _rebuild_all_images() -> void:
	for cy in range(GRID_H):
		for cx in range(GRID_W):
			_write_cell_pixel(cx, cy)
	_state_tex.update(_state_img)
	_minimap_tex.update(_minimap_img)
	_dirty_tex = false
	_dirty_minimap = false

func _write_cell_pixel(cx: int, cy: int) -> void:
	var idx := cy * GRID_W + cx
	var m := _mowed[idx]
	var sp := _special[idx]

	var r_val := 1.0 if m == 1 else 0.0
	var g_val := 0.0
	if sp == 1:
		g_val = 0.5
	elif sp == 2:
		g_val = 1.0
	var b_val := 1.0 if m == 2 else 0.0
	_state_img.set_pixel(cx, cy, Color(r_val, g_val, b_val, 1.0))

	# Minimap pixel
	var mc: Color
	if m == 2:
		mc = Color(0.36, 0.30, 0.24, 1.0)
	elif m == 1:
		mc = Color(0.54, 0.82, 0.34, 1.0)
	elif sp == 1:
		mc = Color(1.0, 0.84, 0.16, 1.0)
	elif sp == 2:
		mc = Color(1.0, 0.36, 0.72, 1.0)
	else:
		mc = Color(0.16, 0.45, 0.19, 1.0)
	_minimap_img.set_pixel(cx, cy, mc)

func _draw() -> void:
	# Cozy exterior garden dirt path around the fenced yard
	var outer := Rect2(-BORDER_PAD * 2.2, -BORDER_PAD * 2.2, FIELD_SIZE.x + BORDER_PAD * 4.4, FIELD_SIZE.y + BORDER_PAD * 4.4)
	draw_rect(outer, Color(0.32, 0.48, 0.24))

	var path_rect := Rect2(-26.0, -26.0, FIELD_SIZE.x + 52.0, FIELD_SIZE.y + 52.0)
	draw_rect(path_rect, Color(0.68, 0.58, 0.42))
	draw_rect(Rect2(-12.0, -12.0, FIELD_SIZE.x + 24.0, FIELD_SIZE.y + 24.0), Color(0.56, 0.45, 0.31))
	draw_rect(Rect2(Vector2.ZERO, FIELD_SIZE), Color(0.18, 0.48, 0.19))

	# Wooden garden fence framing the lawn
	var fence_col := Color(0.56, 0.37, 0.20)
	var fence_hi := Color(0.70, 0.50, 0.30)
	var post_col := Color(0.44, 0.27, 0.13)
	var pad := 8.0
	var tl := Vector2(-pad, -pad)
	var tr := Vector2(FIELD_SIZE.x + pad, -pad)
	var br := Vector2(FIELD_SIZE.x + pad, FIELD_SIZE.y + pad)
	var bl := Vector2(-pad, FIELD_SIZE.y + pad)

	# Fence rails
	draw_line(tl, tr, fence_col, 11.0)
	draw_line(tr, br, fence_col, 11.0)
	draw_line(br, bl, fence_col, 11.0)
	draw_line(bl, tl, fence_col, 11.0)

	draw_line(tl, tr, fence_hi, 4.0)
	draw_line(tr, br, fence_hi, 4.0)
	draw_line(br, bl, fence_hi, 4.0)
	draw_line(bl, tl, fence_hi, 4.0)

	# Fence posts along top & bottom
	var step := 64.0
	var x := -pad
	while x <= FIELD_SIZE.x + pad + 1.0:
		_draw_post(Vector2(x, -pad), post_col, fence_hi)
		_draw_post(Vector2(x, FIELD_SIZE.y + pad), post_col, fence_hi)
		x += step
	# Fence posts along left & right
	var y := -pad + step
	while y < FIELD_SIZE.y + pad - 1.0:
		_draw_post(Vector2(-pad, y), post_col, fence_hi)
		_draw_post(Vector2(FIELD_SIZE.x + pad, y), post_col, fence_hi)
		y += step

func _draw_post(p: Vector2, base_col: Color, hi_col: Color) -> void:
	draw_rect(Rect2(p - Vector2(8.0, 8.0), Vector2(16.0, 16.0)), base_col)
	draw_rect(Rect2(p - Vector2(5.5, 5.5), Vector2(9.0, 9.0)), hi_col)
