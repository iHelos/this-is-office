class_name Cutscene
extends RefCounted
## A branching cutscene, the corporate analogue of a TITP comic-panel interlude.
##
## Holds a start node id and a dictionary of [CutsceneNode] by id. The player
## walks the graph by picking choices; the Game bridge applies each choice's
## effects. A cutscene with no choices anywhere is a single still frame.
##
## All randomness-free and node-free: this is plain data, so it clones cleanly
## into the next deterministic state and the test suite can assert graph
## integrity (no dangling next pointers, a start node exists, every reachable
## branch terminates).

var id: String = ""
var start_node_id: String = ""
var nodes: Dictionary = {}   # node_id -> CutsceneNode
# Optional reactive trigger. Empty for day-scripted cutscenes (the chapter
# system drives those); non-empty cutscenes only fire when the trigger evaluates
# true against the live state. See Triggers.evaluate.
var trigger: Dictionary = {}


static func from_dict(d: Dictionary) -> Cutscene:
	var c := Cutscene.new()
	c.id = String(d.get("id", ""))
	c.start_node_id = String(d.get("start_node_id", ""))
	c.trigger = (d.get("trigger", {}) as Dictionary).duplicate(true)
	var raw_nodes: Array = d.get("nodes", [])
	for raw: Variant in raw_nodes:
		var node: CutsceneNode = CutsceneNode.from_dict(raw as Dictionary)
		if not node.id.is_empty():
			c.nodes[node.id] = node
	return c


func clone() -> Cutscene:
	var c := Cutscene.new()
	c.id = id
	c.start_node_id = start_node_id
	c.trigger = trigger.duplicate(true)
	for nid: String in nodes:
		c.nodes[nid] = (nodes[nid] as CutsceneNode).clone()
	return c


func start_node() -> CutsceneNode:
	return nodes.get(start_node_id) as CutsceneNode


func node_by_id(nid: String) -> CutsceneNode:
	return nodes.get(nid) as CutsceneNode


func to_dict() -> Dictionary:
	var arr := []
	for nid: String in nodes:
		arr.append((nodes[nid] as CutsceneNode).to_dict())
	return {
		"id": id,
		"start_node_id": start_node_id,
		"trigger": trigger.duplicate(true),
		"nodes": arr,
	}
