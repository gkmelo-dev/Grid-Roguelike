extends Node2D

# Clean Grid System for entity placement with multi-cell patterns

# Grid configuration
@export var grid_width: int = GameConfig.DEFAULT_GRID_WIDTH
@export var grid_height: int = GameConfig.DEFAULT_GRID_HEIGHT
@export var cell_size: Vector2 = GameConfig.DEFAULT_CELL_SIZE
@export var show_grid_lines: bool = true
@export var grid_line_color: Color = Color(0.5, 0.5, 0.5, 0.8)
@export var grid_line_width: float = 1.0

# Grid state management
var grid_cells: Array[Array] = []  # 2D array tracking which entities occupy each cell
var placed_entities: Array[Entity] = []  # List of all entities on the grid

# Drag and drop state
var dragging_entity: Entity = null
var drag_offset: Vector2 = Vector2.ZERO
var preview_pattern: GridEntityPattern = null
var preview_position: Vector2i = Vector2i(-1, -1)
var preview_valid: bool = false

# Placement mode state
var placement_mode: bool = false
var placement_pattern: GridEntityPattern = null
var placement_entity_scene: PackedScene = null  # Entity scene for preview
var preview_entity: Entity = null  # Visual preview entity with transparency

# Signals
signal entity_placed(entity: Entity, position: Vector2i)
signal entity_moved(entity: Entity, old_position: Vector2i, new_position: Vector2i)
signal entity_removed(entity: Entity, position: Vector2i)
signal cell_clicked(position: Vector2i, entity: Entity)

func _ready() -> void:
	_initialize_grid()
	Logger.info("Grid initialized with size %dx%d" % [grid_width, grid_height], "Grid")

func _initialize_grid() -> void:
	grid_cells.clear()
	placed_entities.clear()
	
	# Initialize 2D array
	for x in range(grid_width):
		grid_cells.append([])
		for y in range(grid_height):
			grid_cells[x].append(null)

func _draw() -> void:
	if show_grid_lines:
		_draw_grid_lines()
	
	if dragging_entity and preview_pattern:
		_draw_preview()
	elif placement_mode and placement_pattern and preview_position != Vector2i(-1, -1) and not preview_entity:
		# Only draw border preview if we don't have an entity preview
		_draw_placement_preview()

func _draw_grid_lines() -> void:
	# Draw vertical lines
	for x in range(grid_width + 1):
		var start = Vector2(x * cell_size.x, 0)
		var end = Vector2(x * cell_size.x, grid_height * cell_size.y)
		draw_line(start, end, grid_line_color, grid_line_width)
	
	# Draw horizontal lines
	for y in range(grid_height + 1):
		var start = Vector2(0, y * cell_size.y)
		var end = Vector2(grid_width * cell_size.x, y * cell_size.y)
		draw_line(start, end, grid_line_color, grid_line_width)

func _draw_preview() -> void:
	if preview_position == Vector2i(-1, -1):
		return
	
	var cells = preview_pattern.get_absolute_cells(preview_position)
	var color = GameConfig.UI_COLORS["preview_valid"] if preview_valid else GameConfig.UI_COLORS["preview_invalid"]
	
	for cell in cells:
		if is_valid_cell(cell):
			var rect = Rect2(
				Vector2(cell.x * cell_size.x, cell.y * cell_size.y) + Vector2(2, 2),
				cell_size - Vector2(4, 4)
			)
			draw_rect(rect, color, true)
			draw_rect(rect, GameConfig.UI_COLORS["preview_outline"], false, 2)

