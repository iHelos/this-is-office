# Design document — This Is the Office

A corporate reimagining of *This Is the Police*. The original's six systems map
onto a single office; this document pins the mapping, the formulas, and the
balance knobs so the simulation core and the UI agree on one source of truth.

## §1 The frame

You are an office manager. The CTO has decreed a **restructuring in 180 working
days**. To survive it with a severance worth having, you must deliver **$500 000
of profit** before day 180. Every other system is in service of that clock.

## §2 Systems and their corporate analogues

| Original | This Is the Office | Status |
|---|---|---|
| 911 dispatch | Ticket stream from departments & clients | core planned |
| Officers | Employees (dev / analyst / designer) | core planned |
| Detectives | Troubleshooters / auditors | core planned |
| SWAT | Architects / seniors (heavy incidents) | core planned |
| Mayor & city hall | CTO & HR (budget, quotas, pressure) | core planned |
| Sand & Varga families | Two rival departments | core planned |
| Confiscate-to-mafia | Leak data / IP to a competitor | core planned |
| Investigation board | Incident board: kompromat, deduction | core planned |
| Final raid | Final product launch / deal | core planned |

## §3 Employees

Each employee has:

- `xp` (int, 0..1500) — professionalism. Grows only on clean resolutions.
- `fatigue` (float, 0..1) — accumulates per assignment, recovered on rest days.
- `loyalty` (float, -1..+1) — how disposed toward the player. Low loyalty:
  refusal, sabotage of heavy incidents, resignation.
- `dept` (String) — which department they belong to.
- `traits` (Array) — flags that nudge outcomes (e.g. `meticulous`, `burned_out`).

## §4 Resolving a ticket

The probability a ticket resolves cleanly is a logistic of the team's effective
skill against the ticket's severity:

```
effective_skill = sum(employee.xp * (1 - 0.5*fatigue) * (0.5 + 0.5*(loyalty+1)))
                     for employee in assigned
odds            = effective_skill / (effective_skill + severity * SEVERITY_SCALE)
clean_chance    = clamp(odds, FLOOR, CEIL)
```

Knobs (`SEVERITY_SCALE`, `FLOOR`, `CEIL`) live in `content/balance.json` so
tuning never edits code. A clean resolution pays the reward and grants `+10` xp
to primary assignees, `+5` to backups. A fumble loses budget (penalty), raises
fatigue, and can cost an employee.

## §5 The day

A day has three phases:

1. **Morning** — newspaper / CTO memo (narrative), assign troubleshooters to
   open incidents.
2. **Dispatch** — tickets arrive on the board with timers; the player assigns
   employees in real time.
3. **Evening** — resolutions land, salaries accrue, the day rolls over.

## §6 The campaign

180 days, scripted at the milestones that give the original its shape:

- **Day 1** — first morning, the CTO's edict.
- **Day 4** — first major incident (the first "investigation").
- **Day 8** — mandatory performance review (random answers have consequences).
- **Day 12** — pick a side: rival department A or B.
- **Day 13** — the departments go to war.
- **Day 15** — HR diversity quota.
- **~Day 170** — the final launch / deal.
- **Day 180** — restructuring; ending determined by profit, faction, loyalty.

Days without a scripted beat are filled procedurally from `content/tickets.json`
and `content/incidents.json`, deterministically from the seed.
