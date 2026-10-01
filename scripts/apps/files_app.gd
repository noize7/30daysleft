extends Control
## FilesApp — Explorador de pistas (Tanda 6+)

## Icono pequeño mostrado junto a cada archivo según su "type".
const TYPE_ICON_PATHS := {
	"system": "res://assets/Icons Pc/pc.png",
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

## Imágenes grandes de pistas concretas (id → ruta).
const CLUE_IMAGE_PATHS := {
	"clue_photo": "res://assets/clues/foto_rota.png",
}

var _icon_cache: Dictionary = {}
var _image_cache: Dictionary = {}

@onready var header: Label = $Root/Header
@onready var status_label: Label = $Root/StatusLabel
@onready var clue_list: ItemList = $Root/MainRow/ClueList
@onready var body_title: Label = $Root/MainRow/RightCol/BodyTitle
@onready var clue_body: Label = $Root/MainRow/RightCol/ClueBody

var _clue_ids: Array = []
var _entry_types: Array[String] = []
var _preview_image: TextureRect = null
var _password_dialog: ConfirmationDialog = null
var _password_edit: LineEdit = null
var _pending_story_file_id: String = ""
var _paranoia_fake_active: bool = false
var _paranoia_fake_generation: int = 0

func _ready() -> void:
	_style()
	_ensure_preview_image()
	if header:
		header.text = LocaleSystem.t("desktop.files", "Archivos") if LocaleSystem else "Archivos"
	if clue_list and not clue_list.item_selected.is_connected(_on_selected):
		clue_list.item_selected.connect(_on_selected)
	if clue_list and clue_list.has_signal("item_clicked") and not clue_list.item_clicked.is_connected(_on_item_clicked):
		clue_list.item_clicked.connect(_on_item_clicked)
	if not ClueSystem.clues_changed.is_connected(refresh):
		ClueSystem.clues_changed.connect(refresh)
	if not GameManager.upgrade_changed.is_connected(_on_upg):
		GameManager.upgrade_changed.connect(_on_upg)
	if InvestigationSystem and not InvestigationSystem.investigation_changed.is_connected(refresh):
		InvestigationSystem.investigation_changed.connect(refresh)
	if ParanoiaSystem and not ParanoiaSystem.paranoia_event.is_connected(_on_paranoia_event):
		ParanoiaSystem.paranoia_event.connect(_on_paranoia_event)
	_ensure_password_dialog()
	refresh()

func _on_upg(_c: String, _l: int) -> void:
	refresh()

func _ensure_preview_image() -> void:
	var right: Control = get_node_or_null("Root/MainRow/RightCol")
	if right == null:
		return
	if right.get_node_or_null("PreviewImage") != null:
		_preview_image = right.get_node("PreviewImage")
		return
	_preview_image = TextureRect.new()
	_preview_image.name = "PreviewImage"
	_preview_image.visible = false
	_preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_image.custom_minimum_size = Vector2(0, 140)
	_preview_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Insertar después del título
	right.add_child(_preview_image)
	if body_title:
		right.move_child(_preview_image, body_title.get_index() + 1)

func _style() -> void:
	if header:
		header.text = LocaleSystem.t("desktop.files", "Archivos") if LocaleSystem else "Archivos"
		header.add_theme_color_override("font_color", Color(0.0, 0.15, 0.45))
		header.add_theme_font_size_override("font_size", 35)
	if status_label:
		status_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
		status_label.add_theme_font_size_override("font_size", 24)
	if body_title:
		body_title.add_theme_color_override("font_color", Color(0.12, 0.12, 0.28))
		body_title.add_theme_font_size_override("font_size", 27)
	if clue_body:
		clue_body.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
		clue_body.add_theme_font_size_override("font_size", 24)
	if clue_list:
		clue_list.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12))
		clue_list.add_theme_font_size_override("font_size", 30)
		clue_list.fixed_icon_size = Vector2i(48, 48)
		clue_list.icon_mode = ItemList.ICON_MODE_LEFT

