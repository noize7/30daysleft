extends Control
## EmailApp — bandeja de correo + botón copiar en cuenta de escape

const TYPE_ICON_PATHS := {
	"system": "res://assets/Icons Pc/Mensajes.png",
	"job": "res://assets/Icons Pc/Portafolio.png",
	"text": "res://assets/Icons Pc/txt-file.png",
	"document": "res://assets/Icons Pc/PDF-File.png",
	"folder": "res://assets/Icons Pc/carpeta.png",
	"photo": "res://assets/Icons Pc/foto.png",
	"audio": "res://assets/Icons Pc/Musica.png",
	"warning": "res://assets/Icons Pc/Advertencia.png",
	"medical": "res://assets/Icons Pc/medico.png",
	"key": "res://assets/Icons Pc/llave.png",
	"locked": "res://assets/Icons Pc/Candado.png",
	"police": "res://assets/Icons Pc/Policia.png",
}
var _icon_cache: Dictionary = {}

@onready var header: Label = $Root/Header
@onready var email_list: ItemList = $Root/MainRow/EmailList
@onready var email_body: Label = $Root/MainRow/EmailBody

var _email_ids: Array = []
var _copy_btn: Button = null
var _copy_hint: Label = null
var _current_account: String = ""
var _right_col: VBoxContainer = null

func _ready() -> void:
	_ensure_right_col()
	_style()
	if email_list and not email_list.item_selected.is_connected(_on_selected):
		email_list.item_selected.connect(_on_selected)
	if not EmailSystem.emails_changed.is_connected(refresh):
		EmailSystem.emails_changed.connect(refresh)
	GameManager.sanity_changed.connect(func(_s): refresh())
	refresh()

func _ensure_right_col() -> void:
	var main_row: Control = get_node_or_null("Root/MainRow")
	if main_row == null:
		return
	# Migrar EmailBody suelto a RightCol si hace falta
	var existing_body = main_row.get_node_or_null("EmailBody")
	_right_col = main_row.get_node_or_null("RightCol") as VBoxContainer
	if _right_col == null:
		_right_col = VBoxContainer.new()
		_right_col.name = "RightCol"
		_right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_right_col.add_theme_constant_override("separation", 6)
		main_row.add_child(_right_col)
		if existing_body:
			existing_body.reparent(_right_col)
			email_body = existing_body
	if email_body == null:
		email_body = _right_col.get_node_or_null("EmailBody") as Label
	if email_body == null:
		email_body = Label.new()
		email_body.name = "EmailBody"
		email_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		email_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		email_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_right_col.add_child(email_body)

	# Fila: botón copiar (solo icono) + hint
	var copy_row: HBoxContainer = _right_col.get_node_or_null("CopyRow") as HBoxContainer
	if copy_row == null:
		copy_row = HBoxContainer.new()
		copy_row.name = "CopyRow"
		copy_row.add_theme_constant_override("separation", 6)
		_right_col.add_child(copy_row)
		_right_col.move_child(copy_row, 0)

	_copy_btn = copy_row.get_node_or_null("CopyBtn") as Button
	if _copy_btn == null:
		_copy_btn = Button.new()
		_copy_btn.name = "CopyBtn"
		_copy_btn.text = "📋"
		_copy_btn.tooltip_text = "Copiar número de cuenta"
		_copy_btn.custom_minimum_size = Vector2(28, 28)
		_copy_btn.focus_mode = Control.FOCUS_NONE
		_copy_btn.pressed.connect(_on_copy_account)
		copy_row.add_child(_copy_btn)
	_copy_hint = copy_row.get_node_or_null("CopyHint") as Label
	if _copy_hint == null:
		_copy_hint = Label.new()
		_copy_hint.name = "CopyHint"
		_copy_hint.text = "Copiar cuenta"
		_copy_hint.add_theme_font_size_override("font_size", 12)
		_copy_hint.add_theme_color_override("font_color", Color(0.25, 0.35, 0.25))
		copy_row.add_child(_copy_hint)
	copy_row.visible = false

