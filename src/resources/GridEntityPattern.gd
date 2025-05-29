class_name GridEntityPattern
extends Resource

# GridEntityPattern defines the shape and rotation capabilities of grid entities

# Pattern definition - array of Vector2i representing relative cell positions
@export var pattern_cells: Array[Vector2i] = []
@export var can_rotate: bool = true
@export var pattern_name: String = ""

# Predefined pattern types for easy creation
enum PatternType {
	SINGLE,      # 1x1 - single cell
	SQUARE_2X2,  # 2x2 square
	LINE_H3,     # 3x1 horizontal line
	LINE_V3,     # 1x3 vertical line
	T_SHAPE,     # T-shaped pattern
	L_SHAPE,     # L-shaped pattern
	PLUS_SHAPE   # Plus/cross shape
}

func _init(p_pattern_name: String = "", p_pattern_cells: Array[Vector2i] = [], p_can_rotate: bool = true) -> void:
	pattern_name = p_pattern_name
	pattern_cells = p_pattern_cells.duplicate()
	can_rotate = p_can_rotate

# Factory method to create predefined patterns
static func create_pattern(type: PatternType) -> GridEntityPattern:
	var pattern: GridEntityPattern = GridEntityPattern.new()
	
	match type:
		PatternType.SINGLE:
			pattern.pattern_name = "Single"
			pattern.pattern_cells = [Vector2i(0, 0)]
			pattern.can_rotate = false
		
		PatternType.SQUARE_2X2:
			pattern.pattern_name = "Square 2x2"
			pattern.pattern_cells = [
				Vector2i(0, 0), Vector2i(1, 0),
				Vector2i(0, 1), Vector2i(1, 1)
			]
			pattern.can_rotate = false  # Square looks the same when rotated
		
		PatternType.LINE_H3:
			pattern.pattern_name = "Line 3x1"
			pattern.pattern_cells = [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)
			]
			pattern.can_rotate = true
		
		PatternType.LINE_V3:
			pattern.pattern_name = "Line 1x3"
			pattern.pattern_cells = [
				Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)
			]
			pattern.can_rotate = true
		
		PatternType.T_SHAPE:
			pattern.pattern_name = "T-Shape"
			pattern.pattern_cells = [
				Vector2i(1, 0),
				Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)
			]
			pattern.can_rotate = true
		
		PatternType.L_SHAPE:
			pattern.pattern_name = "L-Shape"
			pattern.pattern_cells = [
				Vector2i(0, 0),
				Vector2i(0, 1), Vector2i(1, 1)
			]
			pattern.can_rotate = true
		
		PatternType.PLUS_SHAPE:
			pattern.pattern_name = "Plus"
			pattern.pattern_cells = [
				Vector2i(1, 0),
				Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
				Vector2i(1, 2)
			]
			pattern.can_rotate = false  # Plus looks the same when rotated
	
	return pattern

# Rotate the pattern 90 degrees clockwise
func rotate_clockwise() -> GridEntityPattern:
	if not can_rotate:
		return self
	
	var rotated_pattern: GridEntityPattern = GridEntityPattern.new(pattern_name + " (Rotated)", [], can_rotate)
	
	for cell: Vector2i in pattern_cells:
		# Rotation matrix for 90 degrees clockwise: (x, y) -> (y, -x)
		var rotated_cell: Vector2i = Vector2i(cell.y, -cell.x)
		rotated_pattern.pattern_cells.append(rotated_cell)
	
	# Normalize the pattern to start from (0,0)
	rotated_pattern._normalize_pattern()
	
	return rotated_pattern

# Normalize pattern so the minimum x and y coordinates are 0
func _normalize_pattern() -> void:
	if pattern_cells.is_empty():
		return
	
	var min_x: int = pattern_cells[0].x
	var min_y: int = pattern_cells[0].y
	
	# Find minimum coordinates
	for cell: Vector2i in pattern_cells:
		min_x = min(min_x, cell.x)
		min_y = min(min_y, cell.y)
	
	# Offset all cells to make minimum coordinates (0,0)
	for i: int in range(pattern_cells.size()):
		pattern_cells[i] = Vector2i(pattern_cells[i].x - min_x, pattern_cells[i].y - min_y)

# Get pattern cells relative to a base position
func get_absolute_cells(base_position: Vector2i) -> Array[Vector2i]:
	var absolute_cells: Array[Vector2i] = []
	for cell: Vector2i in pattern_cells:
		absolute_cells.append(base_position + cell)
	return absolute_cells

# Get pattern cells centered on a position (for cursor-centered placement)
func get_centered_cells(center_position: Vector2i) -> Array[Vector2i]:
	var center_offset: Vector2i = get_pattern_center()
	var base_position: Vector2i = center_position - center_offset
	return get_absolute_cells(base_position)

# Get the center point of the pattern
func get_pattern_center() -> Vector2i:
	if pattern_cells.is_empty():
		return Vector2i(0, 0)
	
	var bounding_box: Rect2i = get_bounding_box()
	return Vector2i(int(bounding_box.position.x + bounding_box.size.x / 2.0), int(bounding_box.position.y + bounding_box.size.y / 2.0))

# Get the base position needed to center the pattern on a given position
func get_base_position_for_center(center_position: Vector2i) -> Vector2i:
	var center_offset: Vector2i = get_pattern_center()
	return center_position - center_offset

# Get the bounding box of the pattern
func get_bounding_box() -> Rect2i:
	if pattern_cells.is_empty():
		return Rect2i(0, 0, 1, 1)
	
	var min_x: int = pattern_cells[0].x
	var max_x: int = pattern_cells[0].x
	var min_y: int = pattern_cells[0].y
	var max_y: int = pattern_cells[0].y
	
	for cell: Vector2i in pattern_cells:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_y = min(min_y, cell.y)
		max_y = max(max_y, cell.y)
	
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

# Validation
func is_valid() -> bool:
	return not pattern_cells.is_empty() and pattern_name != ""

func get_debug_info() -> String:
	return "GridEntityPattern{name=%s, cells=%d, can_rotate=%s, cells=%s}" % [
		pattern_name, pattern_cells.size(), can_rotate, str(pattern_cells)
	] 