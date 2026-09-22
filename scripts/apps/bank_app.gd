extends Control
## Banco — saldo + transferencia a cuenta de escape (layout estable)

@onready var scroll: ScrollContainer = $Scroll
@onready var root_box: VBoxContainer = $Scroll/Root
@onready var header: Label = $Scroll/Root/Header
@onready var balance_label: Label = $Scroll/Root/BalanceLabel
@onready var info_label: Label = $Scroll/Root/InfoLabel
@onready var method_label: Label = $Scroll/Root/MethodLabel
@onready var btn_cash: Button = $Scroll/Root/Methods/BtnCash
@onready var btn_transfer: Button = $Scroll/Root/Methods/BtnTransfer
@onready var status_label: Label = $Scroll/Root/StatusLabel

var preferred_method: String = "transfer"
var _account_edit: LineEdit = null
var _amount_edit: LineEdit = null
var _btn_send: Button = null
var _btn_all: Button = null
var _progress_label: Label = null
var _transfer_box: VBoxContainer = null

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if scroll:
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if root_box:
		root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_box.custom_minimum_size = Vector2(0, 0)
	_build_transfer_ui()
	_style()
	if btn_cash and not btn_cash.pressed.is_connected(_on_cash):
		btn_cash.pressed.connect(_on_cash)
	if btn_transfer and not btn_transfer.pressed.is_connected(_on_transfer_mode):
		btn_transfer.pressed.connect(_on_transfer_mode)
	if not GameManager.money_changed.is_connected(_on_money):
		GameManager.money_changed.connect(_on_money)
	if GameManager.has_signal("escape_changed"):
		if not GameManager.escape_changed.is_connected(_on_escape):
			GameManager.escape_changed.connect(_on_escape)
	_refresh_balance()
	_set_method(preferred_method)

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

func _build_transfer_ui() -> void:
	if root_box == null:
		return
	if root_box.get_node_or_null("TransferBox") != null:
		_transfer_box = root_box.get_node("TransferBox")
		_account_edit = _transfer_box.get_node_or_null("AccountEdit")
		_amount_edit = _transfer_box.get_node_or_null("AmountEdit")
		_btn_send = _transfer_box.get_node_or_null("BtnSend")
		_btn_all = _transfer_box.get_node_or_null("BtnAll")
		_progress_label = _transfer_box.get_node_or_null("ProgressLabel")
		if _btn_send and not _btn_send.pressed.is_connected(_on_transfer):
			_btn_send.pressed.connect(_on_transfer)
		if _btn_all and not _btn_all.pressed.is_connected(_on_fill_all):
			_btn_all.pressed.connect(_on_fill_all)
		return

	_transfer_box = VBoxContainer.new()
	_transfer_box.name = "TransferBox"
	_transfer_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_transfer_box.add_theme_constant_override("separation", 6)
	root_box.add_child(_transfer_box)
	if status_label and status_label.get_parent() == root_box:
		root_box.move_child(_transfer_box, status_label.get_index())

	var acc_lbl := Label.new()
	acc_lbl.text = "Cuenta a transferir:"
	acc_lbl.add_theme_font_size_override("font_size", 14)
	acc_lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))
	acc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_transfer_box.add_child(acc_lbl)

	_account_edit = LineEdit.new()
	_account_edit.name = "AccountEdit"
	_account_edit.placeholder_text = "12 dígitos (del correo)"
	_account_edit.custom_minimum_size = Vector2(120, 34)
	_account_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_account_edit.clip_contents = true
	_account_edit.max_length = 24
	_account_edit.context_menu_enabled = true
	_transfer_box.add_child(_account_edit)

	var amt_lbl := Label.new()
	amt_lbl.text = "Cantidad:"
	amt_lbl.add_theme_font_size_override("font_size", 14)
	amt_lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))
	_transfer_box.add_child(amt_lbl)

	_amount_edit = LineEdit.new()
	_amount_edit.name = "AmountEdit"
	_amount_edit.placeholder_text = "Ej: 100"
	_amount_edit.custom_minimum_size = Vector2(120, 34)
	_amount_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_amount_edit.clip_contents = true
	_amount_edit.max_length = 16
	_transfer_box.add_child(_amount_edit)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_transfer_box.add_child(btn_row)

	_btn_send = Button.new()
	_btn_send.name = "BtnSend"
	_btn_send.text = "Transferir"
	_btn_send.custom_minimum_size = Vector2(100, 36)
	_btn_send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_send.pressed.connect(_on_transfer)
	btn_row.add_child(_btn_send)

	_btn_all = Button.new()
	_btn_all.name = "BtnAll"
	_btn_all.text = "Todo el saldo"
	_btn_all.custom_minimum_size = Vector2(100, 36)
	_btn_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_all.pressed.connect(_on_fill_all)
	btn_row.add_child(_btn_all)

	_progress_label = Label.new()
	_progress_label.name = "ProgressLabel"
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_label.add_theme_font_size_override("font_size", 13)
	_progress_label.add_theme_color_override("font_color", Color(0.15, 0.3, 0.15))
	_transfer_box.add_child(_progress_label)

