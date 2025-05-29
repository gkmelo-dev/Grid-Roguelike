extends Control

# Game HUD - Handles entity selection and grid interaction

# UI References
@onready var sunflower_button: Button

# Grid reference (to be set from Game scene)
var grid: Node2D = null

# Entity scenes
var sunflower_scene: PackedScene = preload("res://src/scenes/entities/entities/Sunflower.tscn")

# Selection state
var selected_entity_scene: PackedScene = null
var selected_entity_pattern: GridEntityPattern = null
var selected_pattern_rotation: int = 0  # Track rotation for preview

# Signals
signal entity_selected(entity_scene: PackedScene, pattern: GridEntityPattern)
signal entity_deselected()

func _ready() -> void:
	_setup_ui()
	Logger.info("GameHud ready", "GameHUD")

func _setup_ui() -> void:
	# Create Sunflower selection button
	sunflower_button = Button.new()
	sunflower_button.text = "Sunflower"
	sunflower_button.toggle_mode = true
	sunflower_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sunflower_button.pressed.connect(_on_sunflower_button_pressed)
	
	# Position the button
	sunflower_button.position = Vector2(10, 10)
	sunflower_button.size = Vector2(100, 40)
	
	add_child(sunflower_button)

func set_grid_reference(grid_node: Node2D) -> void:
	grid = grid_node
	if grid:
		# Connect to grid signals
		grid.cell_clicked.connect(_on_grid_cell_clicked)
		Logger.info("GameHud connected to Grid", "GameHUD")

func _on_sunflower_button_pressed() -> void:
	if sunflower_button.button_pressed:
		# Select Sunflower
		selected_entity_scene = sunflower_scene
		selected_pattern_rotation = 0  # Reset rotation when selecting
		
		# Instead of forcing a SINGLE pattern, let the entity use its own configured pattern
		# We'll set this to null and let the Grid system use the entity's own pattern
		selected_entity_pattern = null
		
		# For preview, we need to create a temporary entity to get its pattern
		var temp_entity = sunflower_scene.instantiate() as Entity
		if temp_entity:
			# Add temporarily to get the pattern
			add_child(temp_entity)
			if temp_entity.grid_component and temp_entity.grid_component.get_pattern():
				selected_entity_pattern = temp_entity.grid_component.get_pattern()
				Logger.info("Using Sunflower's configured pattern: %s" % selected_entity_pattern.pattern_name, "GameHUD")
			else:
				# Fallback to SINGLE if no pattern found
				selected_entity_pattern = GridEntityPattern.create_pattern(GridEntityPattern.PatternType.SINGLE)
				Logger.warning("Sunflower has no pattern, using SINGLE as fallback", "GameHUD")
			remove_child(temp_entity)
			temp_entity.queue_free()
		else:
			# Fallback to SINGLE
			selected_entity_pattern = GridEntityPattern.create_pattern(GridEntityPattern.PatternType.SINGLE)
		
		# Tell grid to show preview with current rotation
		if grid:
			grid.set_placement_mode(true, _get_rotated_pattern())
		
		entity_selected.emit(selected_entity_scene, selected_entity_pattern)
		Logger.info("Sunflower selected for placement", "GameHUD")
	else:
		# Deselect
		_deselect_entity()

func _deselect_entity() -> void:
	selected_entity_scene = null
	selected_entity_pattern = null
	
	# Tell grid to hide preview
	if grid:
		grid.set_placement_mode(false, null)
	
	entity_deselected.emit()
	Logger.info("Entity deselected", "GameHUD")

func _on_grid_cell_clicked(position: Vector2i, entity: Entity) -> void:
	if entity:
		# Clicked on existing entity - deselect for now
		sunflower_button.button_pressed = false
		_deselect_entity()
	else:
		# Clicked on empty cell - try to place selected entity
		if selected_entity_scene and grid:
			_place_entity_at(position)

