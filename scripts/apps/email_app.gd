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
	"police": "res://assets/Icons Pc/Police.png",
}
var _icon_cache: Dictionary = {}

@onready var header: Label = $Root/Header
@onready var email_list: ItemList = $Root/MainRow/EmailList
@onready var email_body: Label = $Root/MainRow/RightCol/EmailBody
@onready var _right_col: VBoxContainer = $Root/MainRow/RightCol
@onready var _copy_row: HBoxContainer = $Root/MainRow/RightCol/CopyRow
@onready var _copy_btn: Button = $Root/MainRow/RightCol/CopyRow/CopyBtn
@onready var _copy_hint: Label = $Root/MainRow/RightCol/CopyRow/CopyHint

var _email_ids: Array = []
var _current_account: String = ""
var _paranoia_distorted_id: String = ""

func _ready() -> void:
	_style()
	if _copy_btn and not _copy_btn.pressed.is_connected(_on_copy_account):
		_copy_btn.pressed.connect(_on_copy_account)
	if _copy_row:
		_copy_row.visible = false
	if email_list and not email_list.item_selected.is_connected(_on_selected):
		email_list.item_selected.connect(_on_selected)
	if not EmailSystem.emails_changed.is_connected(refresh):
		EmailSystem.emails_changed.connect(refresh)
	if ParanoiaSystem and not ParanoiaSystem.paranoia_event.is_connected(_on_paranoia_event):
		ParanoiaSystem.paranoia_event.connect(_on_paranoia_event)
	GameManager.sanity_changed.connect(func(_s): refresh())
	if LocaleSystem and not LocaleSystem.language_changed.is_connected(_on_lang):
		LocaleSystem.language_changed.connect(_on_lang)
	refresh()

func _on_lang(_lang: String) -> void:
	if _copy_btn:
		_copy_btn.tooltip_text = LocaleSystem.t("email.copy_tooltip", "Copiar número de cuenta") if LocaleSystem else "Copiar número de cuenta"
	if _copy_hint:
		_copy_hint.text = LocaleSystem.t("email.copy_account", "Copiar cuenta") if LocaleSystem else "Copiar cuenta"
	refresh()

func _style() -> void:
	if header:
		header.add_theme_color_override("font_color", Color(0.0, 0.0, 0.45))
		header.add_theme_font_size_override("font_size", 30)
	if email_body:
		email_body.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12))
		email_body.add_theme_font_size_override("font_size", 24)
		email_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		email_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		email_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		email_body.clip_text = false
	if email_list:
		email_list.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12))
		email_list.add_theme_font_size_override("font_size", 24)
		email_list.fixed_icon_size = Vector2i(48, 48)
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
		_copy_btn.add_theme_font_size_override("font_size", 19)

func _icon_for(type_name: String) -> Texture2D:
	if _icon_cache.has(type_name):
		return _icon_cache[type_name]
	var path: String = TYPE_ICON_PATHS.get(type_name, TYPE_ICON_PATHS["text"])
	var tex: Texture2D = load(path) as Texture2D
	_icon_cache[type_name] = tex
	return tex

func _on_paranoia_event(event_type: String) -> void:
	if event_type != "email_echo":
		return
	if _current_account.is_empty() and _email_ids.is_empty():
		return
	var selected := email_list.get_selected_items() if email_list else PackedInt32Array()
	if selected.size() == 0 or selected[0] < 0 or selected[0] >= _email_ids.size():
		return
	var email_id := str(_email_ids[selected[0]])
	if _paranoia_distorted_id == email_id:
		return
	_paranoia_distorted_id = email_id
	if email_body:
		email_body.text += (LocaleSystem.t("email.interference", "\n\n[INTERFERENCIA]\n¿Por qué sigues buscando?") if LocaleSystem else "\n\n[INTERFERENCIA]\n¿Por qué sigues buscando?")
		email_body.add_theme_color_override("font_color", Color(0.45, 0.08, 0.18))

func refresh() -> void:
	if header:
		var hdr_fmt: String = LocaleSystem.t("email.inbox", "Correo  |  Sin leer: %d  |  C:%d%%") if LocaleSystem else "Correo  |  Sin leer: %d  |  C:%d%%"
		header.text = hdr_fmt % [EmailSystem.unread_count(), int(GameManager.sanity)]
	if email_list == null:
		return
	email_list.clear()
	_email_ids.clear()
	var inbox: Array = EmailSystem.get_inbox()
	for mail in inbox:
		var id: String = str(mail.get("id", ""))
		_email_ids.append(id)
		var mark: String = " " if EmailSystem.is_read(id) else "*"
		var fake_mark: String = " ⚠" if bool(mail.get("is_fake", false)) else ""
		var icon: Texture2D = _icon_for(str(mail.get("type", "text")))
		var subj: String = LocaleSystem.field(mail, "subject", str(mail.get("subject", "?"))) if LocaleSystem else str(mail.get("subject", "?"))
		email_list.add_item("%s %s%s" % [mark, subj, fake_mark], icon)

func _on_selected(idx: int) -> void:
	if idx < 0 or idx >= _email_ids.size():
		return
	if SoundSystem:
		SoundSystem.play_click(true)
	var email_id: String = str(_email_ids[idx])
	_paranoia_distorted_id = ""
	EmailSystem.mark_read(email_id)
	_current_account = ""
	var show_copy := false
	for mail in EmailSystem.EMAILS:
		if str(mail["id"]) != email_id:
			continue
		if email_body:
			var is_fake: bool = bool(mail.get("is_fake", false))
			var truth_header: String = ""
			if is_fake:
				truth_header = (LocaleSystem.t("email.fake_header", "⚠ POSIBLE ALUCINACIÓN — este mensaje puede no ser real\n\n") if LocaleSystem else "⚠ POSIBLE ALUCINACIÓN — este mensaje puede no ser real\n\n")
				email_body.add_theme_color_override("font_color", Color(0.55, 0.12, 0.18))
			else:
				truth_header = (LocaleSystem.t("email.verified_header", "✓ VERIFICADO por el sistema\n\n") if LocaleSystem else "✓ VERIFICADO por el sistema\n\n")
				email_body.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12))
			var fake_note: String = (LocaleSystem.t("email.fake_note", "\n\n— — —\nEste correo no aparece en los logs del servidor.") if LocaleSystem else "\n\n— — —\nEste correo no aparece en los logs del servidor.") if is_fake else ""
			var from_lbl: String = LocaleSystem.t("email.from", "De:") if LocaleSystem else "De:"
			var body_txt: String = LocaleSystem.field(mail, "body", str(mail.get("body", ""))) if LocaleSystem else str(mail.get("body", ""))
			var from_txt: String = LocaleSystem.field(mail, "from", str(mail.get("from", ""))) if LocaleSystem else str(mail.get("from", ""))
			email_body.text = "%s%s %s\n\n%s%s" % [truth_header, from_lbl, from_txt, body_txt, fake_note]
		# Cuenta de escape: mostrar botón copiar
		if email_id == EmailSystem.ESCAPE_MAIL_ID:
			_current_account = GameManager.escape_account_number
			show_copy = not _current_account.is_empty()
		break
	if _copy_row:
		_copy_row.visible = show_copy
	if _copy_hint:
		_copy_hint.text = LocaleSystem.t("email.copy_account", "Copiar cuenta") if LocaleSystem else "Copiar cuenta"
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
		_copy_hint.text = LocaleSystem.t("email.copied", "¡Copiado!") if LocaleSystem else "¡Copiado!"
		_copy_hint.add_theme_color_override("font_color", Color(0.1, 0.55, 0.2))
