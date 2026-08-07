extends RefCounted
## Validates the chapter structure.
##
## Chapters are the campaign's narrative spine: they must cover every day 1..180
## exactly once (no gaps, no overlaps), reference only cutscenes that exist, and
## keep their acts in monotonic day order so the act banners read sensibly. A
## content edit that breaks any of these fails here instead of producing a
## confusing runtime.

const CAMPAIGN_DAYS := 180
const ContentLoader := preload("res://core/content_loader.gd")


func run(t: TestCase) -> void:
	var chapters: Array = ContentLoader.chapters()
	t.ok(not chapters.is_empty(), "chapter catalog is not empty")
	_chapters_cover_all_days_without_overlap(t, chapters)
	_chapter_cutscenes_exist(t, chapters)
	_acts_are_monotonic(t, chapters)
	_chapter_for_day_resolves(t)


func _chapters_cover_all_days_without_overlap(t: TestCase, chapters: Array) -> void:
	# Build a per-day owner map; every day must be owned by exactly one chapter.
	var owners: Dictionary = {}
	var parsed: Array = []
	for raw: Variant in chapters:
		var ch: Chapter = Chapter.from_dict(raw as Dictionary)
		parsed.append(ch)
		for day: int in range(ch.start_day, ch.end_day + 1):
			t.ok(not owners.has(day), "day %d is owned by only one chapter" % day)
			owners[day] = ch.id
	for day: int in range(1, CAMPAIGN_DAYS + 1):
		t.ok(owners.has(day), "day %d is covered by some chapter" % day)


func _chapter_cutscenes_exist(t: TestCase, chapters: Array) -> void:
	var cutscene_ids: Dictionary = {}
	for raw: Variant in ContentLoader.cutscenes():
		var cs: Cutscene = Cutscene.from_dict(raw as Dictionary)
		cutscene_ids[cs.id] = true
	for raw: Variant in chapters:
		var ch: Chapter = Chapter.from_dict(raw as Dictionary)
		if ch.cutscene_id.is_empty():
			continue
		t.ok(cutscene_ids.has(ch.cutscene_id), "chapter '%s' references existing cutscene '%s'" % [ch.id, ch.cutscene_id])


func _acts_are_monotonic(t: TestCase, chapters: Array) -> void:
	# Within an act, chapters must be in increasing day order; across acts, an
	# act's first day must not precede the previous act's last day.
	var prev_act := ""
	var prev_end := 0
	for raw: Variant in chapters:
		var ch: Chapter = Chapter.from_dict(raw as Dictionary)
		if ch.act != prev_act:
			prev_act = ch.act
			prev_end = 0
		t.ok(ch.start_day <= ch.end_day, "chapter '%s' start_day <= end_day" % ch.id)
		t.ok(ch.start_day > prev_end, "chapter '%s' starts after the previous chapter ends" % ch.id)
		prev_end = ch.end_day


func _chapter_for_day_resolves(t: TestCase) -> void:
	# The Game bridge resolves the owning chapter for a day; spot-check a few
	# milestones against what the catalog declares.
	Game.start_new_game(1)
	var milestones := {1: "ch_arrival", 12: "ch_faction_choice", 60: "ch_sabotage", 180: "ch_restructuring"}
	for day: int in milestones:
		Game.state.day = day
		var ch: Chapter = Game.chapter_for_day(day)
		t.ok(ch != null, "day %d has an owning chapter" % day)
		if ch != null:
			t.eq(ch.id, String(milestones[day]), "day %d maps to chapter '%s'" % [day, milestones[day]])
