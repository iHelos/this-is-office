class_name CutsceneNode
extends RefCounted
## One frame of a branching cutscene.
##
## A cutscene is a directed graph of these nodes. Each node shows a speaker and
## a line, then offers zero or more choices. A node with no choices is terminal:
## the cutscene ends there. Each choice points at the id of the next node and
## carries an optional list of effects (flags, budget, loyalty, faction standing)
## that the Game bridge applies when the player picks it.
##
## A linear cutscene is just a graph where every node has exactly one choice —
## the format does not distinguish, so authors can start linear and add branches
## later without changing the schema.

var id: String = ""
var speaker_key: String = ""        # i18n key, e.g. "speaker.cto"
var text_key: String = ""           # i18n key for the node's line
var choices: Array = []             # Array[Dictionary]: {label_key, next, effects}


static func from_dict(d: Dictionary) -> CutsceneNode:
	var n := CutsceneNode.new()
	n.id = String(d.get("id", ""))
	n.speaker_key = String(d.get("speaker_key", ""))
	n.text_key = String(d.get("text_key", ""))
	# Choices are free-form dicts defined in content/cutscenes.json; deep-copy so
	# the catalog stays pristine across many games in one session.
	var src: Array = d.get("choices", [])
	var cloned := []
	for ch: Variant in src:
		cloned.append((ch as Dictionary).duplicate(true))
	n.choices = cloned
	return n


func clone() -> CutsceneNode:
	var c := CutsceneNode.new()
	c.id = id
	c.speaker_key = speaker_key
	c.text_key = text_key
	c.choices = []
	for ch: Dictionary in choices:
		c.choices.append(ch.duplicate(true))
	return c


func to_dict() -> Dictionary:
	return {
		"id": id,
		"speaker_key": speaker_key,
		"text_key": text_key,
		"choices": choices.duplicate(true),
	}
