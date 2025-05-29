class_name Logger
extends Node

# Structured logging system for the game

enum LogLevel {
	DEBUG,
	INFO,
	WARNING,
	ERROR,
	CRITICAL
}

static var _instance: Logger
static var _log_level: LogLevel = LogLevel.INFO

static func get_instance() -> Logger:
	if not _instance:
		_instance = Logger.new()
	return _instance

static func set_log_level(level: LogLevel) -> void:
	_log_level = level

static func debug(message: String, context: String = "") -> void:
	_log(LogLevel.DEBUG, message, context)

static func info(message: String, context: String = "") -> void:
	_log(LogLevel.INFO, message, context)

static func warning(message: String, context: String = "") -> void:
	_log(LogLevel.WARNING, message, context)

static func error(message: String, context: String = "") -> void:
	_log(LogLevel.ERROR, message, context)

static func critical(message: String, context: String = "") -> void:
	_log(LogLevel.CRITICAL, message, context)

static func _log(level: LogLevel, message: String, context: String = "") -> void:
	if level < _log_level:
		return
	
	var timestamp: String = Time.get_datetime_string_from_system()
	var level_str: String = _get_level_string(level)
	var context_str: String = " [%s]" % context if context != "" else ""
	var formatted_message: String = "%s %s%s: %s" % [timestamp, level_str, context_str, message]
	
	print(formatted_message)
	
	# In production, you might want to write to file or send to analytics
	if level >= LogLevel.ERROR:
		push_error(formatted_message)

static func _get_level_string(level: LogLevel) -> String:
	match level:
		LogLevel.DEBUG:
			return "[DEBUG]"
		LogLevel.INFO:
			return "[INFO]"
		LogLevel.WARNING:
			return "[WARN]"
		LogLevel.ERROR:
			return "[ERROR]"
		LogLevel.CRITICAL:
			return "[CRITICAL]"
		_:
			return "[UNKNOWN]"

# Specialized logging methods for common game events
static func log_transaction(success: bool, item: String, amount: int, remaining: int) -> void:
	if success:
		info("Transaction successful: %s ($%d), Remaining: $%d" % [item, amount, remaining], "Economy")
	else:
		warning("Transaction failed: %s ($%d), Had: $%d" % [item, amount, remaining], "Economy")

static func log_entity_action(action: String, entity_name: String, position: Vector2i) -> void:
	info("%s: %s at (%d,%d)" % [action, entity_name, position.x, position.y], "Garden")

static func log_ui_event(event: String, details: String = "") -> void:
	debug("UI Event: %s %s" % [event, details], "UI")

static func log_validation_error(field: String, value: String, expected: String) -> void:
	error("Validation failed: %s='%s', expected: %s" % [field, value, expected], "Validation") 
