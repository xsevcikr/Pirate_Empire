class_name RivalScreen
extends MenuScreen
## The rivals page (O): each named rival with their meter, level, the trophy they hold and how the arc stands.


func _init() -> void:
	super()
	_title_key = "rival.title"
	dim = 0.55


func build() -> void:
	var st: Dictionary = Session.state
	var nem: String = RivalState.nemesis(st)
	if nem != "":
		_label(Loc.t("rival.nemesis") % RivalData.def(nem)["name"])
	for id: String in RivalData.ORDER:
		var r: Dictionary = RivalState.get_rival(st, id)
		var line: String = "%s  -  %s %d  -  %s %d" % [RivalData.def(id)["name"], Loc.t("rival.level"), int(r["level"]), Loc.t("rival.meter"), roundi(float(r["meter"]))]
		if bool(r["defeated"]):
			line += "  (%s)" % Loc.t("rival.beaten")
		elif not RivalData.CAMPAIGN.has(id) and not RivalState.available(st, id):
			line += "  (%s)" % Loc.t("rival.unknown")
		_label(line)
		if str(r["trophy"]) != "" and not bool(r["defeated"]):
			_label("    " + Loc.t("rival.holds." + str(r["trophy"])))
	add_button("menu.back", close)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(l)
	return l
