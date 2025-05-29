extends Node2D

# Main Game Scene

@onready var grid: Node2D = $Grid
@onready var game_hud: Control = $GameHud

func _ready() -> void:
	_setup_connections()
	Logger.info("Game scene ready", "Game")

func _setup_connections() -> void:
	# Connect GameHud to Grid
	if game_hud and grid:
		game_hud.set_grid_reference(grid)
		Logger.info("GameHud connected to Grid", "Game")
	else:
		Logger.error("Failed to connect GameHud to Grid", "Game") 
