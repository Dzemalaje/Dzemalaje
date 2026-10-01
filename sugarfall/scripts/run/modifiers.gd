class_name Modifiers
extends RefCounted
## Read-only view of the player's upgrade ranks. Everything that an upgrade
## changes asks this object, so unowned upgrades fall back to values[0].

var ranks: Dictionary = {}


func rank(id: String) -> int:
	return ranks.get(id, 0)


func val(id: String) -> float:
	return UpgradeDB.value(id, rank(id))


func has(id: String) -> bool:
	return rank(id) > 0


func bomb_radius() -> int:
	return int(val("bigger_blast"))


## Sum of ranks on the non-capstone upgrades in a branch.
func branch_progress(branch: int) -> int:
	var n := 0
	for id in UpgradeDB.ids_in_branch(branch):
		if not UpgradeDB.is_capstone(id):
			n += rank(id)
	return n


func is_unlocked(id: String) -> bool:
	if not UpgradeDB.is_capstone(id):
		return true
	return branch_progress(UpgradeDB.get_def(id).branch) >= UpgradeDB.CAPSTONE_REQUIREMENT


func can_offer(id: String) -> bool:
	return is_unlocked(id) and rank(id) < UpgradeDB.max_rank(id)
