class_name PieceKind
extends RefCounted

enum Kind { PAWN, KNIGHT, BISHOP, ROOK, QUEEN }

const PROMOTION_TRACK: Array[Kind] = [
	Kind.PAWN, Kind.KNIGHT, Kind.BISHOP, Kind.ROOK, Kind.QUEEN,
]

const KNIGHT_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 2), Vector2i(-1, 2), Vector2i(1, -2), Vector2i(-1, -2),
	Vector2i(2, 1), Vector2i(-2, 1), Vector2i(2, -1), Vector2i(-2, -1),
]

const DIAGONAL_DIRS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

const ORTHOGONAL_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]


static func kind_from_string(s: String) -> Kind:
	match s:
		"PAWN":
			return Kind.PAWN
		"KNIGHT":
			return Kind.KNIGHT
		"BISHOP":
			return Kind.BISHOP
		"ROOK":
			return Kind.ROOK
		"QUEEN":
			return Kind.QUEEN
		_:
			return -1


static func kind_to_string(kind: Kind) -> String:
	match kind:
		Kind.PAWN:
			return "PAWN"
		Kind.KNIGHT:
			return "KNIGHT"
		Kind.BISHOP:
			return "BISHOP"
		Kind.ROOK:
			return "ROOK"
		Kind.QUEEN:
			return "QUEEN"
		_:
			return ""


static func kind_to_letter(kind: Kind) -> String:
	match kind:
		Kind.PAWN:
			return "P"
		Kind.KNIGHT:
			return "N"
		Kind.BISHOP:
			return "B"
		Kind.ROOK:
			return "R"
		Kind.QUEEN:
			return "Q"
		_:
			return "?"


static func is_sliding(kind: Kind) -> bool:
	return kind == Kind.BISHOP or kind == Kind.ROOK or kind == Kind.QUEEN


static func next_in_promotion_track(kind: Kind) -> Kind:
	var idx: int = PROMOTION_TRACK.find(kind)
	if idx < 0 or idx == PROMOTION_TRACK.size() - 1:
		return kind
	return PROMOTION_TRACK[idx + 1]
