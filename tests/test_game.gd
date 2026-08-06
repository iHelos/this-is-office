extends RefCounted
## Integration checks for the Game autoload bridge.
##
## The unit suites pin the core in isolation; this one wires the autoload to the
## core and asserts the contract the UI depends on: a new game produces a
## playable state with a morning board, and ending the day advances the clock and
## spawns a fresh board. Runs against the real content files, so a content break
## that only shows up at game start fails here too.

const CAMPAIGN_DAYS := 180


func run(t: TestCase) -> void:
	_new_game_initializes_state(t)
	_morning_board_is_non_empty(t)
	_end_day_advances_clock_and_refreshes_board(t)
	_assign_ticket_resolves_in_place(t)


func _new_game_initializes_state(t: TestCase) -> void:
	Game.start_new_game(12345)
	t.ok(Game.state != null, "start_new_game builds a GameState")
	t.eq(Game.current_day(), 1, "a new game starts on day 1")
	t.ok(not Game.state.employees.is_empty(), "the starter roster is loaded")
	t.eq(Game.state.factions.size(), 2, "two factions are loaded")


func _morning_board_is_non_empty(t: TestCase) -> void:
	Game.start_new_game(12345)
	t.ok(not Game.state.tickets.is_empty(), "day 1 spawns a morning ticket board")
	# Day 1 has one scripted ticket plus procedural fillers; all must be open.
	for tk: Ticket in Game.state.tickets:
		t.eq(tk.state, "open", "morning ticket '%s' starts open" % tk.id)


func _end_day_advances_clock_and_refreshes_board(t: TestCase) -> void:
	Game.start_new_game(12345)
	var day_before: int = Game.current_day()
	Game.end_day()
	t.eq(Game.current_day(), day_before + 1, "end_day advances the day")
	t.ok(not Game.state.tickets.is_empty(), "a new morning board spawns after end_day")


func _assign_ticket_resolves_in_place(t: TestCase) -> void:
	# Assigning the whole team to the first ticket should resolve it to clean or
	# fumbled, never leave it open. This exercises the autoload -> Sim path.
	Game.start_new_game(12345)
	var first: Ticket = Game.state.tickets[0]
	var ids: Array = []
	for e: Employee in Game.state.employees:
		ids.append(e.id)
	Game.assign_ticket(first.id, ids)
	t.ne(first.state, "open", "an assigned ticket leaves the open state")
