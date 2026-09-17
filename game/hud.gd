class_name Hud
extends Control

signal levels_requested
## Fired when a targeted card (currently just Promote) is pressed - the
## card isn't played yet, main.gd still needs a piece to target. Untargeted
## cards (Push Back) are played immediately from here instead.
signal card_target_requested(card_type: String)

var controller: GameController
var moves_label: Label
var status_label: Label
var restart_button: Button
var undo_button: Button
var levels_button: Button
var card_buttons: Array[Button] = []
var _outcome: Rules.Outcome = Rules.Outcome.ONGOING


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
	# Second row, beside the move counter: the status line now says
	# something during ordinary play ("Blocked - play a card"), not only at
	# the end of one, and on the top row a level name of any length runs
	# straight into it.
	status_label.position = Vector2(150, 32)
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

	levels_button = Button.new()
	levels_button.text = "Levels"
	levels_button.position = Vector2(360, 74)
	levels_button.pressed.connect(func(): levels_requested.emit())
	add_child(levels_button)

	controller.state_updated.connect(_on_state_updated)
	controller.outcome_updated.connect(_on_outcome_updated)
	_on_state_updated()
	_on_outcome_updated(controller.outcome)


func _on_state_updated() -> void:
	moves_label.text = "Moves: %d / %d" % [controller.state.moves_used, controller.state.move_budget]
	_rebuild_hand()
	_refresh_status()


## Card buttons are rebuilt from scratch on every state change rather than
## diffed - the hand is at most a couple of entries, and state_updated
## already fires on every move/card play, so this stays cheap and avoids
## tracking per-card-type button identity across turns.
func _rebuild_hand() -> void:
	for button in card_buttons:
		button.queue_free()
	card_buttons = []

	var counts: Dictionary = {}
	for card_type in controller.state.player_hand:
		counts[card_type] = counts.get(card_type, 0) + 1

	var i: int = 0
	for card_type in counts:
		var button: Button = Button.new()
		var count: int = counts[card_type]
		button.text = "%s%s" % [_card_label(card_type), (" x%d" % count) if count > 1 else ""]
		button.position = Vector2(16, 64 + i * 34)
		button.disabled = controller.state.card_played_this_turn
		button.pressed.connect(func(): _on_card_pressed(card_type))
		add_child(button)
		card_buttons.append(button)
		i += 1


func _card_label(card_type: String) -> String:
	match card_type:
		Rules.CARD_PROMOTE:
			return "Promote"
		Rules.CARD_PUSH_BACK:
			return "Push Back"
		_:
			return card_type


func _on_card_pressed(card_type: String) -> void:
	if card_type == Rules.CARD_PROMOTE:
		card_target_requested.emit(card_type)
	else:
		controller.try_play_card(card_type)


func _on_outcome_updated(outcome: Rules.Outcome) -> void:
	_outcome = outcome
	_refresh_status()


## Status text for the last known outcome. Driven from both signals, not
## just outcome_updated: playing a card emits only state_updated, and it's
## exactly what clears the blocked prompt below.
func _refresh_status() -> void:
	match _outcome:
		Rules.Outcome.WIN:
			status_label.text = "WIN!"
		Rules.Outcome.LOSS_ELIMINATED:
			status_label.text = "LOSS - all pieces lost"
		Rules.Outcome.LOSS_NO_MOVES:
			status_label.text = "LOSS - out of moves"
		_:
			# Being blocked with a card in hand that would free the piece
			# is no longer a loss, but with no highlighted move to click it
			# reads exactly like one - so say what the way out is. See
			# plans/done/blocked-with-a-card-is-not-a-loss.md.
			status_label.text = "Blocked - play a card" if Rules.player_must_play_card(controller.state) else ""
