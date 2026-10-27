class_name JournalScreen
extends PortScreen
## The captain's log (L): the written log, achievements and lifetime stats on three tabs.

const TABS: Array[String] = ["log", "achievements", "stats", "clues"]
var tab: String = "log"


func _init() -> void:
	super()
	_title_key = "journal.title"
	dim = 0.55


func build() -> void:
	var row := HBoxContainer.new()
	for t in TABS:
		var b := Button.new()
		b.text = Loc.t("journal.tab." + t)
		b.disabled = t == tab
		b.pressed.connect(_set_tab.bind(t))
		row.add_child(b)
	_box.add_child(row)
	begin_list(400.0)
	var s: Dictionary = state()
	match tab:
		"log":
			var entries: Array = s["log"]
			if entries.is_empty():
				add_text(Loc.t("journal.empty"))
			for i in range(entries.size() - 1, -1, -1):
				var e: Dictionary = entries[i]
				add_text("%s %d: %s" % [Loc.t("journal.day"), int(e["day"]), CaptainLog.text(e)])
		"achievements":
			add_text(Loc.t("journal.ach_count") % [Achievements.count(s), AchievementData.LIST.size()])
			for a in AchievementData.LIST:
				var id: String = str(a["id"])
				var got: bool = Achievements.unlocked(s, id)
				add_text("%s %s - %s" % ["[x]" if got else "[ ]", Loc.t("ach." + id), Loc.t("ach.%s.desc" % id)])
		"stats":
			for k in ["ships_sunk", "gold_earned", "distance_km", "duels_won", "islands_found", "tours_done", "fish_caught", "games_played"]:
				add_text("%s: %d" % [Loc.t("stat." + k), int(Achievements.value(s, k))])
		"clues":
			var frags: Array = s["map_fragments"]
			if frags.is_empty():
				add_text(Loc.t("journal.no_clues"))
			for f in frags:
				add_text(str(f))
	add_button("menu.back", close)


func _set_tab(t: String) -> void:
	tab = t
	_rebuild()
