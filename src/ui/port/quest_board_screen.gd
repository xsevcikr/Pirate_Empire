class_name QuestBoardScreen
extends PortScreen
## Jobs posted in port. Taking one puts its target on the sea.


func _init() -> void:
	super()
	_title_key = "port.quests"


func build() -> void:
	add_header()
	begin_list()
	var s: Dictionary = state()
	var tut_blocks: bool = TutorialData.index_of(s["tutorial"]) < TutorialData.index_of("quest_board")
	var open: Array[String] = QuestData.available(s)
	if open.is_empty():
		add_text(Loc.t("port.no_quests"))
	for id in open:
		var job: Dictionary = QuestData.JOBS[id]
		add_text("%s (%d g)\n%s" % [Loc.t(job["title"]), int(job["reward"]), Loc.t(job["text"])])
		add_item_row("", [[Loc.t("port.accept"), _accept.bind(id) if not tut_blocks else Callable()]])
	if tut_blocks and not open.is_empty():
		add_text(Loc.t("port.quests_locked"))
	for id: String in s["quests"]:
		add_text("• " + Loc.t(QuestData.JOBS[id]["title"]) + " (" + Loc.t("port.active") + ")")
	add_button("menu.back", close)


func _accept(id: String) -> void:
	state()["quests"].append(id)
	emit_bus("quest_taken", [id])
	toast("port.quest_taken")
	_rebuild()