func _draw_placement_preview() -> void:
	if preview_position == Vector2i(-1, -1) or not placement_pattern:
		return
	
	var cells = placement_pattern.get_absolute_cells(preview_position)
	var color = GameConfig.UI_COLORS["preview_valid"] if preview_valid else GameConfig.UI_COLORS["preview_invalid"]
	
	for cell in cells:
		if is_valid_cell(cell):
			var rect = Rect2(
				Vector2(cell.x * cell_size.x, cell.y * cell_size.y) + Vector2(2, 2),
				cell_size - Vector2(4, 4)
			)
			# Draw border instead of filled rect for placement mode
			draw_rect(rect, color, false, 3)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventKey and event.pressed:
		_handle_keyboard_input(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var local_pos = to_local(event.position)
	var cell_pos = world_to_grid(local_pos)
	
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_left_click_pressed(cell_pos, local_pos)
		else:
			_handle_left_click_released(cell_pos)
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_handle_right_click(cell_pos)

func _handle_left_click_pressed(cell_pos: Vector2i, world_pos: Vector2) -> void:
	if not is_valid_cell(cell_pos):
		return
	
	var entity = get_entity_at_cell(cell_pos)
	if entity:
		# Check if entity can be dragged
		if entity.grid_component and entity.grid_component.can_be_dragged():
			# Start dragging existing entity
			_start_dragging_entity(entity, world_pos)
		else:
			# Entity cannot be dragged
			Logger.info("Entity %s cannot be dragged (can_drag = false)" % entity.name, "Grid")
			cell_clicked.emit(cell_pos, entity)
	else:
		# Empty cell clicked
		cell_clicked.emit(cell_pos, null)

func _handle_left_click_released(cell_pos: Vector2i) -> void:
	if dragging_entity:
		_finish_dragging(cell_pos)

func _handle_right_click(_cell_pos: Vector2i) -> void:
	if dragging_entity and dragging_entity.grid_component and dragging_entity.grid_component.get_pattern().can_rotate:
		# Rotate dragging entity using GridComponent's method
		dragging_entity.grid_component.rotate_pattern()
		preview_pattern = dragging_entity.grid_component.get_pattern()
		_update_preview()
		Logger.debug("Rotated entity pattern", "Grid")

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var local_pos = to_local(event.position)
	var cell_pos = world_to_grid(local_pos)
	
	if dragging_entity:
		dragging_entity.global_position = event.position - drag_offset
		if is_valid_cell(cell_pos):
			preview_position = cell_pos
			_update_preview()
	elif placement_mode and placement_pattern:
		# Update placement preview
		if is_valid_cell(cell_pos):
			preview_position = cell_pos
			_update_placement_preview()
			
			# Update preview entity position and visibility
			if preview_entity:
				_update_preview_entity_position(cell_pos)
	
	queue_redraw()

func _start_dragging_entity(entity: Entity, click_pos: Vector2) -> void:
	dragging_entity = entity
	drag_offset = click_pos - entity.position
	
	if entity.grid_component:
		preview_pattern = entity.grid_component.get_pattern()
		# Remove entity from grid temporarily
		_remove_entity_from_grid(entity)
	
	Logger.debug("Started dragging entity: %s" % entity.name, "Grid")

func _finish_dragging(cell_pos: Vector2i) -> void:
	if not dragging_entity:
		return
	
	var old_position = Vector2i(-1, -1)
	if dragging_entity.grid_component:
		old_position = dragging_entity.grid_component.get_grid_position()
	
	if is_valid_cell(cell_pos) and _can_place_entity_at(dragging_entity, cell_pos):
		# Place entity at new position
		_place_entity_at(dragging_entity, cell_pos)
		
		if old_position != Vector2i(-1, -1):
			entity_moved.emit(dragging_entity, old_position, cell_pos)
		else:
			entity_placed.emit(dragging_entity, cell_pos)
		
		Logger.info("Entity placed at (%d, %d)" % [cell_pos.x, cell_pos.y], "Grid")
	else:
		# Invalid placement - return entity to original position or remove
		if old_position != Vector2i(-1, -1) and _can_place_entity_at(dragging_entity, old_position):
			_place_entity_at(dragging_entity, old_position)
			Logger.warning("Invalid placement, returned entity to original position", "Grid")
		else:
			# Remove entity if can't return to original position
			_remove_entity_completely(dragging_entity)
			Logger.warning("Invalid placement and cannot return to original position, removed entity", "Grid")
	
	# Clear dragging state
	dragging_entity = null
	drag_offset = Vector2.ZERO
	preview_pattern = null
	preview_position = Vector2i(-1, -1)
	queue_redraw()

func _update_preview() -> void:
	if preview_pattern and is_valid_cell(preview_position):
		preview_valid = can_place_pattern_at(preview_pattern, preview_position)
	else:
		preview_valid = false

func _update_placement_preview() -> void:
	if placement_pattern and is_valid_cell(preview_position):
		preview_valid = can_place_pattern_at(placement_pattern, preview_position)
	else:
		preview_valid = false

# Entity placement methods
func place_entity(entity: Entity, cell_pos: Vector2i) -> bool:
	if not _can_place_entity_at(entity, cell_pos):
		Logger.warning("Cannot place entity at (%d, %d)" % [cell_pos.x, cell_pos.y], "Grid")
		return false
	
	_place_entity_at(entity, cell_pos)
	entity_placed.emit(entity, cell_pos)
	return true

func _place_entity_at(entity: Entity, cell_pos: Vector2i) -> void:
	if not entity.grid_component:
		Logger.error("Entity has no GridComponent", "Grid")
		return
	
	# Set entity position
	entity.grid_component.set_grid_position(cell_pos)
	entity.position = grid_to_world(cell_pos)
	
	# Mark cells as occupied
	var occupied_cells = entity.grid_component.get_occupied_cells()
	for cell in occupied_cells:
		if is_valid_cell(cell):
			grid_cells[cell.x][cell.y] = entity
	
	# Add to entity list and scene tree if not already there
	if entity not in placed_entities:
		placed_entities.append(entity)
	
	if entity.get_parent() != self:
		add_child(entity)

func _can_place_entity_at(entity: Entity, cell_pos: Vector2i) -> bool:
	if not entity.grid_component:
		return false
	
	var pattern = entity.grid_component.get_pattern()
	return can_place_pattern_at(pattern, cell_pos)

func can_place_pattern_at(pattern: GridEntityPattern, cell_pos: Vector2i) -> bool:
	if not pattern:
		Logger.warning("No pattern provided for placement validation", "Grid")
		return false
	
	var cells = pattern.get_absolute_cells(cell_pos)
	Logger.info("Checking placement at (%d, %d) for pattern %s with cells: %s" % [
		cell_pos.x, cell_pos.y, pattern.pattern_name, str(cells)
	], "Grid")
	
	for cell in cells:
		if not is_valid_cell(cell):
			Logger.info("Cell (%d, %d) is outside grid bounds" % [cell.x, cell.y], "Grid")
			return false
		if is_cell_occupied(cell):
			Logger.info("Cell (%d, %d) is already occupied" % [cell.x, cell.y], "Grid")
			return false
	
	Logger.info("Placement validation passed for position (%d, %d)" % [cell_pos.x, cell_pos.y], "Grid")
	return true

func _remove_entity_from_grid(entity: Entity) -> void:
	if not entity.grid_component:
		return
	
	var occupied_cells = entity.grid_component.get_occupied_cells()
	for cell in occupied_cells:
		if is_valid_cell(cell) and grid_cells[cell.x][cell.y] == entity:
			grid_cells[cell.x][cell.y] = null

func _remove_entity_completely(entity: Entity) -> void:
	_remove_entity_from_grid(entity)
	if entity in placed_entities:
		placed_entities.erase(entity)
	if entity.get_parent() == self:
		remove_child(entity)
	entity_removed.emit(entity, entity.grid_component.get_grid_position() if entity.grid_component else Vector2i.ZERO)

# Grid utility methods
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / cell_size.x),
		int(world_pos.y / cell_size.y)
	)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * cell_size.x, grid_pos.y * cell_size.y)

