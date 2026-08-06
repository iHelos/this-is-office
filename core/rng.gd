class_name Rng
extends RefCounted
## Deterministic, splittable random source.
##
## The brief makes determinism a load-bearing property, not a nicety: §8.3 wants
## scene layout recomputed from [code]hash(hero_id, segment_index)[/code] rather
## than stored, and §8.6 wants a hero's appearance to *be* a number so that
## another player's hero travels down a fate thread as a few bytes.
##
## Two things follow, and neither is satisfied by [RandomNumberGenerator]:
##
## [b]Portability.[/b] splitmix64 is specified in integer arithmetic, so the same
## seed yields the same bytes on every platform — and, later, in the Rust core
## (see docs/adr/0002), where the same algorithm will be reimplemented and pinned
## against the same vectors.
##
## [b]Names that cannot be shadowed.[/b] The primitives are [method next_float],
## [method next_float_range] and [method next_int_range] rather than the obvious
## randf/randf_range/randi_range, because those three are also functions on
## GDScript's [@GlobalScope]. An unqualified call inside this class resolves to
## the GLOBAL one, silently, and the result still compiles and still looks random
## — so [method gauss] and [method chance] were drawing from the engine's shared
## generator instead of from the seed, and every hero came out different on every
## run. It cost an afternoon; the names are deliberately un-collidable now, and
## test_rng pins the derived helpers rather than only the primitives.
##
## [b]Stream stability.[/b] [method fork] derives a child stream from
## [code](seed, name)[/code] [i]without advancing the parent[/i]. Adding a new
## detail to the generator therefore cannot reshuffle every hero that already
## exists — a property that a single shared stream silently destroys the first
## time anyone inserts a [code]next_float()[/code] in the middle of a function.

const _GAMMA := -7046029254386353131      ## 0x9E3779B97F4A7C15
const _MIX_A := -4658895280553007687      ## 0xBF58476D1CE4E5B9
const _MIX_B := -7723592293110705685      ## 0x94D049BB133111EB
const _FNV_OFFSET := -3750763034362895579 ## 0xCBF29CE484222325
const _FNV_PRIME := 1099511628211

var _state: int
var _seed: int


func _init(seed_value: int = 0) -> void:
	_seed = seed_value
	_state = seed_value


## Logical (zero-filling) right shift. GDScript's [code]>>[/code] is arithmetic,
## which would smear the sign bit through the mixing steps and break the
## algorithm for half of all seeds.
static func _lsr(x: int, k: int) -> int:
	if k <= 0:
		return x
	if k >= 64:
		return 0
	return (x >> k) & ((1 << (64 - k)) - 1)


static func _mix64(z0: int) -> int:
	var z := z0
	z = (z ^ _lsr(z, 30)) * _MIX_A
	z = (z ^ _lsr(z, 27)) * _MIX_B
	return z ^ _lsr(z, 31)


## Stable 64-bit hash of a string (FNV-1a). Used to name streams; never exposed
## as content, so its exact value only has to stay stable, not be pretty.
static func hash_str(s: String) -> int:
	var h := _FNV_OFFSET
	for b: int in s.to_utf8_buffer():
		h = (h ^ b) * _FNV_PRIME
	return h


## Mixes an arbitrary set of integers into one seed. This is the
## [code]hash(hero_id, segment_index)[/code] of §8.3.
static func seed_from(parts: Array) -> int:
	var h := _FNV_OFFSET
	for p: Variant in parts:
		var v: int = p if p is int else hash_str(str(p))
		h = _mix64(h ^ v)
	return h


static func from_seed(seed_value: int) -> Rng:
	return Rng.new(seed_value)


func seed_value() -> int:
	return _seed


## An independent stream, derived from this one's [i]seed[/i], not its position.
## Calling [method fork] never consumes randomness from the parent.
func fork(name: String) -> Rng:
	return Rng.new(_mix64(_seed ^ hash_str(name)))


func next_u64() -> int:
	_state += _GAMMA
	return _mix64(_state)


## 53-bit float in [0, 1).
func next_float() -> float:
	return float(_lsr(next_u64(), 11)) * (1.0 / 9007199254740992.0)


func next_float_range(from: float, to: float) -> float:
	return from + (to - from) * next_float()


## Symmetric jitter in [-amount, +amount]. The workhorse of §9.5's irregularity:
## "the next step in quality is not more detail, it is irregularity".
func jitter(amount: float) -> float:
	return next_float_range(-amount, amount)


func next_int_range(from: int, to: int) -> int:
	if to <= from:
		return from
	return from + int(_lsr(next_u64(), 1) % (to - from + 1))


func chance(p: float) -> bool:
	return next_float() < p


func pick(options: Array) -> Variant:
	assert(not options.is_empty(), "Rng.pick: empty options")
	return options[next_int_range(0, options.size() - 1)]


## Weighted pick. [param weights] must be the same length as [param options] and
## sum to something positive.
func pick_weighted(options: Array, weights: PackedFloat32Array) -> Variant:
	assert(options.size() == weights.size(), "Rng.pick_weighted: length mismatch")
	var total := 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		return pick(options)
	var roll := next_float() * total
	for i: int in options.size():
		roll -= weights[i]
		if roll <= 0.0:
			return options[i]
	return options[options.size() - 1]


## Approximately normal, via the sum of three uniforms. Cheap, bounded at ±3
## sigma, and bounded is what body proportions want — a true Gaussian tail
## produces the occasional hero with a head twice the size of his torso.
func gauss(mean: float, sd: float) -> float:
	var s := next_float() + next_float() + next_float() - 1.5
	return mean + s * sd * 1.4142135


## Value in [from, to] biased toward the middle. Used for proportions where the
## extremes are legal but should stay rare.
func central(from: float, to: float) -> float:
	var mid := (from + to) * 0.5
	return clampf(gauss(mid, (to - from) * 0.22), from, to)