func _icon_for(clue: Dictionary) -> Texture2D:
	# Foto rota: siempre el icono foto.png en la lista
	if str(clue.get("id", "")) == "clue_photo":
		var key_photo := "photo_list_icon"
		if _icon_cache.has(key_photo):
			return _icon_cache[key_photo]
		var photo_path := "res://assets/Icons Pc/foto.png"
		if ResourceLoader.exists(photo_path):
			var tex_p: Texture2D = load(photo_path) as Texture2D
			_icon_cache[key_photo] = tex_p
			return tex_p
	var key: String = "locked" if bool(clue.get("hidden", false)) and not UpgradeSystem.has_hidden_files_access() else str(clue.get("type", "text"))
	if _icon_cache.has(key):
		return _icon_cache[key]
	var path: String = TYPE_ICON_PATHS.get(key, TYPE_ICON_PATHS["text"])
	var tex: Texture2D = load(path) as Texture2D
	_icon_cache[key] = tex
	return tex

func _image_for_clue(clue_id: String) -> Texture2D:
	if not CLUE_IMAGE_PATHS.has(clue_id):
		return null
	if _image_cache.has(clue_id):
		return _image_cache[clue_id]
	var path: String = str(CLUE_IMAGE_PATHS[clue_id])
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	_image_cache[clue_id] = tex
	return tex

func _ensure_password_dialog() -> void:
	if _password_dialog != null and is_instance_valid(_password_dialog):
		return
	_password_dialog = ConfirmationDialog.new()
	_password_dialog.name = "StoryFilePasswordDialog"
	_password_dialog.title = LocaleSystem.t("files.locked", "Archivo protegido") if LocaleSystem else "Archivo protegido"
	_password_dialog.ok_button_text = LocaleSystem.t("files.confirm", "Confirmar") if LocaleSystem else "Confirmar"
	_password_dialog.cancel_button_text = LocaleSystem.t("files.cancel", "Cancelar") if LocaleSystem else "Cancelar"
	_password_dialog.dialog_hide_on_ok = true
	# Tamaño compacto legible
	_password_dialog.min_size = Vector2(360, 0)
	var box := VBoxContainer.new()
	box.name = "VBoxContainer"
	box.add_theme_constant_override("separation", 10)
	var info := Label.new()
	info.name = "Info"
	info.text = LocaleSystem.t("files.enter_password", "Introduce la contraseña.") if LocaleSystem else "Introduce la contraseña."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(320, 0)
	info.add_theme_font_size_override("font_size", 22)
	box.add_child(info)
	_password_edit = LineEdit.new()
	_password_edit.name = "Password"
	_password_edit.placeholder_text = LocaleSystem.t("files.password", "Contraseña") if LocaleSystem else "Contraseña"
	_password_edit.secret = true
	_password_edit.max_length = 32
	_password_edit.custom_minimum_size = Vector2(320, 36)
	_password_edit.add_theme_font_size_override("font_size", 24)
	_password_edit.text_submitted.connect(func(_t): _password_dialog.get_ok_button().pressed.emit())
	box.add_child(_password_edit)
	_password_dialog.add_child(box)
	add_child(_password_dialog)
	_password_dialog.confirmed.connect(_on_password_confirmed)
	if not _password_dialog.canceled.is_connected(_on_password_canceled):
		_password_dialog.canceled.connect(_on_password_canceled)
	if not _password_dialog.close_requested.is_connected(_on_password_canceled):
		_password_dialog.close_requested.connect(_on_password_canceled)

func _show_story_file(file_id: String) -> void:
	if InvestigationSystem == null:
		return
	var file_data := InvestigationSystem.get_file(file_id)
	if file_data.is_empty():
		return
	if InvestigationSystem.is_file_read(file_id):
		_open_story_file(file_id)
		return
	var method := str(file_data.get("unlock_method", "flag"))
	if method == "password":
		_pending_story_file_id = file_id
		if _password_edit:
			_password_edit.text = ""
		var info := _password_dialog.get_node_or_null("VBoxContainer/Info") as Label
		if info:
			info.text = "%s\nContraseña de otra pista." % str(file_data.get("title", file_id))
		_password_dialog.popup_centered(Vector2(380, 160))
		if _password_edit:
			_password_edit.grab_focus()
		return
	_open_story_file(file_id)