func _place_entity_at(position: Vector2i) -> void:
	if not selected_entity_scene or not grid:
		return
	
	# Debug: Check grid bounds
	Logger.info("Trying to place entity at (%d, %d), Grid bounds: %s" % [position.x, position.y, grid.get_grid_bounds()], "GameHUD")
	
	# Create entity with the rotated pattern
	var entity = grid.add_entity_to_grid(selected_entity_scene, _get_rotated_pattern())
	
	if entity:
		# Apply rotation to the entity if it was rotated
		if entity.grid_component and selected_pattern_rotation > 0:
			# Set the pattern rotation for proper sprite positioning
			entity.grid_component.pattern_rotation = selected_pattern_rotation
			# Update sprite position and rotation
			entity.grid_component._update_sprite_position()
		
		# Debug: Check entity setup
		Logger.info("Created entity: %s" % entity.name, "GameHUD")
		Logger.info("Entity has grid_component: %s" % (entity.grid_component != null), "GameHUD")
		
		if entity.grid_component:
			var pattern = entity.grid_component.get_pattern()
			Logger.info("Entity pattern: %s" % (pattern.pattern_name if pattern else "None"), "GameHUD")
			if pattern:
				Logger.info("Pattern cells: %s" % str(pattern.pattern_cells), "GameHUD")
				Logger.info("Pattern should occupy %d cells" % pattern.pattern_cells.size(), "GameHUD")
			
			# Debug: Check what cells will be occupied at this position
			var occupied_cells = entity.grid_component.get_occupied_cells()
			Logger.info("Entity will occupy cells: %s when placed at (%d, %d)" % [str(occupied_cells), position.x, position.y], "GameHUD")
		
		# Debug: Check placement validation with rotated pattern
		var can_place = grid.can_place_pattern_at(_get_rotated_pattern(), position)
		Logger.info("Can place pattern at (%d, %d): %s" % [position.x, position.y, can_place], "GameHUD")
		
		# Debug: Check if cell is occupied
		Logger.info("Cell (%d, %d) occupied: %s" % [position.x, position.y, grid.is_cell_occupied(position)], "GameHUD")
		
		if grid.place_entity(entity, position):
			Logger.info("Entity placed at (%d, %d)" % [position.x, position.y], "GameHUD")
			
			# Debug: Verify what cells are actually occupied after placement
			if entity.grid_component:
				var final_occupied_cells = entity.grid_component.get_occupied_cells()
				Logger.info("Entity now occupies cells: %s" % str(final_occupied_cells), "GameHUD")
			
			# Keep selection active for placing more entities
		else:
			# Failed to place - remove entity
			entity.queue_free()
			Logger.warning("Cannot place entity at (%d, %d)" % [position.x, position.y], "GameHUD")
	else:
		Logger.error("Failed to create entity", "GameHUD")

# Public API
func deselect_all() -> void:
	sunflower_button.button_pressed = false
	_deselect_entity()

func is_entity_selected() -> bool:
	return selected_entity_scene != null

func get_selected_entity_scene() -> PackedScene:
	return selected_entity_scene

func get_selected_pattern() -> GridEntityPattern:
	return selected_entity_pattern 

func _get_rotated_pattern() -> GridEntityPattern:
	if not selected_entity_pattern:
		return null
	
	var rotated_pattern = selected_entity_pattern
	# Apply rotation the number of times needed
	for i in range(selected_pattern_rotation):
		rotated_pattern = rotated_pattern.rotate_clockwise()
	
	return rotated_pattern

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				if selected_entity_scene and selected_entity_pattern:
					# Rotate the selected pattern before placement
					selected_pattern_rotation = (selected_pattern_rotation + 1) % 4
					Logger.info("Rotated pattern to %d degrees" % (selected_pattern_rotation * 90), "GameHUD")
					
					# Update grid preview
					if grid:
						grid.set_placement_mode(true, _get_rotated_pattern()) 
