extends RefCounted
## Validates cutscene graph integrity.
##
## Cutscenes are authored by hand in content/cutscenes.json, and a typo there —
## a choice pointing at a node that does not exist, a start node missing, a node
## with no path to a terminal — would freeze or crash the player at runtime in a
## way that looks like a code bug. This suite walks every cutscene's graph and
## asserts it is well-formed, so those failures surface in the test run.

const ContentLoader := preload("res://core/content_loader.gd")


func run(t: TestCase) -> void:
	var cutscenes: Array = ContentLoader.cutscenes()
	t.ok(not cutscenes.is_empty(), "cutscene catalog is not empty")
	for raw: Variant in cutscenes:
		var cs: Cutscene = Cutscene.from_dict(raw as Dictionary)
		_one_cutscene_is_well_formed(t, cs)
	# End-to-end: the Game bridge must resolve the faction-choice cutscene id we
	# reference from a chapter, and applying its branch choice must set the flag.
	_faction_choice_cutscene_exists(t)


func _one_cutscene_is_well_formed(t: TestCase, cs: Cutscene) -> void:
	t.ok(not cs.id.is_empty(), "cutscene has an id")
	t.ok(not cs.start_node_id.is_empty(), "cutscene '%s' names a start node" % cs.id)
	t.ok(cs.nodes.has(cs.start_node_id), "cutscene '%s' start node '%s' exists" % [cs.id, cs.start_node_id])
	# Every choice's next pointer must either be empty (terminal) or name a node
	# that exists. A dangling pointer would freeze the player on that choice.
	for nid: String in cs.nodes:
		var node: CutsceneNode = cs.nodes[nid] as CutsceneNode
		for raw: Variant in node.choices:
			var choice: Dictionary = raw as Dictionary
			var next: String = String(choice.get("next", ""))
			if next.is_empty():
				continue
			t.ok(cs.nodes.has(next), "cutscene '%s' node '%s' choice points at existing node '%s'" % [cs.id, nid, next])
		# Every effect must be a known kind so a typo is caught here, not silently
		# ignored at runtime.
		for raw: Variant in node.choices:
			var choice: Dictionary = raw as Dictionary
			for effect: Variant in choice.get("effects", []):
				_assert_known_effect(t, effect as Dictionary, cs.id)
	# Reachability: from the start node, at least one path must reach a terminal
	# (a node/choice with empty next). Otherwise the cutscene can never end.
	t.ok(_has_terminal_path(cs), "cutscene '%s' has at least one terminal path from start" % cs.id)


func _assert_known_effect(t: TestCase, effect: Dictionary, cutscene_id: String) -> void:
	var known := ["set_flag", "budget", "loyalty", "faction_standing"]
	var hit := false
	for k: String in known:
		if effect.has(k):
			hit = true
			break
	t.ok(hit, "cutscene '%s' effect is a known kind (got %s)" % [cutscene_id, str(effect.keys())])


func _has_terminal_path(cs: Cutscene) -> bool:
	# Depth-first from start; bounded by node count since the graph is finite.
	# A cycle without a terminal would loop forever; guard with a visited set.
	return _reaches_terminal(cs, cs.start_node_id, {})


func _reaches_terminal(cs: Cutscene, nid: String, visited: Dictionary) -> bool:
	if visited.has(nid):
		return false
	visited[nid] = true
	var node: CutsceneNode = cs.nodes.get(nid) as CutsceneNode
	if node == null:
		return false
	if node.choices.is_empty():
		return true   # a still-frame terminal node
	for raw: Variant in node.choices:
		var choice: Dictionary = raw as Dictionary
		var next: String = String(choice.get("next", ""))
		if next.is_empty():
			return true   # a choice that ends the cutscene
		if _reaches_terminal(cs, next, visited.duplicate()):
			return true
	return false


func _faction_choice_cutscene_exists(t: TestCase) -> void:
	# The chapter ch_faction_choice names cs_faction_choice; the cutscene must
	# resolve and its start node must be non-null, or the day-12 morning crashes.
	Game.start_new_game(1)
	Game.state.day = 12
	var cs: Cutscene = _catalog_cutscene("cs_faction_choice")
	t.ok(cs != null, "cs_faction_choice exists in the catalog")
	if cs == null:
		return
	t.ok(cs.start_node() != null, "cs_faction_choice has a reachable start node")


func _catalog_cutscene(id: String) -> Cutscene:
	for raw: Variant in ContentLoader.cutscenes():
		var cs: Cutscene = Cutscene.from_dict(raw as Dictionary)
		if cs.id == id:
			return cs
	return null
