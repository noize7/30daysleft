extends Control
## Banco — UI en scenes/apps/bank_app.tscn

@onready var scroll: ScrollContainer = $Scroll
@onready var root_box: VBoxContainer = $Scroll/Root
@onready var header: Label = $Scroll/Root/Header
@onready var balance_label: Label = $Scroll/Root/BalanceLabel
@onready var info_label: Label = $Scroll/Root/InfoLabel
@onready var method_label: Label = $Scroll/Root/MethodLabel
@onready var btn_cash: Button = $Scroll/Root/Methods/BtnCash
@onready var btn_transfer: Button = $Scroll/Root/Methods/BtnTransfer
@onready var status_label: Label = $Scroll/Root/StatusLabel
@onready var _transfer_box: VBoxContainer = $Scroll/Root/TransferBox
@onready var _account_edit: LineEdit = $Scroll/Root/TransferBox/AccountEdit
@onready var _amount_edit: LineEdit = $Scroll/Root/TransferBox/AmountEdit
@onready var _btn_send: Button = $Scroll/Root/TransferBox/BtnRow/BtnSend
@onready var _btn_all: Button = $Scroll/Root/TransferBox/BtnRow/BtnAll
@onready var _progress_label: Label = $Scroll/Root/TransferBox/ProgressLabel
@onready var _transactions_box: VBoxContainer = $Scroll/Root/TransactionsBox
@onready var _transactions_title: Label = $Scroll/Root/TransactionsBox/TransactionsTitle
@onready var _transactions_list: ItemList = $Scroll/Root/TransactionsBox/TransactionsList
@onready var _account_label: Label = $Scroll/Root/TransferBox/AccountLabel
@onready var _amount_label: Label = $Scroll/Root/TransferBox/AmountLabel

var preferred_method: String = "transfer"

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if scroll:
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_style_buttons()
	_apply_locale()
	if btn_cash and not btn_cash.pressed.is_connected(_on_cash):
		btn_cash.pressed.connect(_on_cash)
	if btn_transfer and not btn_transfer.pressed.is_connected(_on_transfer_mode):
		btn_transfer.pressed.connect(_on_transfer_mode)
	if _btn_send and not _btn_send.pressed.is_connected(_on_transfer):
		_btn_send.pressed.connect(_on_transfer)
	if _btn_all and not _btn_all.pressed.is_connected(_on_fill_all):
		_btn_all.pressed.connect(_on_fill_all)
	if _transactions_list and not _transactions_list.item_selected.is_connected(_on_transaction_selected):
		_transactions_list.item_selected.connect(_on_transaction_selected)
	if BankSystem and not BankSystem.transactions_changed.is_connected(_refresh_transactions):
		BankSystem.transactions_changed.connect(_refresh_transactions)
	if InvestigationSystem:
		InvestigationSystem.register_bank_open()
	if not GameManager.money_changed.is_connected(_on_money):
		GameManager.money_changed.connect(_on_money)
	if GameManager.has_signal("escape_changed"):
		if not GameManager.escape_changed.is_connected(_on_escape):
			GameManager.escape_changed.connect(_on_escape)
	if LocaleSystem and not LocaleSystem.language_changed.is_connected(_on_lang):
		LocaleSystem.language_changed.connect(_on_lang)
	_refresh_balance()
	_refresh_transactions()
	_set_method(preferred_method)

func _on_lang(_lang: String) -> void:
	_apply_locale()
	_refresh_balance()
	_set_method(preferred_method)

