extends "res://tests/test_case.gd"
## Weighing-of-the-soul verdict & karma bonus.

const SoulJudgmentC = preload("res://systems/progression/soul_judgment.gd")

func run() -> Dictionary:
	print("[SoulJudgment]")

	var r = SoulJudgmentC.weigh({"aggressive": 5, "cautious": 2, "greedy": 0, "merciful": 0})
	check(r["dominant"] == "aggressive", "dominant style detected")
	check(r["verdict_key"] == "judgment.wrathful", "aggressive -> wrathful verdict")
	check(r["karma_bonus"] == 5, "karma bonus equals dominant count")

	var z = SoulJudgmentC.weigh({"aggressive": 0, "cautious": 0, "greedy": 0, "merciful": 0})
	check(z["verdict_key"] == "judgment.balanced", "no style -> balanced (Ma'at)")
	check(z["karma_bonus"] == 0, "no style -> no bonus")

	var big = SoulJudgmentC.weigh({"greedy": 30})
	check(big["verdict_key"] == "judgment.avaricious", "greedy -> avaricious")
	check(big["karma_bonus"] == 20, "karma bonus is capped at 20")

	return result()
