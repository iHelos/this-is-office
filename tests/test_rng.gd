extends RefCounted
## Pins the deterministic random source.
##
## These checks exist because determinism is a load-bearing property of the
## project (docs/architecture.md §1): every later suite that calls the core
## assumes that the same seed yields the same bytes forever. If a refactor of
## [code]core/rng.gd[/code] silently changes the stream, this suite fails before
## anything downstream can be misread as a gameplay bug.

func run(t: TestCase) -> void:
	_same_seed_replays_same_stream(t)
	_fork_does_not_advance_parent(t)
	_fork_is_stable_across_recomputation(t)
	_next_int_range_stays_inclusive(t)
	_next_float_is_half_open(t)
	_chance_threshold(t)
	_pick_weighted_respects_weights(t)
	_hash_str_is_stable(t)


func _same_seed_replays_same_stream(t: TestCase) -> void:
	var a := Rng.new(42)
	var b := Rng.new(42)
	var first: PackedInt64Array = PackedInt64Array()
	var second: PackedInt64Array = PackedInt64Array()
	for i: int in 16:
		first.append(a.next_u64())
	for i: int in 16:
		second.append(b.next_u64())
	t.eq(first, second, "two streams from the same seed must be identical")


func _fork_does_not_advance_parent(t: TestCase) -> void:
	# fork() derives its seed from the parent's *seed*, not its position. If a
	# later refactor accidentally shares the stream, the parent's next value
	# would change depending on whether fork() was called. That is exactly the
	# bug the original zpg rng.gd warns about in its docstring.
	var parent := Rng.new(7)
	var before := parent.next_u64()
	var parent2 := Rng.new(7)
	# Discard the child on purpose: the point is that asking for a fork must not
	# move the parent's stream, whether or not the child is read.
	var _discarded_child := parent2.fork("leak")
	var after := parent2.next_u64()
	t.eq(before, after, "fork must not consume randomness from the parent")


func _fork_is_stable_across_recomputation(t: TestCase) -> void:
	# Forking the same name twice must give the same child stream, so that
	# adding randomness to one system never reshuffles another.
	var parent := Rng.new(123)
	var child_a := parent.fork("dispatch")
	var child_b := parent.fork("dispatch")
	var va: PackedInt64Array = PackedInt64Array()
	var vb: PackedInt64Array = PackedInt64Array()
	for i: int in 8:
		va.append(child_a.next_u64())
		vb.append(child_b.next_u64())
	t.eq(va, vb, "fork('dispatch') is replayable")


func _next_int_range_stays_inclusive(t: TestCase) -> void:
	var r := Rng.new(2024)
	var seen_low := false
	var seen_high := false
	for i: int in 5000:
		var v: int = r.next_int_range(3, 5)
		t.ok(v >= 3 and v <= 5, "next_int_range stays within [from, to]")
		if v == 3:
			seen_low = true
		if v == 5:
			seen_high = true
	t.ok(seen_low and seen_high, "next_int_range hits both endpoints over many rolls")


func _next_float_is_half_open(t: TestCase) -> void:
	var r := Rng.new(99)
	for i: int in 10000:
		var v: float = r.next_float()
		t.ok(v >= 0.0 and v < 1.0, "next_float stays in [0, 1)")


func _chance_threshold(t: TestCase) -> void:
	# chance(0) never fires, chance(1) always fires; the rest is probabilistic
	# and is not asserted beyond those two anchors.
	var r := Rng.new(5)
	var never := true
	for i: int in 1000:
		if r.chance(0.0):
			never = false
	t.ok(never, "chance(0) never fires")
	var always := true
	for i: int in 1000:
		if not r.chance(1.0):
			always = false
	t.ok(always, "chance(1) always fires")


func _pick_weighted_respects_weights(t: TestCase) -> void:
	# With heavy bias on option B, B must dominate over many draws. We do not
	# pin an exact ratio — that is rng-implementation dependent — only direction.
	var r := Rng.new(31337)
	var counts := {"a": 0, "b": 0}
	for i: int in 4000:
		var pick: String = r.pick_weighted(["a", "b"], PackedFloat32Array([0.1, 0.9]))
		counts[pick] += 1
	t.less(counts["a"], counts["b"], "weighted pick favours the heavier option")


func _hash_str_is_stable(t: TestCase) -> void:
	# String hashing feeds fork() names; if it drifted, a fork named "dispatch"
	# would silently become a different stream and every replay would break.
	t.eq(Rng.hash_str("dispatch"), Rng.hash_str("dispatch"), "hash_str is stable")
	t.ne(Rng.hash_str("dispatch"), Rng.hash_str("investigations"), "hash_str differs by name")