func _apply_locale() -> void:
	if header:
		header.text = LocaleSystem.t("bank.title", "Banco") if LocaleSystem else "Banco"
	if _transactions_title:
		_transactions_title.text = LocaleSystem.t("bank.recent", "Movimientos recientes") if LocaleSystem else "Movimientos recientes"
	if _account_label:
		_account_label.text = LocaleSystem.t("bank.account_label", "Cuenta a transferir:") if LocaleSystem else "Cuenta a transferir:"
	if _amount_label:
		_amount_label.text = LocaleSystem.t("bank.amount_label", "Cantidad:") if LocaleSystem else "Cantidad:"
	if _account_edit:
		_account_edit.placeholder_text = LocaleSystem.t("bank.account_placeholder", "12 dígitos (del correo)") if LocaleSystem else "12 dígitos (del correo)"
	if _amount_edit:
		_amount_edit.placeholder_text = LocaleSystem.t("bank.amount_placeholder", "Ej: 100") if LocaleSystem else "Ej: 100"
	if _btn_send:
		_btn_send.text = LocaleSystem.t("bank.send", "Transferir") if LocaleSystem else "Transferir"
	if _btn_all:
		_btn_all.text = LocaleSystem.t("bank.all_balance", "Todo el saldo") if LocaleSystem else "Todo el saldo"
	if btn_cash:
		btn_cash.text = LocaleSystem.t("bank.cash", "Efectivo") if LocaleSystem else "Efectivo"
	if btn_transfer:
		btn_transfer.text = LocaleSystem.t("bank.transfer", "Transferencia") if LocaleSystem else "Transferencia"
	if info_label and GameManager:
		var info_fmt: String = LocaleSystem.t("bank.info", "Transfiere a la cuenta del correo.\nMeta de escape: $%.0f") if LocaleSystem else "Transfiere a la cuenta del correo.\nMeta de escape: $%.0f"
		info_label.text = info_fmt % GameManager.MONEY_GOAL

func _style_buttons() -> void:
	for btn in [btn_cash, btn_transfer, _btn_send, _btn_all]:
		if btn == null:
			continue
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.12, 0.45, 0.28)
		s.set_corner_radius_all(6)
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", s)
		var h := s.duplicate()
		h.bg_color = Color(0.18, 0.58, 0.35)
		btn.add_theme_stylebox_override("hover", h)
		btn.add_theme_color_override("font_color", Color.WHITE)

func _on_cash() -> void:
	if SoundSystem:
		SoundSystem.play_button()
	_set_method("cash")

func _on_transfer_mode() -> void:
	if SoundSystem:
		SoundSystem.play_button()
	_set_method("transfer")

func _on_money(_m: float) -> void:
	_refresh_balance()

func _on_escape(_transferred: float) -> void:
	_refresh_balance()

func _refresh_transactions() -> void:
	if _transactions_list == null or BankSystem == null:
		return
	_transactions_list.clear()
	for tx in BankSystem.get_transactions():
		var amount := float(tx.get("amount", 0.0))
		var prefix := "+" if amount >= 0.0 else "-"
		_transactions_list.add_item("%s  %s  %s$%.2f" % [
			str(tx.get("date", "")),
			str(tx.get("merchant", "")),
			prefix,
			absf(amount)
		])
	if _transactions_list.item_count == 0:
		_transactions_list.add_item(LocaleSystem.t("bank.no_movements", "No hay movimientos disponibles.") if LocaleSystem else "No hay movimientos disponibles.")

func _on_transaction_selected(index: int) -> void:
	if BankSystem == null:
		return
	var txs := BankSystem.get_transactions()
	if index < 0 or index >= txs.size():
		return
	var tx: Dictionary = txs[index]
	var tx_id := str(tx.get("id", ""))
	BankSystem.mark_seen(tx_id)
	if status_label:
		status_label.text = "%s\n%s" % [
			str(tx.get("merchant", "")),
			(LocaleSystem.field(tx, "note", str(tx.get("note", ""))) if LocaleSystem else str(tx.get("note", "")))
		]
		status_label.add_theme_color_override("font_color", Color(0.1, 0.3, 0.2))
	if SoundSystem:
		SoundSystem.play_click(true)

