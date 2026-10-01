class_name Cell
extends RefCounted
## One grid cell. A cell either holds a candy (color >= 0, or a color bomb),
## is empty (waiting for refill), or is occupied by a blocker.

enum Special { NONE, STRIPED_H, STRIPED_V, BOMB, MEGA_BOMB, COLOR_BOMB }
enum Blocker { NONE, STONE, CHOCOLATE, BOSS }

const EMPTY := -1
## Color value of a color bomb: it never matches by color.
const NO_COLOR := -2

var color: int = EMPTY
var special: int = Special.NONE
## Ice layers lock a candy in place: it can't be swapped and doesn't fall.
var ice: int = 0
var blocker: int = Blocker.NONE
var blocker_hp: int = 0
## Enemy countdown bomb attached to this candy (0 = none).
var countdown: int = 0


func has_candy() -> bool:
	return blocker == Blocker.NONE and color != EMPTY


func is_fixed() -> bool:
	return blocker != Blocker.NONE or ice > 0


func can_swap() -> bool:
	return has_candy() and ice == 0


func can_match() -> bool:
	return blocker == Blocker.NONE and color >= 0


func clear_candy() -> void:
	color = EMPTY
	special = Special.NONE
	countdown = 0


func set_blocker(kind: int, hp: int) -> void:
	clear_candy()
	ice = 0
	blocker = kind
	blocker_hp = hp


func remove_blocker() -> void:
	blocker = Blocker.NONE
	blocker_hp = 0
	clear_candy()


func to_dict() -> Dictionary:
	return {
		"color": color,
		"special": special,
		"ice": ice,
		"blocker": blocker,
		"blocker_hp": blocker_hp,
		"countdown": countdown,
	}
