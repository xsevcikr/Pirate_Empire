class_name BankScreen
extends PortScreen
## Deposit gold at a capital's bank: 1% interest a week, and it survives a sinking.

const STEPS: Array[int] = [100, 1000]


func _init() -> void:
	super()
	_title_key = "port.bank"


func build() -> void:
	add_header()
	var s: Dictionary = state()
	var l := Label.new()
	l.text = Loc.t("bank.balance") % [int(s["bank"]), int(TradeData.BANK_INTEREST_PER_WEEK * 100.0)]
	_box.add_child(l)
	for n in STEPS:
		add_button("bank.deposit", _move.bind(n, true)).text = "%s %d g" % [Loc.t("bank.deposit"), n]
		add_button("bank.withdraw", _move.bind(n, false)).text = "%s %d g" % [Loc.t("bank.withdraw"), n]
	add_button("bank.all_in", func() -> void: Finance.deposit(state(), int(state()["gold"])); _rebuild())
	add_button("menu.back", close)


func _move(n: int, deposit: bool) -> void:
	var ok: bool = Finance.deposit(state(), n) if deposit else Finance.withdraw(state(), n)
	if not ok:
		toast("port.cannot_buy")
	_rebuild()
