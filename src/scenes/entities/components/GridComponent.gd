class_name GridComponent
extends Node

# Grid Component - Handles grid placement, positioning, and occupied cells for grid-based entities

# Grid properties
@export var grid_position: Vector2i = Vector2i.ZERO
@export var cell_size: Vector2 = GameConfig.DEFAULT_CELL_SIZE

# Pattern support for complex shapes
@export var entity_pattern: GridEntityPattern  # For L-shapes, T-shapes, etc.
@export var use_pattern: bool = false  # If true, use pattern instead of entity_size

# References
var parent_entity: Node2D  # The entity this component belongs to

# Signals
signal position_changed(old_position: Vector2i, new_position: Vector2i)
signal size_changed(old_size: Vector2i, new_size: Vector2i)

func _ready() -> void:
	# Get reference to parent entity
	parent_entity = get_parent() as Node2D
	if not parent_entity:
		Logger.error("GridComponent must be a child of a Node2D", "GridComponent")
	
	# Ensure we have a pattern (default to single cell if none)
	if not entity_pattern:
		entity_pattern = GridEntityPattern.create_pattern(GridEntityPattern.PatternType.SINGLE)
		use_pattern = true
		Logger.debug("GridComponent: No pattern set, defaulting to SINGLE", "GridComponent")
	
	Logger.debug("GridComponent ready for entity: %s" % parent_entity.name, "GridComponent")

# Position management
func get_grid_position() -> Vector2i:
	return grid_position

func set_grid_position(new_position: Vector2i) -> void:
	var old_position: Vector2i = grid_position
	grid_position = new_position
	
	# Update parent entity's pixel position
	_update_pixel_position()
	
	position_changed.emit(old_position, new_position)
	Logger.debug("Grid position changed: %s -> %s" % [old_position, new_position], "GridComponent")

func get_pixel_position() -> Vector2:
	return Vector2(grid_position.x * cell_size.x, grid_position.y * cell_size.y)

func _update_pixel_position() -> void:
	if parent_entity:
		parent_entity.position = get_pixel_position()

# Size management - derived from pattern
func get_entity_size() -> Vector2i:
	if entity_pattern:
		return entity_pattern.get_bounding_box().size
	else:
		return Vector2i(1, 1)

func get_pixel_size() -> Vector2:
	var size: Vector2i = get_entity_size()
	return Vector2(size.x * cell_size.x, size.y * cell_size.y)

# Grid cell calculations - uses pattern
func get_occupied_cells() -> Array[Vector2i]:
	if entity_pattern:
		return entity_pattern.get_absolute_cells(grid_position)
	else:
		# Fallback for missing pattern
		return [grid_position]

func get_center_cell() -> Vector2i:
	if entity_pattern:
		var pattern_center: Vector2i = entity_pattern.get_pattern_center()
		return grid_position + pattern_center
	else:
		return grid_position

func get_bounds() -> Rect2i:
	if entity_pattern:
		var pattern_bounds: Rect2i = entity_pattern.get_bounding_box()
		return Rect2i(grid_position + pattern_bounds.position, pattern_bounds.size)
	else:
		return Rect2i(grid_position, Vector2i(1, 1))

# Grid placement validation
func is_valid_grid_position(pos: Vector2i, grid_width: int, grid_height: int) -> bool:
	if not entity_pattern:
		return pos.x >= 0 and pos.y >= 0 and pos.x < grid_width and pos.y < grid_height
	
	# Check if all pattern cells fit within grid bounds
	var test_cells: Array[Vector2i] = entity_pattern.get_absolute_cells(pos)
	for cell: Vector2i in test_cells:
		if cell.x < 0 or cell.y < 0 or cell.x >= grid_width or cell.y >= grid_height:
			return false
	return true

func would_overlap_with(other_component: GridComponent) -> bool:
	if not other_component:
		return false
	
	var our_cells: Array[Vector2i] = get_occupied_cells()
	var other_cells: Array[Vector2i] = other_component.get_occupied_cells()
	
	# Check if any cells overlap
	for our_cell: Vector2i in our_cells:
		for other_cell: Vector2i in other_cells:
			if our_cell == other_cell:
				return true
	return false

func contains_grid_cell(cell: Vector2i) -> bool:
	var occupied_cells: Array[Vector2i] = get_occupied_cells()
	return cell in occupied_cells

# Grid positioning utilities
func move_by_offset(offset: Vector2i) -> void:
	set_grid_position(grid_position + offset)

func snap_to_grid(pixel_position: Vector2) -> Vector2i:
	return Vector2i(
		int(pixel_position.x / cell_size.x),
		int(pixel_position.y / cell_size.y)
	)

func get_grid_distance_to(other_position: Vector2i) -> float:
	return grid_position.distance_to(other_position)

func get_manhattan_distance_to(other_position: Vector2i) -> int:
	var diff: Vector2i = (grid_position - other_position).abs()
	return diff.x + diff.y

# Neighbor detection
func get_adjacent_cells() -> Array[Vector2i]:
	var adjacent: Array[Vector2i] = []
	var directions: Array[Vector2i] = [
		Vector2i(0, -1),  # North
		Vector2i(1, 0),   # East
		Vector2i(0, 1),   # South
		Vector2i(-1, 0)   # West
	]
	
	for direction: Vector2i in directions:
		adjacent.append(grid_position + direction)
	
	return adjacent

func get_surrounding_cells(radius: int = 1) -> Array[Vector2i]:
	var surrounding: Array[Vector2i] = []
	
	for x: int in range(-radius, radius + 1):
		for y: int in range(-radius, radius + 1):
			if x == 0 and y == 0:
				continue  # Skip center cell
			surrounding.append(grid_position + Vector2i(x, y))
	
	return surrounding

# Configuration
func set_cell_size(new_cell_size: Vector2) -> void:
	cell_size = new_cell_size
	_update_pixel_position()
	Logger.debug("Cell size updated to: %s" % cell_size, "GridComponent")

# Pattern management
func set_pattern(pattern: GridEntityPattern) -> void:
	var old_size: Vector2i = get_entity_size()
	entity_pattern = pattern
	use_pattern = pattern != null
	var new_size: Vector2i = get_entity_size()
	
	if old_size != new_size:
		size_changed.emit(old_size, new_size)
	
	Logger.debug("Pattern set: %s" % pattern.pattern_name if pattern else "None", "GridComponent")

func get_pattern() -> GridEntityPattern:
	return entity_pattern

func is_using_pattern() -> bool:
	return use_pattern and entity_pattern != null

# Debug information
func get_debug_info() -> Dictionary:
	return {
		"grid_position": grid_position,
		"entity_size": get_entity_size(),
		"pixel_position": get_pixel_position(),
		"pixel_size": get_pixel_size(),
		"cell_size": cell_size,
		"occupied_cells": get_occupied_cells(),
		"center_cell": get_center_cell(),
		"bounds": get_bounds(),
		"pattern_name": entity_pattern.pattern_name if entity_pattern else "None",
		"use_pattern": use_pattern
	} 
