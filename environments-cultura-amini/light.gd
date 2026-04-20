extends Sprite2D

@export var blink_interval: float = 0.5
@export var pulse_speed: float = 4.0
@export var min_alpha: float = 0.5
@export var max_alpha: float = 1.0

@onready var timer: Timer = Timer.new()

var is_on: bool = false
var blinking_active: bool = false

func _ready() -> void:
	add_child(timer)
	timer.wait_time = blink_interval
	timer.one_shot = false
	timer.autostart = false
	timer.timeout.connect(_on_blink)
	
	visible = false
	modulate.a = 0.0
	set_process(false)

func start_blinking() -> void:
	blinking_active = true
	is_on = true
	visible = true
	modulate.a = max_alpha
	timer.start()
	set_process(true)

func stop_blinking() -> void:
	blinking_active = false
	is_on = false
	timer.stop()
	visible = false
	modulate.a = 0.0
	set_process(false)

func _on_blink() -> void:
	is_on = !is_on
	visible = is_on
	
	if is_on:
		modulate.a = max_alpha
	else:
		modulate.a = 0.0

func _process(delta: float) -> void:
	if blinking_active and is_on:
		var t: float = Time.get_ticks_msec() / 1000.0
		var pulse: float = (sin(t * pulse_speed) + 1.0) / 2.0
		modulate.a = lerp(min_alpha, max_alpha, pulse)
