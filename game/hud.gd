class_name Hud
extends Control

var controller: GameController
var moves_label: Label
var status_label: Label
var restart_button: Button
var undo_button: Button


func setup(p_controller: GameController, level_name: String) -> void:
	controller = p_controller
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title: Label = Label.new()
	title.text = level_name
	title.position = Vector2(16, 8)
	add_child(title)

	moves_label = Label.new()
	moves_label.position = Vector2(16, 32)
	add_child(moves_label)

	status_label = Label.new()
	status_label.position = Vector2(150, 8)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	add_child(status_label)

	restart_button = Button.new()
	restart_button.text = "Restart"
	restart_button.position = Vector2(360, 6)
	restart_button.pressed.connect(controller.restart)
	add_child(restart_button)

	undo_button = Button.new()
	undo_button.text = "Undo"
	undo_button.position = Vector2(360, 40)
	undo_button.pressed.connect(controller.undo)
	add_child(undo_button)

	controller.state_updated.connect(_on_state_updated)
	controller.outcome_updated.connect(_on_outcome_updated)
	_on_state_updated()
	_on_outcome_updated(controller.outcome)


func _on_state_updated() -> void:
	moves_label.text = "Moves: %d / %d" % [controller.state.moves_used, controller.state.move_budget]


func _on_outcome_updated(outcome: Rules.Outcome) -> void:
	match outcome:
		Rules.Outcome.WIN:
			status_label.text = "WIN!"
		Rules.Outcome.LOSS_THREATENED:
			status_label.text = "LOSS - threatened"
		Rules.Outcome.LOSS_NO_MOVES:
			status_label.text = "LOSS - out of moves"
		_:
			status_label.text = ""