func _refresh_balance() -> void:
	if balance_label:
		var bal_fmt: String = LocaleSystem.t("bank.balance", "Saldo: $%.2f") if LocaleSystem else "Saldo: $%.2f"
		balance_label.text = bal_fmt % GameManager.money
	if _progress_label:
		var prog_fmt: String = LocaleSystem.t("bank.escape_progress", "Progreso escape: $%.2f / $%.0f") if LocaleSystem else "Progreso escape: $%.2f / $%.0f"
		_progress_label.text = prog_fmt % [
			GameManager.escape_transferred, GameManager.MONEY_GOAL
		]
	if info_label:
		var info_fmt: String = LocaleSystem.t("bank.info", "Transfiere a la cuenta del correo.\nMeta de escape: $%.0f") if LocaleSystem else "Transfiere a la cuenta del correo.\nMeta de escape: $%.0f"
		info_label.text = info_fmt % GameManager.MONEY_GOAL

func _set_method(m: String) -> void:
	preferred_method = m
	if method_label:
		if m == "cash":
			method_label.text = LocaleSystem.t("bank.method_cash", "Método preferido: Efectivo") if LocaleSystem else "Método preferido: Efectivo"
		else:
			method_label.text = LocaleSystem.t("bank.method_transfer", "Método preferido: Transferencia") if LocaleSystem else "Método preferido: Transferencia"
	if _transfer_box:
		_transfer_box.visible = (m == "transfer")
	if status_label:
		if m == "transfer":
			status_label.text = (LocaleSystem.t("bank.hint_transfer", "Introduce la cuenta y la cantidad, luego Transferir.") if LocaleSystem else "Introduce la cuenta y la cantidad, luego Transferir.")
		else:
			status_label.text = LocaleSystem.t("bank.cash_no_escape", "Efectivo no sirve para el escape. Usa Transferencia.") if LocaleSystem else "Efectivo no sirve para el escape. Usa Transferencia."
		status_label.add_theme_color_override("font_color", Color(0.1, 0.35, 0.2))

func _on_fill_all() -> void:
	if SoundSystem:
		SoundSystem.play_click(true)
	if _amount_edit == null:
		return
	var cents: int = int(floor(GameManager.money * 100.0 + 0.001))
	_amount_edit.text = "%.2f" % (float(cents) / 100.0)

func _parse_amount(raw: String) -> float:
	var s: String = raw.strip_edges().replace(",", ".").replace(" ", "").replace("$", "")
	if s.is_empty():
		return -1.0
	var cleaned := ""
	var dot_seen := false
	for i in range(s.length()):
		var ch: String = s[i]
		if ch >= "0" and ch <= "9":
			cleaned += ch
		elif ch == "." and not dot_seen:
			cleaned += ch
			dot_seen = true
	if cleaned.is_empty() or cleaned == ".":
		return -1.0
	return float(cleaned)

func _on_transfer() -> void:
	if SoundSystem:
		SoundSystem.play_button()
	if _account_edit == null or _amount_edit == null:
		return
	var account: String = _account_edit.text.strip_edges().replace(" ", "")
	var amount: float = _parse_amount(_amount_edit.text)
	if account.is_empty():
		_set_status((LocaleSystem.t("bank.need_account", "Introduce el número de cuenta del correo.") if LocaleSystem else "Introduce el número de cuenta del correo."), false)
		return
	if amount < 0.0:
		_set_status((LocaleSystem.t("bank.invalid_amount", "Cantidad no válida.") if LocaleSystem else "Cantidad no válida."), false)
		return
	if amount <= 0.0:
		_set_status("La cantidad debe ser mayor que 0.", false)
		return
	if amount > GameManager.money + 0.011:
		_set_status((LocaleSystem.t("bank.insufficient", "Saldo insuficiente (tienes $%.2f).") if LocaleSystem else "Saldo insuficiente (tienes $%.2f).") % GameManager.money, false)
		return
	if amount > GameManager.money:
		amount = GameManager.money
	var msg: String = GameManager.transfer_money(account, amount)
	var ok := msg.begins_with("Transfer")
	_set_status(msg, ok)
	_refresh_balance()
	if _amount_edit and ok:
		_amount_edit.text = ""

func _set_status(msg: String, ok: bool) -> void:
	if status_label:
		status_label.text = msg
		status_label.add_theme_color_override(
			"font_color", Color(0.1, 0.45, 0.2) if ok else Color(0.7, 0.15, 0.1)
		)

func get_preferred_method() -> String:
	return preferred_method
