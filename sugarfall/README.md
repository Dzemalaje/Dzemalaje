# Sugarfall: Infinite

An endless candy match-3 roguelite built in **Godot 4.3** (GDScript, mobile portrait 720x1280).

There are no levels. One board keeps going for as long as you survive:

- **Match** 3+ candies by swiping (or tapping two neighbours). Cascades build a combo multiplier.
- **Specials:** match 4 for a striped candy (clears a row/column), an L or T shape for a wrapped bomb,
  and 5 in a row for a Color Candy (clears a whole color; swap it with any candy).
- **Bosses** arrive after a calm phase (20 moves at first, shorter later):
  - **Encased** bosses sit inside the board behind a caramel cage. Only matches touching them and
    blasts reaching them do damage. They hit your HP every few moves.
  - **Spawner** bosses float above the board, take damage from every clear (3x for their weak color),
    and drop ice, stone, spreading chocolate and countdown bombs.
  - **Hybrid** bosses (boss 5+) do both.
  - Every boss enrages if the fight drags on, and boss HP grows exponentially.
- **Sugar HP** is your life. Boss attacks, exploding countdown bombs and overgrown chocolate drain it.
  At 0 the run is over.
- **Upgrades** come from three places: a pick after each boss, smaller picks at score milestones,
  and a coin shop between bosses. 25 upgrades across 5 branches (Combo Mastery, Bombcraft,
  Chromatic Magic, Momentum, Candy Economy). Each branch's capstone unlocks after 2 ranks in it.

## Running

Open `project.godot` in Godot 4.3 or newer and press Play. Mouse drag works the same as touch.

## Tests

```sh
godot --headless --path sugarfall --import
godot --headless --path sugarfall -s res://tests/test_runner.gd   # unit tests + full-run simulation
godot --headless --path sugarfall -s res://tests/smoke_main.gd    # boots the main scene and plays it
```

The smoke test can also save screenshots of every screen when run with a display:

```sh
xvfb-run godot --path sugarfall --rendering-driver opengl3 --resolution 720x1280 \
  -s res://tests/smoke_main.gd -- --shots=/tmp/shots
```

## Layout

| Path | What it is |
|---|---|
| `scripts/board/` | Pure board logic: cells, match finding, cascades/specials, obstacles |
| `scripts/boss/` | Boss model and the factory that scales bosses by index |
| `scripts/run/` | `RunState` (HP, boss cycle, picks, shop) and upgrade `Modifiers` |
| `scripts/upgrades/` | `UpgradeDB`: every upgrade's values per rank |
| `scripts/view/` | Procedurally drawn views and UI (no image assets needed) |
| `scenes/main.gd` | Game controller tying the run to the views |
| `tests/` | Headless test runner, simulation and smoke test |

Balance numbers live in `scripts/boss/boss_factory.gd`, `scripts/run/run_state.gd` and
`scripts/upgrades/upgrade_db.gd`.
