extends Node2D
## The isometric office view — drawn entirely with _draw primitives.
##
## No art assets: the floor is a grid of diamond polygons, desks are small
## parallelograms with a monitor square, and employees are circles coloured by
## department. The view is the visual link to the simulation — it redraws on
## every Game.state_changed, and an employee flagged on_assignment or on_rest
## vanishes from their desk so the player sees the team leave and return.
##
## Isometric projection: for a grid cell (gx, gy) the screen offset from the
## room's origin is ((gx - gy) * TILE_W / 2, (gx + gy) * TILE_H / 2).

const TILE_W := 96.0
const TILE_H := 48.0
const GRID_W := 6        # cells across the room
const GRID_H := 4        # cells deep
const DESK_ROWS := 4     # how many desks per row-group
const DESKS_PER_ROW := 3

# Department colours so a glance reads who sits where.
const COLOR_DEPT := {
	"eng": Color(0.35, 0.62, 0.85),
	"data": Color(0.55, 0.80, 0.45),
	"design": Color(0.85, 0.55, 0.80),
	"ops": Color(0.85, 0.70, 0.40),
	"sales": Color(0.70, 0.55, 0.85),
	"support": Color(0.55, 0.75, 0.75),
}
const COLOR_DEFAULT_DEPT := Color(0.7, 0.7, 0.7)

var _room_origin: Vector2
# Fixed desk grid coordinates, built once. Each entry is a cell (gx, gy) that
# holds a desk; an employee is mapped to a desk by index in state.employees.
var _desk_cells: Array = []
# Cache of (employee_id -> cell) so a returning employee reclaims their seat.
var _seat_map: Dictionary = {}


func _ready() -> void:
	# Centre the room in the 1280x800 viewport, leaving room for the HUD.
	_room_origin = Vector2(640.0, 280.0)
	_build_desks()
	Game.state_changed.connect(queue_redraw)


func _build_desks() -> void:
	# Lay desks out in two row-groups along the depth axis, three desks across.
	# This is deliberately a fixed layout for the prototype; a richer office
	# would read desks from content/office.json.
	var cells := [
		Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
	]
	for c: Vector2i in cells:
		_desk_cells.append(c)


func _to_screen(gx: int, gy: int) -> Vector2:
	return _room_origin + Vector2((gx - gy) * TILE_W * 0.5, (gx + gy) * TILE_H * 0.5)


func _draw() -> void:
	if Game.state == null:
		return
	_draw_floor()
	_draw_desks()
	_draw_employees()


func _draw_floor() -> void:
	for gy: int in GRID_H:
		for gx: int in GRID_W:
			var poly := _diamond(gx, gy)
			# Subtle checker for depth, so the floor reads as a grid.
			var tint := 0.16 if (gx + gy) % 2 == 0 else 0.19
			draw_colored_polygon(poly, Color(tint, tint + 0.02, tint + 0.05, 1.0))


func _draw_desks() -> void:
	for cell: Vector2i in _desk_cells:
		var center: Vector2 = _to_screen(cell.x, cell.y)
		# Desk slab: a small horizontal diamond, wood-coloured.
		var slab := _diamond_around(center, TILE_W * 0.42, TILE_H * 0.42)
		draw_colored_polygon(slab, Color(0.30, 0.22, 0.16, 1.0))
		# Monitor: a small blue square on the back edge of the desk.
		var mon_offset := Vector2(0.0, -TILE_H * 0.12)
		draw_rect(Rect2(center + mon_offset - Vector2(8, 5), Vector2(16, 10)),
			Color(0.30, 0.55, 0.75, 1.0), true)


func _draw_employees() -> void:
	# Assign seats once and keep them stable across redraws.
	var employed: Array = Game.state.employees.filter(func(e: Employee) -> bool: return e.employed)
	for i: int in employed.size():
		var e: Employee = employed[i]
		if i >= _desk_cells.size():
			break
		if not _seat_map.has(e.id):
			_seat_map[e.id] = _desk_cells[i]
		# Away from desk: on a ticket or resting. Skip drawing so the seat reads empty.
		if e.on_assignment or e.on_rest:
			continue
		var cell: Vector2i = _seat_map[e.id]
		var pos: Vector2 = _to_screen(cell.x, cell.y) + Vector2(0.0, -TILE_H * 0.35)
		var dept_color: Color = COLOR_DEPT.get(e.dept, COLOR_DEFAULT_DEPT)
		# Fatigue dims the token; low loyalty gets a red outline.
		var body := dept_color
		body.a = clampf(1.0 - e.fatigue * 0.5, 0.45, 1.0)
		draw_circle(pos, 10.0, body)
		if e.loyalty < -0.2:
			draw_arc(pos, 11.0, 0.0, TAU, 24, Color(0.9, 0.35, 0.35, 0.9), 2.0)
		# Initials under the token so the player can tell people apart.
		var initials := _initials(e.name)
		draw_string(_font(), pos + Vector2(-12, 24), initials, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.85, 0.85, 0.9))


func _diamond(gx: int, gy: int) -> PackedVector2Array:
	var c: Vector2 = _to_screen(gx, gy)
	return _diamond_around(c, TILE_W * 0.5, TILE_H * 0.5)


func _diamond_around(center: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -hh),    # top
		center + Vector2(hw, 0.0),     # right
		center + Vector2(0.0, hh),     # bottom
		center + Vector2(-hw, 0.0),    # left
	])


func _initials(full_name: String) -> String:
	# "Анна Ковалёва" -> "АК". Falls back to the first two letters if no space.
	var parts: PackedStringArray = full_name.split(" ", false)
	if parts.size() >= 2:
		return (parts[0].left(1) + parts[1].left(1)).to_upper()
	return full_name.left(2).to_upper()


func _font() -> Font:
	# Node2D does not have get_theme_default_font() (that's a Control/Window
	# method); use ThemeDB's fallback so _draw has something to render with.
	var f: Font = ThemeDB.fallback_font
	if f != null:
		return f
	# Last-resort: empty font reference keeps _draw from crashing.
	return FontFile.new()
