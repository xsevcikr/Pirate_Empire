class_name SkillsScreen
extends PortScreen
## The captain's level, XP and the five skill trees (U): spend a point to raise a skill one rank.


func _init() -> void:
	super()
	_title_key = "skills.title"
	dim = 0.55


func build() -> void:
	var s: Dictionary = state()
	var lvl: int = int(s["captain_level"])
	var next_xp: int = ProgressionData.xp_to_reach(lvl + 1) if lvl < ProgressionData.MAX_LEVEL else Progression.xp(s)
	var head := Label.new()
	head.text = Loc.t("skills.header") % [lvl, Progression.xp(s), next_xp, Progression.points_free(s)]
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(head)
	begin_list(420.0)
	for tree: String in ProgressionData.TREES:
		var t: Label = add_text(Loc.t("skills.tree." + tree))
		t.add_theme_font_size_override("font_size", 22)
		for sk: Dictionary in ProgressionData.SKILLS[tree]:
			var full: String = "%s.%s" % [tree, sk["id"]]
			var r: int = Progression.rank(s, full)
			var pips: String = "[%s%s]" % ["#".repeat(r), "-".repeat(ProgressionData.MAX_RANK - r)]
			var ok: bool = Progression.can_spend(s, full)
			add_item_row("%s %s  -  %s" % [Loc.t("skill." + full), pips, describe(full, r)],
				[[Loc.t("skills.raise"), _raise.bind(full) if ok else Callable()]])
	add_button("skills.respec", _respec)
	add_button("menu.back", close)


## "Faster reload: x0.92 -> x0.84" for the next rank (or the current value at full rank).
static func describe(full_id: String, r: int) -> String:
	var cur: float = Progression.value_at(full_id, r)
	if r >= ProgressionData.MAX_RANK:
		return _fmt(cur)
	return "%s > %s" % [_fmt(cur), _fmt(Progression.value_at(full_id, r + 1))]


static func _fmt(v: float) -> String:
	return "%d" % int(v) if absf(v - roundf(v)) < 0.001 and absf(v) >= 1.0 and v != 1.0 else "%.2f" % v


func _raise(full: String) -> void:
	if Progression.spend(state(), full):
		toast("skills.raised")
	_rebuild()


func _respec() -> void:
	Progression.respec(state())
	_rebuild()
