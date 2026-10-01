class_name Boss
extends RefCounted
## A boss fight on the endless board.
##  ENCASED: sits inside the board as a block wrapped in a shell; only matches
##           touching it and blasts reaching it do damage. Attacks your HP.
##  SPAWNER: floats above the board, takes damage from every cleared candy
##           (3x for its weak color) and keeps dropping obstacles.
##  HYBRID:  encased body that also drops obstacles.

enum Kind { ENCASED, SPAWNER, HYBRID }

const KIND_NAMES := ["Encased", "Spawner", "Hybrid"]
const SHELL_PER_LAYER := 6
## Damage per cleared candy touching an on-board boss, and per blast hit.
const CONTACT_DAMAGE := 2.0
const BLAST_DAMAGE := 3.0

var kind: int = Kind.ENCASED
var index: int = 1
var name: String = ""
var max_hp: int = 10
var hp: int = 10
var max_shell: int = 0
var shell: int = 0
var size: int = 2
var cells: Array = []
var weak_color: int = -1
var attack_interval: int = 4
var attack_damage: int = 5
var attack_timer: int = 4
var spawn_interval: int = 0
var spawn_count: int = 0
var spawn_pool: Array = []
var spawn_strength: int = 1
var spawn_timer: int = 0
var par_moves: int = 15
var enrage_after: int = 24
var moves_in_fight: int = 0


func on_board() -> bool:
	return kind != Kind.SPAWNER


func spawns_obstacles() -> bool:
	return spawn_interval > 0


func is_dead() -> bool:
	return hp <= 0


func is_enraged() -> bool:
	return moves_in_fight >= enrage_after


func shell_layers() -> int:
	return ceili(float(shell) / SHELL_PER_LAYER)


## Picks a block of cells away from the edges and turns them into boss cells.
func place(board: Board) -> bool:
	if not on_board():
		return true
	var options: Array = []
	for y in range(1, board.height - size):
		for x in range(1, board.width - size):
			var ok := true
			for dy in size:
				for dx in size:
					if board.at(Vector2i(x + dx, y + dy)).blocker != Cell.Blocker.NONE:
						ok = false
			if ok:
				options.append(Vector2i(x, y))
	if options.is_empty():
		# Board is crowded: take the center block regardless of what's there.
		options.append(Vector2i((board.width - size) / 2, (board.height - size) / 2))
	var origin: Vector2i = options[board.rng.randi_range(0, options.size() - 1)]
	cells.clear()
	for dy in size:
		for dx in size:
			var p := origin + Vector2i(dx, dy)
			board.at(p).set_blocker(Cell.Blocker.BOSS, 0)
			cells.append(p)
	return true


func remove_from(board: Board) -> void:
	for p in cells:
		if board.at(p).blocker == Cell.Blocker.BOSS:
			board.at(p).remove_blocker()
	cells.clear()


func origin() -> Vector2i:
	return cells[0] if not cells.is_empty() else Vector2i(-1, -1)


## Raw damage this boss takes from one resolved move.
func damage_from(summary: Dictionary, mods: Modifiers) -> float:
	var dmg := 0.0
	if on_board():
		dmg += summary.boss_adjacent * CONTACT_DAMAGE + summary.boss_blast * BLAST_DAMAGE
	else:
		for col in summary.by_color.size():
			dmg += summary.by_color[col] * (3.0 if col == weak_color else 1.0)
		dmg += summary.specials_triggered * 1.0
	dmg += summary.color_cleared * mods.val("spectrum_surge") * 0.5
	return dmg


## Shell absorbs damage first. Returns how much went to each.
func apply_damage(amount: int) -> Dictionary:
	var to_shell := mini(shell, amount)
	shell -= to_shell
	var to_hp := mini(hp, amount - to_shell)
	hp -= to_hp
	return {"shell": to_shell, "hp": to_hp}


## Advances the boss one move. Returns events:
##   {type:"boss_attack", damage}, {type:"spawn", kind, cells}, {type:"weak_color", color}
func end_turn(board: Board, rng: RandomNumberGenerator, countdown_turns: int) -> Array:
	var events: Array = []
	moves_in_fight += 1
	var enraged := is_enraged()
	attack_timer -= 2 if enraged else 1
	if attack_timer <= 0:
		attack_timer = attack_interval
		events.append({"type": "boss_attack", "damage": roundi(attack_damage * (1.5 if enraged else 1.0))})
	if spawns_obstacles():
		spawn_timer -= 1
		if spawn_timer <= 0:
			spawn_timer = spawn_interval
			for i in spawn_count + (1 if enraged else 0):
				var kind_pick: int = spawn_pool[rng.randi_range(0, spawn_pool.size() - 1)]
				var placed := Obstacles.spawn(board, rng, kind_pick, 1, countdown_turns, spawn_strength)
				if not placed.is_empty():
					events.append({"type": "spawn", "kind": kind_pick, "cells": placed})
	if kind == Kind.SPAWNER and moves_in_fight % 5 == 0:
		weak_color = (weak_color + rng.randi_range(1, board.num_colors - 1)) % board.num_colors
		events.append({"type": "weak_color", "color": weak_color})
	return events
