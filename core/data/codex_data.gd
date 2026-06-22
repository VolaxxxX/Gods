class_name CodexData
extends RefCounted
## A Codex ("Book of the Dead") entry: a piece of mythological lore unlocked as
## the player learns it in play. Data-driven; see content/codex.json.

var id: String = ""
var category: String = "realm"   # realm | lord | (future: deity, being)
var order: int = 0               # sort order within a category
var title: String = ""           # raw display title
var body: Array = []             # raw paragraphs
# Unlock condition (either may be set): a story flag, or a conquered realm id.
var unlock_flag: String = ""
var unlock_realm: String = ""

func is_unlocked() -> bool:
	if unlock_flag != "" and SaveManager.has_flag(unlock_flag):
		return true
	if unlock_realm != "" and unlock_realm in SaveManager.realms_cleared():
		return true
	return unlock_flag == "" and unlock_realm == ""

static func from_dict(d: Dictionary) -> CodexData:
	var c := CodexData.new()
	c.id = d.get("id", "")
	c.category = d.get("category", "realm")
	c.order = int(d.get("order", 0))
	c.title = d.get("title", c.id)
	c.body = d.get("body", [])
	c.unlock_flag = d.get("unlock_flag", "")
	c.unlock_realm = d.get("unlock_realm", "")
	return c