func _style() -> void:
	if header:
		header.text = "Banco"
		header.add_theme_color_override("font_color", Color(0.0, 0.25, 0.15))
		header.add_theme_font_size_override("font_size", 22)
	if balance_label:
		balance_label.add_theme_color_override("font_color", Color(0.0, 0.4, 0.15))
		balance_label.add_theme_font_size_override("font_size", 18)
	if info_label:
		info_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.25))
		info_label.add_theme_font_size_override("font_size", 13)
		info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_label.text = "Transfiere a la cuenta del correo.\nMeta de escape: $%.0f" % GameManager.MONEY_GOAL
	if method_label:
		method_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))
		method_label.add_theme_font_size_override("font_size", 14)
	if status_label:
		status_label.add_theme_font_size_override("font_size", 12)
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for btn in [btn_cash, btn_transfer, _btn_send, _btn_all]:
		if btn == null:
			continue
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.12, 0.45, 0.28)
		s.set_corner_radius_all(6)
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		btn.add_theme_stylebox_override("normal", s)
		var h := s.duplicate()
		h.bg_color = Color(0.18, 0.58, 0.35)
		btn.add_theme_stylebox_override("hover", h)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", 14)

func _refresh_balance() -> void:
	if balance_label:
		balance_label.text = "Saldo: $%.2f" % GameManager.money
	if _progress_label:
		_progress_label.text = "Progreso escape: $%.2f / $%.0f" % [
			GameManager.escape_transferred, GameManager.MONEY_GOAL
		]
	if info_label:
		info_label.text = "Transfiere a la cuenta del correo.\nMeta de escape: $%.0f" % GameManager.MONEY_GOAL

func _set_method(m: String) -> void:
	preferred_method = m
	if method_label:
		method_label.text = "Método preferido: Efectivo" if m == "cash" else "Método preferido: Transferencia"
	if _transfer_box:
		_transfer_box.visible = (m == "transfer")
	if status_label:
		if m == "transfer":
			status_label.text = "Introduce la cuenta y la cantidad, luego Transferir."
		else:
			status_label.text = "Efectivo no sirve para el escape. Usa Transferencia."
		status_label.add_theme_color_override("font_color", Color(0.1, 0.35, 0.2))

func _on_fill_all() -> void:
	if SoundSystem:
		SoundSystem.play_click(true)
	if _amount_edit == null:
		return
	# Redondeo a 2 decimales hacia abajo para no superar el saldo
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
		_set_status("Introduce el número de cuenta del correo.", false)
		return
	if amount < 0.0:
		_set_status("Cantidad no válida.", false)
		return
	if amount <= 0.0:
		_set_status("La cantidad debe ser mayor que 0.", false)
		return
	# Permitir transferir hasta el saldo completo (tolerancia 1 céntimo)
	if amount > GameManager.money + 0.011:
		_set_status("Saldo insuficiente (tienes $%.2f)." % GameManager.money, false)
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
