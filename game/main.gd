extends Node2D

const DESIGN_SIZE: Vector2 = Vector2(480, 800)

const LEVELS: Array[Dictionary] = [
	{"path": "res://levels/01_first_steps.json", "label": "1. First Steps"},
	{"path": "res://levels/02_under_threat.json", "label": "2. Under Threat"},
	{"path": "res://levels/03_powerup_intro.json", "label": "3. Powerup Intro"},
	{"path": "res://levels/04_point_of_no_return.json", "label": "4. Point of No Return"},
	{"path": "res://levels/05_the_gauntlet.json", "label": "5. The Gauntlet"},
	{"path": "res://levels/06_the_sacrifice.json", "label": "6. The Sacrifice"},
	{"path": "res://levels/07_the_shove.json", "label": "7. The Shove"},
	{"path": "res://levels/edge_case_boxed_in.json", "label": "Bonus: Boxed In"},
]

var controller: GameController
var board_view: BoardView
var input_controller: InputController
var hud: Hud
var selected_piece_id: int = -1
var _pending_card_type: String = ""
var _level_select_buttons: Array[Button] = []


func _ready() -> void:
	_setup_sound()
	_show_level_select()
	_center_in_safe_area()


## Main owns the sound node and hands it to SoundHooks once, here. It is
## built in code rather than added to Main.tscn for the same reason as
## everything else in this scene (docs/PLAN.md section 9), and it is wired
## explicitly rather than autoloaded because that section rules autoloads
## out. It lives for the life of the app, so _teardown_level() leaves it be.
func _setup_sound() -> void:
	var sfx: Sfx = Sfx.new()
	add_child(sfx)
	SoundHooks.attach(sfx)


func _show_level_select() -> void:
	for i in range(LEVELS.size()):
		var entry: Dictionary = LEVELS[i]
		var button: Button = Button.new()
		button.text = entry["label"]
		button.position = Vector2(140, 200 + i * 40)
		button.size = Vector2(200, 32)
		var path: String = entry["path"]
		button.pressed.connect(func(): _on_level_selected(path))
		$UI.add_child(button)
		_level_select_buttons.append(button)


func _clear_level_select() -> void:
	for button in _level_select_buttons:
		button.queue_free()
	_level_select_buttons = []


func _on_level_selected(path: String) -> void:
	_clear_level_select()
	_load_level(path)


func _return_to_level_select() -> void:
	_teardown_level()
	_show_level_select()


func _teardown_level() -> void:
	if board_view != null:
		board_view.queue_free()
		board_view = null
	if input_controller != null:
		input_controller.queue_free()
		input_controller = null
	if hud != null:
		hud.queue_free()
		hud = null
	controller = null
	selected_piece_id = -1
	_pending_card_type = ""


func _load_level(path: String) -> void:
	var level: Level = LevelLoader.load_from_file(path)
	if level == null:
		push_error("Failed to load level %s: bad field '%s'" % [path, LevelLoader.last_error])
		return

	_teardown_level()

	controller = GameController.new()
	controller.load_level(level)

	board_view = BoardView.new()
	$BoardRoot.add_child(board_view)
	board_view.setup(controller)

	input_controller = InputController.new()
	input_controller.setup(board_view)
	add_child(input_controller)
	input_controller.cell_clicked.connect(_on_cell_clicked)

	hud = Hud.new()
	$UI.add_child(hud)
	hud.setup(controller, level.level_name)
	hud.levels_requested.connect(_return_to_level_select)
	hud.card_target_requested.connect(_on_card_target_requested)

	controller.state_updated.connect(board_view.refresh)
	controller.outcome_updated.connect(_on_outcome_updated)


# window/stretch/aspect is "expand", which fills the whole screen (no
# letterbox bars) but reveals more canvas than the 480x800 design size on
# any device whose aspect ratio doesn't exactly match, anchored at the
# top-left by default. On an iPhone with a notch/Dynamic Island, that
# leaves the design canvas's origin - where the HUD and top board row both
# sit - directly under the safe-area cutout, clipped. Centering everything
# in the safe area (not just the full screen) fixes both: the content
# moves clear of the notch, and any extra revealed space is split evenly
# top/bottom instead of dumped entirely below.
func _center_in_safe_area() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return

	# get_display_safe_area() is reported in absolute screen coordinates,
	# not window-relative - only meaningful to compare against window_size
	# when the window genuinely occupies the whole screen (always true on
	# iOS; only sometimes true testing windowed on desktop, where comparing
	# the two would produce a nonsense ratio). Fall back to plain centering
	# with zero insets otherwise.
	var top_inset: float = 0.0
	var bottom_inset: float = 0.0
	if window_size == DisplayServer.screen_get_size():
		var safe_area: Rect2i = DisplayServer.get_display_safe_area()
		top_inset = (float(safe_area.position.y) / window_size.y) * viewport_size.y
		bottom_inset = (float(window_size.y - (safe_area.position.y + safe_area.size.y)) / window_size.y) * viewport_size.y

	var usable_height: float = viewport_size.y - top_inset - bottom_inset
	var offset_y: float = top_inset + (usable_height - DESIGN_SIZE.y) / 2.0

	$BoardRoot.position.y = offset_y
	$UI.offset.y = offset_y


func _on_card_target_requested(card_type: String) -> void:
	_pending_card_type = card_type
	selected_piece_id = -1
	board_view.clear_highlights()


func _on_cell_clicked(pos: Vector2i) -> void:
	if controller.outcome != Rules.Outcome.ONGOING:
		return

	var clicked_player: Piece = _player_piece_at(pos)

	if _pending_card_type != "":
		if clicked_player != null:
			controller.try_play_card(_pending_card_type, clicked_player.id)
		_pending_card_type = ""
		return

	if selected_piece_id == -1:
		if clicked_player != null:
			selected_piece_id = clicked_player.id
			board_view.show_highlights(controller.get_legal_moves(selected_piece_id))
		return

	var legal: Array[Vector2i] = controller.get_legal_moves(selected_piece_id)
	if legal.has(pos):
		controller.try_move(selected_piece_id, pos)
		selected_piece_id = -1
	elif clicked_player != null:
		selected_piece_id = clicked_player.id
		board_view.show_highlights(controller.get_legal_moves(selected_piece_id))
	else:
		selected_piece_id = -1
		board_view.clear_highlights()


func _player_piece_at(pos: Vector2i) -> Piece:
	for player in controller.state.get_player_pieces():
		if player.pos == pos:
			return player
	return null


func _on_outcome_updated(outcome: Rules.Outcome) -> void:
	if outcome != Rules.Outcome.ONGOING:
		selected_piece_id = -1
		_pending_card_type = ""
		board_view.clear_highlights()