func _on_password_confirmed() -> void:
	if _pending_story_file_id.is_empty() or InvestigationSystem == null:
		return
	var fid := _pending_story_file_id
	var result := InvestigationSystem.try_open_file(fid, _password_edit.text if _password_edit else "")
	if bool(result.get("ok", false)):
		_pending_story_file_id = ""
		_show_story_result(result)
		_deselect_list()
	else:
		# Contraseña incorrecta: mantener pendiente y permitir reintentar
		if status_label:
			status_label.text = str(result.get("message", LocaleSystem.t("files.wrong_password", "Contraseña incorrecta.") if LocaleSystem else "Contraseña incorrecta."))
			status_label.add_theme_color_override("font_color", Color(0.7, 0.15, 0.1))
		if _password_edit:
			_password_edit.text = ""
			_password_edit.grab_focus()
		# Volver a abrir el diálogo para reintentar
		if _password_dialog:
			_password_dialog.call_deferred("popup_centered")

func _on_password_canceled() -> void:
	_pending_story_file_id = ""
	if status_label:
		status_label.text = LocaleSystem.t("files.locked_hint", "Archivo bloqueado — vuelve a abrirlo cuando tengas la contraseña.") if LocaleSystem else "Archivo bloqueado — vuelve a abrirlo cuando tengas la contraseña."
		status_label.add_theme_color_override("font_color", Color(0.45, 0.35, 0.15))
	_deselect_list()

func _deselect_list() -> void:
	if clue_list:
		clue_list.deselect_all()

func _open_story_file(file_id: String) -> void:
	var result := InvestigationSystem.try_open_file(file_id)
	if bool(result.get("ok", false)):
		_show_story_result(result)
	else:
		if status_label:
			status_label.text = str(result.get("message", "Archivo bloqueado."))
			status_label.add_theme_color_override("font_color", Color(0.7, 0.15, 0.1))

func _show_story_result(result: Dictionary) -> void:
	if body_title:
		body_title.text = str(result.get("title", "Archivo"))
	if clue_body:
		clue_body.text = str(result.get("message", ""))
	_show_clue_image("")
	refresh()

func _on_paranoia_event(event_type: String) -> void:
	if event_type != "fake_file" or not is_visible_in_tree():
		return
	_paranoia_fake_generation += 1
	var generation := _paranoia_fake_generation
	_paranoia_fake_active = true
	refresh()
	if status_label:
		status_label.text = LocaleSystem.t("files.ghost_file", "Se detectó un archivo que no figura en el índice.") if LocaleSystem else "Se detectó un archivo que no figura en el índice."
		status_label.add_theme_color_override("font_color", Color(0.45, 0.08, 0.18))
	await get_tree().create_timer(2.8).timeout
	if generation != _paranoia_fake_generation:
		return
	_paranoia_fake_active = false
	refresh()

