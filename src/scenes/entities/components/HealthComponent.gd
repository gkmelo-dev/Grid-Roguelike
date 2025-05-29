class_name HealthComponent
extends Node

# Health Component - Handles HP, damage, healing, and regeneration for entities

# Health properties
@export var max_health: int = 50
@export var current_health: int = 50
@export var defense_value: int = 0
@export var regeneration_rate: float = 0.0  # HP per second
@export var regeneration_delay: float = 3.0  # Seconds before regeneration starts

# State tracking
var last_damage_time: float = 0.0
var regeneration_timer: float = 0.0

# Signals
signal health_changed(new_health: int, max_health: int)
signal entity_destroyed()
signal entity_damaged(damage_amount: int)
signal entity_healed(heal_amount: int)

func _init(
	p_max_health: int = 50,
	p_defense_value: int = 0,
	p_regeneration_rate: float = 0.0,
	p_regeneration_delay: float = 3.0
) -> void:
	max_health = p_max_health
	current_health = p_max_health
	defense_value = p_defense_value
	regeneration_rate = p_regeneration_rate
	regeneration_delay = p_regeneration_delay

func _ready() -> void:
	if regeneration_rate > 0:
		set_process(true)

func _process(delta: float) -> void:
	_handle_regeneration(delta)

# Health management
func take_damage(amount: int) -> bool:
	if is_destroyed():
		return false
	
	var old_health: int = current_health
	var actual_damage: int = max(0, amount - defense_value)
	current_health = max(0, current_health - actual_damage)
	last_damage_time = Time.get_unix_time_from_system()
	
	health_changed.emit(current_health, max_health)
	entity_damaged.emit(actual_damage)
	
	if is_destroyed():
		entity_destroyed.emit()
		return false

	return true


func heal(amount: int) -> bool:
	if is_destroyed():
		return false
	
	var old_health: int = current_health
	current_health = min(max_health, current_health + amount)
	
	health_changed.emit(current_health, max_health)
	entity_healed.emit(amount)
	
	return true

func _handle_regeneration(delta: float) -> void:
	if is_destroyed() or regeneration_rate <= 0:
		return
	
	# Only regenerate if enough time has passed since last damage
	var current_time: float = Time.get_unix_time_from_system()
	if current_time - last_damage_time < regeneration_delay:
		return
	
	# Only regenerate if not at full health
	if current_health >= max_health:
		return
	
	regeneration_timer += delta
	if regeneration_timer >= 1.0:  # Regenerate every second
		var regen_amount: int = int(regeneration_rate)
		if regen_amount > 0:
			heal(regen_amount)
		regeneration_timer = 0.0

# State queries
func is_destroyed() -> bool:
	return current_health <= 0

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func get_health_percentage() -> float:
	return float(current_health) / float(max_health)

func get_defense() -> int:
	return defense_value

# Health-based color for visuals
func get_health_color() -> Color:
	var health_percent: float = get_health_percentage()
	if health_percent > 0.6:
		return Color.GREEN
	elif health_percent > 0.25:
		return Color.ORANGE
	else:
		return Color.RED

# Debug information
func get_debug_info() -> Dictionary:
	return {
		"health": "%d/%d" % [current_health, max_health],
		"health_percentage": "%.1f%%" % (get_health_percentage() * 100),
		"defense": defense_value,
		"regeneration_rate": regeneration_rate,
		"is_destroyed": is_destroyed(),
		"regeneration_timer": "%.1fs" % regeneration_timer,
		"last_damage_time": last_damage_time
	} 
