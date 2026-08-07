class_name Chapter
extends RefCounted
## A story chapter: one beat of the campaign's narrative spine.
##
## The campaign is organised as acts containing chapters (the TITP "act"
## structure). Each chapter spans a range of days and names the cutscene that
## plays as its prologue on the first morning inside that range. Chapters are
## authored in content/chapters.json; adding one is a data edit, not a code
## change.
##
## A chapter with an empty [member cutscene_id] still structures the timeline
## (it shows an act title) but plays no cutscene — useful for minor beats.

var id: String = ""
var title_key: String = ""         # i18n key for the chapter title
var act: String = ""               # act id this chapter belongs to
var act_title_key: String = ""     # i18n key for the act title (for the banner)
var start_day: int = 1             # inclusive
var end_day: int = 1               # inclusive
var cutscene_id: String = ""       # cutscene played on the first morning, "" = none


static func from_dict(d: Dictionary) -> Chapter:
	var c := Chapter.new()
	c.id = String(d.get("id", ""))
	c.title_key = String(d.get("title_key", ""))
	c.act = String(d.get("act", ""))
	c.act_title_key = String(d.get("act_title_key", ""))
	c.start_day = int(d.get("start_day", 1))
	c.end_day = int(d.get("end_day", 1))
	c.cutscene_id = String(d.get("cutscene_id", ""))
	return c


func clone() -> Chapter:
	# Chapter is effectively immutable during play (the cutscene plays or it
	# doesn't); clone is here for consistency with the rest of the core data.
	var c := Chapter.new()
	c.id = id
	c.title_key = title_key
	c.act = act
	c.act_title_key = act_title_key
	c.start_day = start_day
	c.end_day = end_day
	c.cutscene_id = cutscene_id
	return c


func to_dict() -> Dictionary:
	return {
		"id": id,
		"title_key": title_key,
		"act": act,
		"act_title_key": act_title_key,
		"start_day": start_day,
		"end_day": end_day,
		"cutscene_id": cutscene_id,
	}


## True when [param day] falls inside this chapter's range.
func contains_day(day: int) -> bool:
	return day >= start_day and day <= end_day
