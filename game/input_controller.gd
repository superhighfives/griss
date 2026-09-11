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
			cell_clicked.emit(board_view.screen_to_grid(mouse_event.position))
