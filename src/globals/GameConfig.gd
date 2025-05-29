extends Node

# Game Configuration - Centralized constants and settings

# === GRID SETTINGS ===
const DEFAULT_GRID_WIDTH: int = 10
const DEFAULT_GRID_HEIGHT: int = 8
const DEFAULT_CELL_SIZE: Vector2 = Vector2(32, 32)

# === ECONOMY SETTINGS ===
const STARTING_MONEY: int = 100
const MIN_ENTITY_PRICE: int = 1
const MAX_ENTITY_PRICE: int = 1000

# === UI SETTINGS ===
const WALLET_FONT_SIZE: int = 24
const BUTTON_DISABLED_ALPHA: float = 0.5
const FLASH_DURATION: float = 0.5

# === VALIDATION RULES ===
const MIN_ENTITY_NAME_LENGTH: int = 3
const MAX_ENTITY_NAME_LENGTH: int = 50
const MIN_GROWTH_TIME: float = 0.1
const MAX_GROWTH_TIME: float = 3600.0  # 1 hour

# === COLORS ===
const UI_COLORS: Dictionary = {
	"money": Color.YELLOW,
	"money_shadow": Color.BLACK,
	"success": Color.GREEN,
	"error": Color.RED,
	"warning": Color.ORANGE,
	"disabled": Color.GRAY,
	"preview_valid": Color(0.0, 1.0, 0.0, 0.5),    # Semi-transparent green for valid placement
	"preview_invalid": Color(1.0, 0.0, 0.0, 0.5),  # Semi-transparent red for invalid placement
	"preview_outline": Color.WHITE,
	"core_garden": Color(0.2, 0.8, 0.2),           # Bright green for core garden
	"core_garden_damaged": Color(0.8, 0.4, 0.2),   # Orange when damaged
	"core_garden_critical": Color(0.9, 0.1, 0.1)   # Red when critical
}
