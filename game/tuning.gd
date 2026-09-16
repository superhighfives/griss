class_name Tuning
extends RefCounted

## Board layout and colors - previously scattered as local consts across
## BoardView. Centralized per M4 so presentation tweaks (a color, a size,
## a duration) happen in one place instead of a hunt through the file.

const CELL_SIZE: int = 60
const BOARD_OFFSET: Vector2 = Vector2(120, 60)
const CELL_MARGIN: float = 2.0
const PIECE_MARGIN: float = 8.0
const POWERUP_MARKER_SIZE: float = 24.0

const COLOR_CELL: Color = Color(0.22, 0.22, 0.26)
const COLOR_WALL: Color = Color(0.08, 0.08, 0.09)
const COLOR_GOAL: Color = Color(0.16, 0.34, 0.2)
const COLOR_PLAYER: Color = Color(0.2, 0.45, 0.9)
const COLOR_ENEMY: Color = Color(0.8, 0.2, 0.2)
const COLOR_HIGHLIGHT: Color = Color(1.0, 0.95, 0.3, 0.4)
const COLOR_THREAT: Color = Color(0.9, 0.15, 0.15, 0.35)
const COLOR_POWERUP: Color = Color(1.0, 0.85, 0.2, 0.9)

## Per docs/PLAN.md's M4 scope: "move tweens (~120ms), a subtle highlight
## animation".
const MOVE_TWEEN_DURATION: float = 0.12
const HIGHLIGHT_PULSE_HALF_DURATION: float = 0.35
const HIGHLIGHT_PULSE_MIN_ALPHA: float = 0.25
const HIGHLIGHT_PULSE_MAX_ALPHA: float = 0.55