func is_valid_cell(cell_pos: Vector2i) -> bool:
	return (cell_pos.x >= 0 and cell_pos.x < grid_width and 
			cell_pos.y >= 0 and cell_pos.y < grid_height)

func is_cell_occupied(cell_pos: Vector2i) -> bool:
	if not is_valid_cell(cell_pos):
		return true
	
	var entity_at_cell = grid_cells[cell_pos.x][cell_pos.y]
	
	# Ignore preview entity when checking for occupation
	if entity_at_cell == preview_entity:
		return false
		
	return entity_at_cell != null

func get_entity_at_cell(cell_pos: Vector2i) -> Entity:
	if not is_valid_cell(cell_pos):
		return null
	return grid_cells[cell_pos.x][cell_pos.y]

# Private helper methods (keep for internal use)
func _is_valid_cell(cell_pos: Vector2i) -> bool:
	return is_valid_cell(cell_pos)

func _is_cell_occupied(cell_pos: Vector2i) -> bool:
	return is_cell_occupied(cell_pos)

func _can_place_pattern_at(pattern: GridEntityPattern, cell_pos: Vector2i) -> bool:
	return can_place_pattern_at(pattern, cell_pos)

# Public API
func add_entity_to_grid(entity_scene: PackedScene, pattern: GridEntityPattern = null) -> Entity:
	var entity = entity_scene.instantiate() as Entity
	if not entity:
		Logger.error("Failed to instantiate entity scene", "Grid")
		return null
	
	# Add entity to scene tree temporarily so _ready() gets called and components are found
	add_child(entity)
	
	# Now check if components are available
	Logger.info("Created entity: %s" % entity.name, "Grid")
	Logger.info("Entity has grid_component: %s" % (entity.grid_component != null), "Grid")
	
	# Set pattern if provided, otherwise keep the entity's own pattern
	if pattern and entity.grid_component:
		entity.grid_component.set_pattern(pattern)
		Logger.info("Set pattern %s on entity" % pattern.pattern_name, "Grid")
	elif pattern:
		Logger.warning("Cannot set pattern - entity has no grid_component", "Grid")
	elif entity.grid_component:
		# Entity already has its own pattern from scene configuration
		var existing_pattern = entity.grid_component.get_pattern()
		Logger.info("Entity using its own pattern: %s" % (existing_pattern.pattern_name if existing_pattern else "None"), "Grid")
	
	# Remove from scene tree - it will be re-added when placed
	remove_child(entity)
	
	# Entity will be positioned when placed
	return entity

