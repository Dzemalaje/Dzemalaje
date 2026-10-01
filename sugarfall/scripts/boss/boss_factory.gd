class_name BossFactory
extends RefCounted
## Builds the Nth boss of a run. Odd bosses are encased (hybrid from boss 5),
## even bosses are spawners. Every stat scales with the boss index.

const ENCASED_NAMES := ["Licorice Golem", "Gumdrop Titan", "Toffee Colossus"]
const SPAWNER_NAMES := ["Chocolate Witch", "Frost Jester", "Caramel Hydra", "Sour Sorcerer"]
const HP_GROWTH := 1.15
const ATTACK_GROWTH := 1.06
const HYBRID_NAMES := ["Sugar Lich", "Candy Kraken", "Marzipan Behemoth"]


static func kind_for(index: int) -> int:
	if index % 2 == 0:
		return Boss.Kind.SPAWNER
	return Boss.Kind.HYBRID if index >= 5 else Boss.Kind.ENCASED


static func create(index: int, rng: RandomNumberGenerator, num_colors: int) -> Boss:
	var b := Boss.new()
	b.index = index
	b.kind = kind_for(index)
	match b.kind:
		Boss.Kind.ENCASED:
			b.name = _pick_name(ENCASED_NAMES, floori((index - 1) / 2.0))
			b.size = 3 if index >= 7 else 2
			b.max_hp = 8 + 7 * index
			b.max_shell = 3 + 3 * index
			b.attack_interval = 4 if index < 5 else 3
			b.attack_damage = 4 + 2 * index
			b.par_moves = 14
			b.enrage_after = 26
		Boss.Kind.SPAWNER:
			b.name = _pick_name(SPAWNER_NAMES, floori((index - 2) / 2.0))
			b.max_hp = 60 + 25 * index
			b.max_shell = 0
			b.attack_interval = 6
			b.attack_damage = 3 + index
			b.spawn_interval = 3 if index < 8 else 2
			b.spawn_count = 1 + floori(index / 4.0)
			b.spawn_pool = [Obstacles.Kind.ICE, Obstacles.Kind.STONE]
			if index >= 4:
				b.spawn_pool.append_array([Obstacles.Kind.CHOCOLATE, Obstacles.Kind.COUNTDOWN])
			b.weak_color = rng.randi_range(0, num_colors - 1)
			b.par_moves = 16
			b.enrage_after = 26
		Boss.Kind.HYBRID:
			b.name = _pick_name(HYBRID_NAMES, floori((index - 5) / 2.0))
			b.size = 3 if index >= 9 else 2
			b.max_hp = 10 + 7 * index
			b.max_shell = 3 + 3 * index
			b.attack_interval = 5
			b.attack_damage = 4 + 2 * index
			b.spawn_interval = 4
			b.spawn_count = 1 + floori(index / 6.0)
			b.spawn_pool = [Obstacles.Kind.ICE, Obstacles.Kind.STONE, Obstacles.Kind.CHOCOLATE, Obstacles.Kind.COUNTDOWN]
			b.par_moves = 18
			b.enrage_after = 26
	# Player builds snowball, so late bosses scale exponentially.
	var growth := pow(HP_GROWTH, index - 1)
	b.max_hp = roundi(b.max_hp * growth)
	b.max_shell = roundi(b.max_shell * growth)
	b.attack_damage = roundi(b.attack_damage * pow(ATTACK_GROWTH, index - 1))
	b.spawn_strength = 2 if index >= 6 else 1
	b.hp = b.max_hp
	b.shell = b.max_shell
	b.attack_timer = b.attack_interval
	b.spawn_timer = b.spawn_interval
	return b


static func _pick_name(names: Array, tier: int) -> String:
	var base: String = names[tier % names.size()]
	var lap: int = tier / names.size()
	return base if lap == 0 else "%s %s" % [base, ["", "II", "III", "IV", "V"][mini(lap, 4)]]
