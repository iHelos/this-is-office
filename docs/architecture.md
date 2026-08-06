# Architecture — This Is the Office

The project is split into three layers that never reach sideways:

```
content/  (JSON data)  ──┐
                         ├──▶  core/  (deterministic, pure GDScript, no nodes)
                         │           │
autoload/ (singletons) ◀─┘           └──▶  tests/ (headless, no scene)
       │
       └──▶  scenes/ + ui/  (Godot nodes, reads state, emits actions)
```

## §1 Determinism is load-bearing

The simulation is a pure function of `(seed, state, actions, day)`. The same
seed and the same player choices always produce the same world. This is not a
nicety — it is what lets a playthrough be reproduced for debugging and what
lets the test suite assert outcomes without flakiness.

Consequences:

- **All randomness flows through `core/rng.gd`.** No `randf()`, no
  `RandomNumberGenerator`, no `Time.get_ticks` inside the core. The RNG is
  forked by *name* (`rng.fork("dispatch")`) so adding randomness to one system
  never reshuffles another.
- **The core is pure GDScript, no nodes.** `core/*.gd` classes are
  `RefCounted`; they never touch the SceneTree. The UI never mutates state; it
  asks the `Game` autoload to apply an action through the core.
- **State is recomputed, not patched.** `Sim.advance(state, actions, rng)`
  returns a *new* state. The old state is still valid, which is what makes save,
  undo, and deterministic replay cheap.

## §2 The bridge singleton

`autoload/game.gd` is the only place the core and the UI meet. It owns the seed
and the current `state`, exposes observers (`state` property, `state_changed`
signal), and exposes mutators (`end_day`, and later `assign_ticket`,
`fire_employee`, ...). Screens never hold a reference to the core classes
directly — they go through `Game`.

## §3 Conventions

Inherited from the zpg project, where each was learned the hard way:

- **Static typing is mandatory.** `gdscript/warnings/untyped_declaration=1` in
  `project.godot`.
- `class_name` on reusable `RefCounted` classes; *no* `class_name` on the
  autoloads (their identifier comes from the `[autoload]` table).
- Private members and methods use a `_` prefix; constants are `SCREAMING_SNAKE`.
- Comments explain *why* and cite the design-doc section (e.g. `§4`) they serve.
- JSON is imported manually with `FileAccess.get_file_as_string` +
  `JSON.parse_string`, because `.json` is not a Godot resource.
- Tests are `extends RefCounted` with a single `run(t: TestCase)`; the runner is
  a scene, not `--script`, because autoloads do not exist under `--script`.

## §4 Localization

Two languages ship from day one (`ru`, `en`) via Godot CSV translations, so the
seam is exercised by every screen. All user-facing strings pass through
`L10n.t(key)`; the key itself is returned when a translation is missing, so the
gap is visible but the UI never blanks.
