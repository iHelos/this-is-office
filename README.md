# This Is the Office

A corporate reimagining of **[This Is the Police](https://store.steampowered.com/app/443810/This_Is_the_Police/)** (Weappy Studio, 2016) built in Godot 4.

You are an office manager. The CTO has given you **180 working days** to hit a profit target before a "restructuring" sweeps you out. Dispatch your team to incoming tickets, juggle HR quotas and pressure from above, investigate incidents leaked to rival departments, and decide whose side you are on when the departments go to war.

> **Disclaimer.** This is an original game inspired by the *structure and feel* of This Is the Police. It is not a port, shares no assets with the original, and reinterprets every mechanic through a corporate lens. "This Is the Police" is a trademark of Weappy Studio.

## How the original maps to this game

| This Is the Police | This Is the Office |
|---|---|
| Chief of police Jack Boyd | You, the office manager |
| 180 days to retirement, target $500k | 180 working days to restructuring, profit target |
| Mayor Rogers / city hall | CTO / HR department (budget, quotas, pressure) |
| Patrol officers | Developers / analysts / designers |
| Detectives | Troubleshooters / auditors (work incidents) |
| 911 dispatch | The ticket stream from departments and clients |
| SWAT | Architects / seniors (heavy incidents) |
| The Sand & Varga crime families | Two rival departments |
| Day 12: pick Sand or Varga | Day 12: ally with one of the rival departments |
| Confiscated goods sold to the mafia | Leaked data / IP sold to a competitor |
| Investigation evidence board | Incident board: kompromat, deduction, interrogation |
| Final raid | Final product launch / deal |

## Design pillars

1. **Deterministic core.** The simulation is a pure function of `(seed, state, actions, day)`. The same seed and the same player actions always produce the same world — this is what makes the game testable and lets a playthrough be reproduced byte-for-byte. See [`docs/architecture.md`](docs/architecture.md).
2. **Pressure through scarcity.** There are never enough people for the tickets that arrive. Every assignment is a trade-off against fatigue, loyalty, and the profit clock.
3. **Moral grey.** The clean play is rarely viable. The CTO's quotas are unreasonable; the rival departments offer money for leaks; firing people is sometimes the only lever. The game does not punish you for choosing badly — it makes the consequences visible.

## Running it

Open the project in **Godot 4.x** (developed against 4.6) and press Play.

To run the headless test suite:

```bash
godot --headless --import
godot --headless --path . res://tests/test_runner.tscn
```

Or use the single entry point:

```bash
ci/verify.sh
```

## Repository layout

```
core/       Deterministic simulation kernel (plain GDScript, no scene access)
content/    JSON data: scenario, employees, tickets, incidents, factions
i18n/       ru.csv / en.csv translation tables
scenes/     Godot scenes (UI + isometric office)
autoload/   Game and L10n singletons
ui/         Reusable UI components
tests/      Headless tests + the tiny framework they run on
ci/         Build/verify scripts
docs/       Design doc, architecture, ADRs
```

## Status

The first vertical slice is playable end-to-end. All four MVP systems from the
design doc are in and tested (15206 headless checks across 11 suites):

- **Dispatch** — the ticket board, employee assignment, live clean-chance
  readout, deterministic outcomes (Phase 4).
- **Personnel / HR** — full roster, rest toggles (fatigue recovery), fire
  (Phase 5).
- **Economy** — budget, profit-target progress, side contracts (money now for
  fatigue/loyalty later), day-180 ending (Phase 6).
- **Investigations** — the incident board: troubleshooters gather clues, the
  incident flips to deduction, closing choices trade budget/standing/power
  (Phase 7).
- **Narrative + endings** — the day-12 faction-allegiance prompt, and four
  faction-aware endings on day 180 (Phase 8).

What is still placeholder: the office backdrop is a flat colour (the isometric
office view is scaffolded but not yet drawn), art/audio are absent, and the
scenario beyond the scripted milestones is procedurally filled rather than
authored day-by-day. See `docs/design.md` for what is planned next.
