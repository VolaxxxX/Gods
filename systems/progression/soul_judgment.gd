class_name SoulJudgment
extends RefCounted
## The Egyptian "weighing of the heart": at run end the player's play style is
## weighed and turned into a verdict + a karma bonus that modulates meta rewards.
## Pure & headless-testable. Style counters are accumulated on RunManager.

const VERDICTS := {
	"aggressive": "judgment.wrathful",
	"cautious": "judgment.prudent",
	"greedy": "judgment.avaricious",
	"merciful": "judgment.merciful",
}

## style: Dictionary of kind -> count. Returns:
##   { "dominant": String, "verdict_key": String, "karma_bonus": int }
static func weigh(style: Dictionary) -> Dictionary:
	var dominant := ""
	var best := 0
	for kind in style:
		var v := int(style[kind])
		if v > best:
			best = v
			dominant = kind
	var verdict := "judgment.balanced"
	if dominant != "" and best > 0 and VERDICTS.has(dominant):
		verdict = VERDICTS[dominant]
	return {"dominant": dominant, "verdict_key": verdict, "karma_bonus": mini(best, 20)}
