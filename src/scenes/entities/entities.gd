class_name Entity
extends Node2D

enum EntityType {
	PLANT,
	DECORATION,
	BUILDING,
	UTILITY,
	SPECIAL
}

# Component references (to be assigned by child classes)
@export var entity_type: EntityType
@onready var health_component: HealthComponent
@onready var sprite_component: Sprite2D
@onready var grid_component: GridComponent
var movement_component: Node  # MovementComponent - for free movement (monsters, projectiles) - null for grid entities

# Base signals that all entities can emit
signal entity_initialized(entity: Entity)
signal entity_destroyed(entity: Entity)

func _ready() -> void:
	# Setup base entity functionality
	assert(entity_type != null, "Entity type not set")
	_setup_entity()
	Logger.debug("Entity ready: %s" % name, "Entity")

func _setup_entity() -> void:
	# Find and setup common components
	# Child classes should override this to setup their specific components
	_find_components()

func _find_components() -> void:
	# Try to find grid component
	if not grid_component:
		grid_component = get_node("GridComponent") if has_node("GridComponent") else null
	
	if grid_component:
		Logger.debug("GridComponent found", "Entity")
	else:
		Logger.warning("GridComponent not found for entity %s" % name, "Entity")
	
	# Try to find health component  
	if not health_component:
		health_component = get_node("HealthComponent") if has_node("HealthComponent") else null
	
	if health_component:
		Logger.debug("HealthComponent found", "Entity")
	
	# Try to find sprite component
	if not sprite_component:
		sprite_component = get_node("Sprite2D") if has_node("Sprite2D") else null
	
	if sprite_component:
		Logger.debug("Sprite2D found", "Entity")

# Base initialization - should be called by all entities
func initialize_entity() -> void:
	Logger.debug("Entity initialized: %s" % name, "Entity")
	entity_initialized.emit(self)

# Grid management delegation (if GridComponent exists)
func get_grid_position() -> Vector2i:
	if grid_component:
		return grid_component.get_grid_position()
	else:
		return Vector2i.ZERO

func get_entity_size() -> Vector2i:
	if grid_component:
		return grid_component.get_entity_size()
	else:
		return Vector2i(1, 1)

func get_occupied_cells() -> Array[Vector2i]:
	if grid_component:
		return grid_component.get_occupied_cells()
	else:
		return []

func set_grid_position(new_position: Vector2i) -> void:
	if grid_component:
		grid_component.set_grid_position(new_position)

# Health management delegation (if HealthComponent exists)
func take_damage(amount: int) -> bool:
	if health_component:
		return health_component.take_damage(amount)
	else:
		return false

func heal(amount: int) -> bool:
	if health_component:
		return health_component.heal(amount)
	else:
		return false

func is_destroyed() -> bool:
	if health_component:
		return health_component.is_destroyed()
	else:
		return false

func get_health() -> int:
	if health_component:
		return health_component.get_health()
	else:
		return 0

func get_max_health() -> int:
	if health_component:
		return health_component.get_max_health()
	else:
		return 0

func get_health_percentage() -> float:
	if health_component:
		return health_component.get_health_percentage()
	else:
		return 0.0

# Visual management
func get_entity_color() -> Color:
	# Base implementation - can be overridden by child classes
	if health_component:
		return health_component.get_health_color()
	else:
		return Color.WHITE

# State queries
func has_health_component() -> bool:
	return health_component != null

func has_sprite_component() -> bool:
	return sprite_component != null

func has_grid_component() -> bool:
	return grid_component != null

func get_sprite_component() -> Sprite2D:
	return sprite_component

# Debug information
func get_debug_info() -> Dictionary:
	var base_info: Dictionary = {
		"entity_type": get_script().get_global_name() if get_script() else "Entity",
		"has_health_component": has_health_component(),
		"has_sprite_component": has_sprite_component(),
		"has_grid_component": has_grid_component()
	}
	
	# Add component info if available
	if health_component:
		base_info["health"] = health_component.get_debug_info()
	
	if grid_component:
		base_info["grid"] = grid_component.get_debug_info()
	
	return base_info

# Virtual methods for child classes to override
func _on_entity_initialized() -> void:
	# Override in child classes for custom initialization logic
	pass

func _on_entity_destroyed() -> void:
	# Override in child classes for custom destruction logic
	entity_destroyed.emit(self)
	Logger.info("Entity destroyed: %s" % name, "Entity") 
