class_name UpgradeDB
extends RefCounted
## Every upgrade in the game. `values[rank]` is the effect strength at that
## rank (index 0 = not owned), and is the single source of truth used by
## Modifiers, card previews and the skill tree.

enum Branch { COMBO, BOMB, CHROMA, MOMENTUM, ECONOMY }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC }

const BRANCH_NAMES := ["Combo Mastery", "Bombcraft", "Chromatic Magic", "Momentum", "Candy Economy"]
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic"]
## Earlier ranks in a branch needed before its capstone can be offered.
const CAPSTONE_REQUIREMENT := 2

## fmt: "pct" (0.25 -> 25%), "int", "mult" (+0.50x), "onoff", "every" (N moves, 0 = off)
const UPGRADES := [
	# --- Combo Mastery ---
	{"id": "combo_starter", "name": "Combo Starter", "branch": Branch.COMBO, "rarity": Rarity.COMMON,
		"desc": "Each cascade raises the combo multiplier faster.",
		"label": "Combo growth per cascade", "fmt": "mult", "values": [0.5, 0.75, 1.0, 1.25]},
	{"id": "chain_reaction", "name": "Chain Reaction", "branch": Branch.COMBO, "rarity": Rarity.UNCOMMON,
		"desc": "New candies lean toward their neighbours' colors, so cascades keep going.",
		"label": "Refill match bias", "fmt": "pct", "values": [0.0, 0.1, 0.2, 0.3]},
	{"id": "fever_score", "name": "Fever Score", "branch": Branch.COMBO, "rarity": Rarity.UNCOMMON,
		"desc": "Cascade 3 and beyond score extra.",
		"label": "Score on cascade 3+", "fmt": "pct", "values": [0.0, 0.25, 0.5, 0.75]},
	{"id": "combo_keeper", "name": "Combo Keeper", "branch": Branch.COMBO, "rarity": Rarity.RARE,
		"desc": "Keep part of your streak after a move without a cascade.",
		"label": "Streak kept", "fmt": "pct", "values": [0.0, 0.5, 1.0]},
	{"id": "sugar_rush", "name": "Sugar Rush", "branch": Branch.COMBO, "rarity": Rarity.EPIC, "capstone": true,
		"desc": "Moves with 4+ cascades heal you and hit the boss for bonus damage.",
		"label": "Heal on 4+ cascades", "fmt": "int", "values": [0, 4, 8]},

	# --- Bombcraft ---
	{"id": "bigger_blast", "name": "Bigger Blast", "branch": Branch.BOMB, "rarity": Rarity.COMMON,
		"desc": "Bomb candies explode over a wider area.",
		"label": "Bomb radius", "fmt": "int", "values": [1, 2, 3]},
	{"id": "sticky_fuse", "name": "Sticky Fuse", "branch": Branch.BOMB, "rarity": Rarity.COMMON,
		"desc": "Enemy countdown bombs tick slower.",
		"label": "Extra turns on enemy bombs", "fmt": "int", "values": [0, 2, 4, 6]},
	{"id": "double_pop", "name": "Double Pop", "branch": Branch.BOMB, "rarity": Rarity.UNCOMMON,
		"desc": "Explosions may hit obstacles and bosses twice.",
		"label": "Chance blasts hit twice", "fmt": "pct", "values": [0.0, 0.25, 0.5, 0.75]},
	{"id": "crossfire", "name": "Crossfire", "branch": Branch.BOMB, "rarity": Rarity.RARE,
		"desc": "Bombs also clear their whole row and column.",
		"label": "Row + column blast", "fmt": "onoff", "values": [0, 1]},
	{"id": "mega_bomb", "name": "Mega Bomb", "branch": Branch.BOMB, "rarity": Rarity.EPIC, "capstone": true,
		"desc": "Matches of 4+ may create a Mega Bomb: bigger blast plus a cross.",
		"label": "Mega Bomb chance", "fmt": "pct", "values": [0.0, 0.25, 0.5]},

	# --- Chromatic Magic ---
	{"id": "color_spark", "name": "Color Spark", "branch": Branch.CHROMA, "rarity": Rarity.COMMON,
		"desc": "Matches of 4 may create a Color Candy instead of a striped one.",
		"label": "Color Candy chance", "fmt": "pct", "values": [0.0, 0.15, 0.3, 0.45]},
	{"id": "prismatic_link", "name": "Prismatic Link", "branch": Branch.CHROMA, "rarity": Rarity.UNCOMMON,
		"desc": "Color clears also pop random extra candies.",
		"label": "Extra candies per color clear", "fmt": "int", "values": [0, 4, 8, 12]},
	{"id": "rainbow_echo", "name": "Rainbow Echo", "branch": Branch.CHROMA, "rarity": Rarity.RARE,
		"desc": "Clearing one color may also clear a second color.",
		"label": "Second color chance", "fmt": "pct", "values": [0.0, 0.35, 0.7]},
	{"id": "spectrum_surge", "name": "Spectrum Surge", "branch": Branch.CHROMA, "rarity": Rarity.UNCOMMON,
		"desc": "Candies removed by color clears give bonus score and boss damage.",
		"label": "Color clear bonus", "fmt": "pct", "values": [0.0, 0.5, 1.0, 1.5]},
	{"id": "full_spectrum", "name": "Full Spectrum", "branch": Branch.CHROMA, "rarity": Rarity.EPIC, "capstone": true,
		"desc": "Every few moves, every candy of the most common color is cleared.",
		"label": "Auto color clear", "fmt": "every", "values": [0, 12, 8]},

	# --- Momentum ---
	{"id": "extra_breath", "name": "Extra Breath", "branch": Branch.MOMENTUM, "rarity": Rarity.COMMON,
		"desc": "Raise your max Sugar HP and heal the same amount.",
		"label": "Bonus max HP", "fmt": "int", "values": [0, 15, 30, 45]},
	{"id": "efficient_swaps", "name": "Efficient Swaps", "branch": Branch.MOMENTUM, "rarity": Rarity.COMMON,
		"desc": "Failed swaps may not advance boss attacks and bomb timers.",
		"label": "Free failed swap chance", "fmt": "pct", "values": [0.0, 0.3, 0.6, 0.9]},
	{"id": "second_chance", "name": "Second Chance", "branch": Branch.MOMENTUM, "rarity": Rarity.RARE,
		"desc": "Once per boss cycle, survive a lethal hit and recover some HP.",
		"label": "HP restored when saved", "fmt": "int", "values": [0, 15, 35]},
	{"id": "momentum_bank", "name": "Momentum Bank", "branch": Branch.MOMENTUM, "rarity": Rarity.UNCOMMON,
		"desc": "Beat a boss under par to bank coins for every move saved.",
		"label": "Coins per move under par", "fmt": "int", "values": [0, 1, 2, 3]},
	{"id": "last_hurrah", "name": "Last Hurrah", "branch": Branch.MOMENTUM, "rarity": Rarity.EPIC, "capstone": true,
		"desc": "Below 25% HP your score and boss damage surge.",
		"label": "Low-HP power", "fmt": "pct", "values": [0.0, 0.4, 0.8]},

	# --- Candy Economy ---
	{"id": "sweet_interest", "name": "Sweet Interest", "branch": Branch.ECONOMY, "rarity": Rarity.COMMON,
		"desc": "Earn interest on your coins after each boss.",
		"label": "Interest", "fmt": "pct", "values": [0.0, 0.1, 0.2, 0.3]},
	{"id": "lucky_drop", "name": "Lucky Drop", "branch": Branch.ECONOMY, "rarity": Rarity.COMMON,
		"desc": "Moves may drop bonus coins.",
		"label": "Bonus drop chance", "fmt": "pct", "values": [0.0, 0.08, 0.16, 0.24]},
	{"id": "bargain_hunter", "name": "Bargain Hunter", "branch": Branch.ECONOMY, "rarity": Rarity.UNCOMMON,
		"desc": "Shop items cost less.",
		"label": "Shop discount", "fmt": "pct", "values": [0.0, 0.15, 0.3, 0.45]},
	{"id": "golden_match", "name": "Golden Match", "branch": Branch.ECONOMY, "rarity": Rarity.UNCOMMON,
		"desc": "Creating special candies awards extra coins.",
		"label": "Coins per special", "fmt": "int", "values": [0, 1, 2, 3]},
	{"id": "sugar_vault", "name": "Sugar Vault", "branch": Branch.ECONOMY, "rarity": Rarity.EPIC, "capstone": true,
		"desc": "Raise the interest cap and get a coin bonus right away.",
		"label": "Interest cap", "fmt": "int", "values": [5, 15, 30]},
]

