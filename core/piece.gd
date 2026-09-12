class_name Piece
extends RefCounted

var id: int
var kind: PieceKind.Kind
var team: int  # 0 = player, 1 = enemy
var pos: Vector2i
var charges: int


func _init(p_id: int = 0, p_kind: PieceKind.Kind = PieceKind.Kind.PAWN, p_team: int = 0, p_pos: Vector2i = Vector2i.ZERO, p_charges: int = 0) -> void:
	id = p_id
	kind = p_kind
	team = p_team
	pos = p_pos
	charges = p_charges


func duplicate_piece() -> Piece:
	return Piece.new(id, kind, team, pos, charges)