func set_placement_mode(enabled: bool, pattern: GridEntityPattern = null, entity_scene: PackedScene = null) -> void:
	if enabled and pattern and entity_scene:
		# If already in placement mode, just update the pattern
		if placement_mode and preview_entity:
			update_preview_pattern(pattern)
		else:
			# Enable placement mode and create preview entity
			placement_mode = enabled
			placement_pattern = pattern
			placement_entity_scene = entity_scene
			_create_preview_entity()
	else:
		# Disable placement mode and clean up
		placement_mode = enabled
		placement_pattern = pattern
		placement_entity_scene = entity_scene
		_cleanup_preview_entity()
		preview_position = Vector2i(-1, -1)
		preview_valid = false
	
	queue_redraw()
	Logger.debug("Placement mode: %s" % ("enabled" if enabled else "disabled"), "Grid")

func update_preview_pattern(new_pattern: GridEntityPattern) -> void:
	"""Update the preview entity's pattern without recreating it"""
	if not preview_entity or not new_pattern:
		return
		
	placement_pattern = new_pattern
	
	# Update the preview entity's pattern
	if preview_entity.grid_component:
		preview_entity.grid_component.set_pattern(new_pattern)
		
	# Update position to ensure proper sprite positioning with new pattern
	if preview_position != Vector2i(-1, -1):
		_update_preview_entity_position(preview_position)
		
	Logger.debug("Updated preview pattern to: %s" % new_pattern.pattern_name, "Grid")

