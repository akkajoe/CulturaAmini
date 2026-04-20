extends Camera2D

@export var rumble_enabled: bool = true
@export var rumble_amp_px: float = 4.5    
@export var rumble_freq: float = 11.0       
@export var rumble_smooth: float = 12.0     

var _base_offset := Vector2.ZERO
var _rumble_phase := 0.0
var _rumble_current := Vector2.ZERO

# one-shot shake
var _shake_t := 0.0
var _shake_d := 0.0
var _shake_amp := 0.0
var _shake_freq := 0.0
var _shake_seed := 0.0

func _ready() -> void:
	_base_offset = offset
	randomize()

func set_rumble(on: bool) -> void:
	rumble_enabled = on

func shake_once(duration := 0.25, amplitude_px := 5.0, frequency := 22.0) -> void:
	_shake_t = 0.0
	_shake_d = max(0.01, duration)
	_shake_amp = max(0.0, amplitude_px)
	_shake_freq = max(1.0, frequency)
	_shake_seed = randf() * 1000.0

func _process(delta: float) -> void:
	var rumble := Vector2.ZERO

	if rumble_enabled and rumble_amp_px > 0.0:
		_rumble_phase += delta * rumble_freq
		# smooth pseudo-noise using sin/cos
		var x := sin(_rumble_phase * TAU) * 0.6 + sin(_rumble_phase * TAU * 1.37) * 0.4
		var y := cos(_rumble_phase * TAU) * 0.6 + cos(_rumble_phase * TAU * 1.21) * 0.4
		var target := Vector2(x, y) * rumble_amp_px
		# smooth it so it doesn't jitter
		_rumble_current = _rumble_current.lerp(target, 1.0 - exp(-rumble_smooth * delta))
		rumble = _rumble_current

	var impact := Vector2.ZERO
	if _shake_t < _shake_d:
		_shake_t += delta
		var t := _shake_t / _shake_d
		var decay := (1.0 - t)
		decay *= decay

		var a := (_shake_t * _shake_freq) + _shake_seed
		var ix := sin(a * TAU) + 0.5 * sin(a * TAU * 1.73)
		var iy := cos(a * TAU) + 0.5 * cos(a * TAU * 1.41)
		impact = Vector2(ix, iy) * (_shake_amp * decay)

	offset = _base_offset + rumble + impact
