extends Logger

## Collects errors (script errors, engine errors, push_error) while a test suite runs,
## so the suite can fail on them instead of just printing them. Warnings are ignored.
## Usage: var log := ErrorLog.new(); OS.add_logger(log) ... log.errors

var errors := PackedStringArray()
var _mutex := Mutex.new()


func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	errors.append("%s (%s:%d)" % [rationale if not rationale.is_empty() else code, file, line])
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass
