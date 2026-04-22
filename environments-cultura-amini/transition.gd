extends CanvasLayer

# Autoload this as "Transition" in Project > Project Settings > Autoload.
# Points to this script directly (no .tscn needed).

@export var fade_duration: float = 0.35

var _rect: ColorRect
var _tween: Tween


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS

	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func fade_out(duration: float = fade_duration) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_tween = create_tween()
	_tween.tween_property(_rect, "color", Color(0, 0, 0, 1), duration)
	await _tween.finished


func fade_in(duration: float = fade_duration) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_rect, "color", Color(0, 0, 0, 0), duration)
	await _tween.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func instant_black() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_rect.color = Color(0, 0, 0, 1)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