static var _by_id: Dictionary = {}


static func get_def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for u in UPGRADES:
			_by_id[u.id] = u
	return _by_id.get(id, {})


static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for u in UPGRADES:
		out.append(u.id)
	return out


static func ids_in_branch(branch: int) -> Array[String]:
	var out: Array[String] = []
	for u in UPGRADES:
		if u.branch == branch:
			out.append(u.id)
	return out


static func max_rank(id: String) -> int:
	return get_def(id).values.size() - 1


static func is_capstone(id: String) -> bool:
	return get_def(id).get("capstone", false)


static func value(id: String, rank: int) -> float:
	var vals: Array = get_def(id).values
	return float(vals[clampi(rank, 0, vals.size() - 1)])


static func format_value(id: String, rank: int) -> String:
	var d := get_def(id)
	var v := value(id, rank)
	match d.fmt:
		"pct":
			return "%d%%" % roundi(v * 100.0)
		"mult":
			return "+%.2fx" % v
		"onoff":
			return "On" if v > 0.0 else "Off"
		"every":
			return "Off" if v <= 0.0 else "every %d moves" % int(v)
		_:
			return str(int(v))


## One-line impact preview, e.g. "Bomb radius: 1 -> 2".
static func preview(id: String, from_rank: int) -> String:
	var d := get_def(id)
	return "%s: %s -> %s" % [d.label, format_value(id, from_rank), format_value(id, from_rank + 1)]
