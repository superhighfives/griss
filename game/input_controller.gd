class_name InputController
extends Node2D

signal cell_clicked(pos: Vector2i)

var board_view: BoardView


func setup(p_board_view: BoardView) -> void:
	board_view = p_board_view


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			# mouse_event.position is in viewport space; board_view's own
			# coordinates (BOARD_OFFSET etc.) are local to it, and this node
			# isn't a child of BoardRoot - the two only coincide when
			# BoardRoot sits at (0,0). Since main.gd centers BoardRoot
			# within the safe area (nonzero on any device with a notch),
			# convert into board_view's local space explicitly rather than
			# relying on that coincidence.
			cell_clicked.emit(board_view.screen_to_grid(board_view.to_local(mouse_event.position)))
