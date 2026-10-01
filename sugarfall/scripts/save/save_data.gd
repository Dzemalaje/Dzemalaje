class_name SaveData
extends RefCounted
## Best results across runs, stored in user://save.cfg.

const PATH := "user://save.cfg"

var best_score: int = 0
var best_bosses: int = 0
var best_cascade: int = 0
var runs: int = 0


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	best_score = cfg.get_value("best", "score", 0)
	best_bosses = cfg.get_value("best", "bosses", 0)
	best_cascade = cfg.get_value("best", "cascade", 0)
	runs = cfg.get_value("stats", "runs", 0)


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("best", "score", best_score)
	cfg.set_value("best", "bosses", best_bosses)
	cfg.set_value("best", "cascade", best_cascade)
	cfg.set_value("stats", "runs", runs)
	cfg.save(PATH)


## Records a finished run. Returns true if it set a new best score.
func record(run: RunState) -> bool:
	runs += 1
	var new_best := run.score > best_score
	best_score = maxi(best_score, run.score)
	best_bosses = maxi(best_bosses, run.bosses_defeated)
	best_cascade = maxi(best_cascade, run.best_cascade)
	save_data()
	return new_best
