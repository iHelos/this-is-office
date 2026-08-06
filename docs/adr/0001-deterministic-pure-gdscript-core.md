# ADR 0001 — Deterministic, pure-GDScript simulation core

Date: 2026-08-06
Status: Accepted

## Context

The game is a reimagining of *This Is the Police*, whose interest lives in the
tension of a fixed clock under scarcity. For that tension to be fair and for the
balance to be tunable, the player must be able to trust that the same decisions
produce the same outcomes — and we must be able to assert that in tests.

The zpg project in the same workspace solved the same problem by writing the
simulation core in Rust and binding it through GDExtension. That is the most
robust option but adds a build toolchain and a second language.

## Decision

Keep the simulation core in **pure GDScript** as `RefCounted` classes, but treat
it as deterministic and pure exactly as zpg does:

- `core/rng.gd` is a verbatim copy of zpg's splitmix64 + fork RNG, so the stream
  is identical to a known-good implementation.
- The core never touches the SceneTree; `Sim.advance(state, actions, rng)`
  returns a new state.
- All randomness flows through the RNG, forked by name.

GDExtension / Rust stays open as a future option if profiling shows the core
becoming a bottleneck; the pure-GDScript core is shaped so it could be lifted
out with minimal changes.

## Consequences

- No second build toolchain at launch; the project opens and tests run with a
  stock Godot binary.
- Determinism is a testable property: `test_sim.gd` pins "same seed + same
  actions ⇒ same state".
- The price is runtime speed vs. Rust. Acceptable for a 180-day management game
  whose heaviest work is resolving a few dozen tickets per day.