func update_preview_rotation(new_rotation: int) -> void:
	"""Update the preview entity's rotation state for proper sprite positioning"""
	if not preview_entity or not preview_entity.grid_component:
		return
		
	preview_entity.grid_component.pattern_rotation = new_rotation
	preview_entity.grid_component._update_sprite_position()
	
	Logger.debug("Updated preview rotation to: %d degrees" % (rotation * 90), "Grid")

func is_in_placement_mode() -> bool:
	return placement_mode

func get_placement_pattern() -> GridEntityPattern:
	return placement_pattern

func get_grid_bounds() -> Rect2i:
	return Rect2i(0, 0, grid_width, grid_height)

func get_all_entities() -> Array[Entity]:
	return placed_entities.duplicate()

func clear_grid() -> void:
	for entity in placed_entities.duplicate():
		_remove_entity_completely(entity)
	_initialize_grid()
	Logger.info("Grid cleared", "Grid")

# Debug information
func get_debug_info() -> Dictionary:
	var occupied_count = 0
	for x in range(grid_width):
		for y in range(grid_height):
			if grid_cells[x][y] != null:
				occupied_count += 1
	
	return {
		"grid_size": "%dx%d" % [grid_width, grid_height],
		"cell_size": str(cell_size),
		"occupied_cells": occupied_count,
		"entities_count": placed_entities.size(),
		"dragging": dragging_entity != null,
		"preview_valid": preview_valid if dragging_entity else false
	}

func _handle_keyboard_input(event: InputEventKey) -> void:
	match event.keycode:
		KEY_R:
			# Rotate dragging entity
			if dragging_entity and dragging_entity.grid_component and dragging_entity.grid_component.get_pattern().can_rotate:
				dragging_entity.grid_component.rotate_pattern()
				preview_pattern = dragging_entity.grid_component.get_pattern()
				_update_preview()
				Logger.debug("Rotated entity with R key", "Grid")

func _update_preview_entity_position(cell_pos: Vector2i) -> void:
	if not preview_entity:
		return
		
	# Position the preview entity at the grid position
	if preview_entity.grid_component:
		preview_entity.grid_component.set_grid_position(cell_pos)
	else:
		preview_entity.position = grid_to_world(cell_pos)
	
	# Update preview entity visibility based on placement validity
	var can_place = can_place_pattern_at(placement_pattern, cell_pos)
	preview_entity.visible = true
	
	# Update preview entity opacity based on validity
	_update_preview_entity_opacity(can_place)

func _update_preview_entity_opacity(can_place: bool) -> void:
	if not preview_entity:
		return
		
	# Set transparency and color based on placement validity
	if can_place:
		# Valid placement: semi-transparent white
		preview_entity.modulate = Color(1, 1, 1, 0.6)
	else:
		# Invalid placement: semi-transparent red
		preview_entity.modulate = Color(1, 0.5, 0.5, 0.6)

func _create_preview_entity() -> void:
	if not placement_pattern or not placement_entity_scene:
		return
	
	# Create a preview entity from the scene
	preview_entity = placement_entity_scene.instantiate() as Entity
	if not preview_entity:
		Logger.error("Failed to create preview entity", "Grid")
		return
	
	# Add to scene tree so components initialize
	add_child(preview_entity)
	
	# Set up the preview entity
	if preview_entity.grid_component:
		preview_entity.grid_component.set_pattern(placement_pattern)
	
	# Make it semi-transparent and initially hidden
	preview_entity.visible = false
	preview_entity.modulate = Color(1, 1, 1, 0.6)
	
	Logger.debug("Created preview entity", "Grid")

func _cleanup_preview_entity() -> void:
	if preview_entity:
		if preview_entity.get_parent() == self:
			remove_child(preview_entity)
		preview_entity.queue_free()
		preview_entity = null
		Logger.debug("Cleaned up preview entity", "Grid")