func _style() -> void:
	if header:
		header.add_theme_color_override("font_color", Color(0.0, 0.0, 0.45))
		header.add_theme_font_size_override("font_size", 24)
	if email_body:
		email_body.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12))
		email_body.add_theme_font_size_override("font_size", 16)
		email_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		email_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		email_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		email_body.clip_text = false
	if email_list:
		email_list.add_theme_font_size_override("font_size", 17)
		email_list.fixed_icon_size = Vector2i(28, 28)
		email_list.icon_mode = ItemList.ICON_MODE_LEFT
	if _copy_btn:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.15, 0.45, 0.28)
		s.set_corner_radius_all(4)
		s.content_margin_left = 4
		s.content_margin_right = 4
		s.content_margin_top = 2
		s.content_margin_bottom = 2
		_copy_btn.add_theme_stylebox_override("normal", s)
		var h := s.duplicate()
		h.bg_color = Color(0.2, 0.55, 0.35)
		_copy_btn.add_theme_stylebox_override("hover", h)
		_copy_btn.add_theme_font_size_override("font_size", 14)

func _icon_for(type_name: String) -> Texture2D:
	if _icon_cache.has(type_name):
		return _icon_cache[type_name]
	var path: String = TYPE_ICON_PATHS.get(type_name, TYPE_ICON_PATHS["text"])
	var tex: Texture2D = load(path) as Texture2D
	_icon_cache[type_name] = tex
	return tex

func refresh() -> void:
	if header:
		header.text = "Correo  |  Sin leer: %d  |  C:%d%%" % [EmailSystem.unread_count(), int(GameManager.sanity)]
	if email_list == null:
		return
	email_list.clear()
	_email_ids.clear()
	var inbox: Array = EmailSystem.get_inbox()
	for mail in inbox:
		var id: String = str(mail.get("id", ""))
		_email_ids.append(id)
		var mark: String = " " if EmailSystem.is_read(id) else "*"
		var icon: Texture2D = _icon_for(str(mail.get("type", "text")))
		email_list.add_item("%s %s" % [mark, str(mail.get("subject", "?"))], icon)

func _on_selected(idx: int) -> void:
	if idx < 0 or idx >= _email_ids.size():
		return
	if SoundSystem:
		SoundSystem.play_click(true)
	var email_id: String = str(_email_ids[idx])
	EmailSystem.mark_read(email_id)
	_current_account = ""
	var show_copy := false
	for mail in EmailSystem.EMAILS:
		if str(mail["id"]) != email_id:
			continue
		if email_body:
			var fake_note: String = "\n\n(Posible alucinación.)" if bool(mail.get("is_fake", false)) else ""
			email_body.text = "De: %s\n\n%s%s" % [str(mail.get("from", "")), str(mail.get("body", "")), fake_note]
		# Cuenta de escape: mostrar botón copiar
		if email_id == EmailSystem.ESCAPE_MAIL_ID:
			_current_account = GameManager.escape_account_number
			show_copy = not _current_account.is_empty()
		break
	if _copy_btn and _copy_btn.get_parent():
		_copy_btn.get_parent().visible = show_copy
	if _copy_hint:
		_copy_hint.text = "Copiar cuenta"
		_copy_hint.add_theme_color_override("font_color", Color(0.25, 0.35, 0.25))
	refresh()

func _on_copy_account() -> void:
	if SoundSystem:
		SoundSystem.play_button()
	if _current_account.is_empty():
		_current_account = GameManager.escape_account_number
	if _current_account.is_empty():
		return
	DisplayServer.clipboard_set(_current_account)
	if _copy_hint:
		_copy_hint.text = "¡Copiado!"
		_copy_hint.add_theme_color_override("font_color", Color(0.1, 0.55, 0.2))