func refresh() -> void:
	if header:
		header.text = LocaleSystem.t("desktop.files", "Archivos") if LocaleSystem else "Archivos"
	if status_label:
		var ram_ok := UpgradeSystem.has_hidden_files_access()
		var story_count := InvestigationSystem.get_visible_story_files().size() if InvestigationSystem else 0
		status_label.text = "Leídas: %d  ·  Investigación: %d  ·  %s" % [
			ClueSystem.read_count(),
			story_count,
			"Ocultos OK" if ram_ok else "Ocultos: RAM 8GB"
		]
	if clue_list == null:
		return
	clue_list.clear()
	_clue_ids.clear()
	_entry_types.clear()
	var available: Array = ClueSystem.get_available()
	for clue in available:
		var id: String = str(clue.get("id", ""))
		_clue_ids.append(id)
		_entry_types.append("clue")
		var mark: String = "✓ " if ClueSystem.is_read(id) else "• "
		var truth_mark: String = ""
		if ClueSystem.is_read(id):
			truth_mark = " ✓" if bool(clue.get("is_true", true)) else " ⚠"
		var icon: Texture2D = _icon_for(clue)
		clue_list.add_item("%s%s%s" % [mark, (ClueSystem.localized_title(clue) if ClueSystem and ClueSystem.has_method("localized_title") else str(clue.get("title", "?"))), truth_mark], icon)
	if InvestigationSystem:
		for file_data in InvestigationSystem.get_visible_story_files():
			var id := str(file_data.get("id", ""))
			_clue_ids.append(id)
			_entry_types.append("story")
			var is_read := InvestigationSystem.is_file_read(id)
			var mark := "✓ " if is_read else "🔒 "
			var fake_clue := {"id": id, "type": "locked"}
			clue_list.add_item("%s%s" % [mark, str(file_data.get("title", id))], _icon_for(fake_clue))
	if _paranoia_fake_active:
		_clue_ids.append("__paranoia_fake__")
		_entry_types.append("fake")
		var fake_clue := {"id": "__paranoia_fake__", "type": "locked"}
		clue_list.add_item("⚠ DON'T_LOOK.txt", _icon_for(fake_clue))
	if body_title and (body_title.text.is_empty() or body_title.text == "Vista previa"):
		body_title.text = LocaleSystem.t("files.preview", "Vista previa") if LocaleSystem else "Vista previa"
	if clue_body and clue_body.text.is_empty():
		clue_body.text = LocaleSystem.t("files.select", "Selecciona un archivo de la lista.") if LocaleSystem else "Selecciona un archivo de la lista."


func _on_item_clicked(idx: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	# Permite reabrir el mismo archivo bloqueado aunque ya esté seleccionado
	if idx < 0 or idx >= _clue_ids.size():
		return
	var entry_type := str(_entry_types[idx]) if idx < _entry_types.size() else "clue"
	if entry_type == "story":
		_on_selected(idx)

func _on_selected(idx: int) -> void:
	if idx < 0 or idx >= _clue_ids.size():
		return
	if SoundSystem:
		SoundSystem.play_click(true)
	var file_id := str(_clue_ids[idx])
	var entry_type := str(_entry_types[idx]) if idx < _entry_types.size() else "clue"
	if entry_type == "fake":
		if body_title:
			body_title.text = "DON'T_LOOK.txt"
		if clue_body:
			clue_body.text = LocaleSystem.t("files.dont_open", "Este archivo no estaba aquí antes.\n\nNO LO ABRAS.\n\n...ya lo abriste.") if LocaleSystem else "Este archivo no estaba aquí antes.\n\nNO LO ABRAS.\n\n...ya lo abriste."
		_show_clue_image("")
		return
	if entry_type == "story":
		_show_story_file(file_id)
		return
	ClueSystem.mark_read(file_id)
	for clue in ClueSystem.CLUES:
		if str(clue.get("id", "")) != file_id:
			continue
		if body_title:
			var is_true: bool = bool(clue.get("is_true", true))
			var truth_tag: String = " [VERIFICADO]" if is_true else " [¿ALUCINACIÓN?]"
			body_title.text = (ClueSystem.localized_title(clue) if ClueSystem and ClueSystem.has_method("localized_title") else str(clue.get("title", ""))) + truth_tag
			if is_true:
				body_title.add_theme_color_override("font_color", Color(0.08, 0.35, 0.15))
			else:
				body_title.add_theme_color_override("font_color", Color(0.55, 0.12, 0.12))
		if clue_body:
			clue_body.text = (ClueSystem.localized_body(clue) if ClueSystem and ClueSystem.has_method("localized_body") else str(clue.get("body", clue.get("text", ""))))
		_show_clue_image(file_id)
		break
	refresh()


func _show_clue_image(clue_id: String) -> void:
	_ensure_preview_image()
	if _preview_image == null:
		return
	var tex: Texture2D = _image_for_clue(clue_id)
	if tex == null:
		_preview_image.visible = false
		_preview_image.texture = null
		return
	_preview_image.texture = tex
	_preview_image.visible = true
	# Escala uniforme acotada para no romper la ventana (máx ~160px de alto)
	_preview_image.custom_minimum_size = Vector2(0, 160)
	_preview_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_image.clip_contents = true
