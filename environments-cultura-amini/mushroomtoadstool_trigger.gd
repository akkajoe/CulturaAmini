extends Area2D

@onready var _speech_box: Control = get_node_or_null("../../SpeechCanvasLayer/SpeechBox")

func _ready() -> void:
	push_warning("speech_box: ", _speech_box)
	push_warning("CHECKKK")
	if _speech_box:
		_speech_box.hide()
	body_entered.connect(_on_player_entered)
	body_exited.connect(_on_player_exited)

func _on_player_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if _speech_box:
			_speech_box.show()

func _on_player_exited(body: Node) -> void:
	if body.is_in_group("player"):
		if _speech_box:
			_speech_box.hide()
