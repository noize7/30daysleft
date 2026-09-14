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
	"police": "res://assets/Icons Pc/Policia.png",
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
var _preview_image: TextureRect = null

func _ready() -> void:
	_style()
	_ensure_preview_image()
	if header:
		header.text = "Archivos"
	if clue_list and not clue_list.item_selected.is_connected(_on_selected):
		clue_list.item_selected.connect(_on_selected)
	if not ClueSystem.clues_changed.is_connected(refresh):
		ClueSystem.clues_changed.connect(refresh)
	if not GameManager.upgrade_changed.is_connected(_on_upg):
		GameManager.upgrade_changed.connect(_on_upg)
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
		header.text = "Archivos"
		header.add_theme_color_override("font_color", Color(0.0, 0.15, 0.45))
		header.add_theme_font_size_override("font_size", 26)
	if status_label:
		status_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
		status_label.add_theme_font_size_override("font_size", 18)
	if body_title:
		body_title.add_theme_color_override("font_color", Color(0.12, 0.12, 0.28))
		body_title.add_theme_font_size_override("font_size", 20)
	if clue_body:
		clue_body.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
		clue_body.add_theme_font_size_override("font_size", 19)
	if clue_list:
		clue_list.add_theme_font_size_override("font_size", 19)
		clue_list.fixed_icon_size = Vector2i(30, 30)
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

func refresh() -> void:
	if header:
		header.text = "Archivos"
	if status_label:
		var ram_ok := UpgradeSystem.has_hidden_files_access()
		status_label.text = "Leídas: %d  ·  Para escapar: %d  ·  %s" % [
			ClueSystem.read_count(),
			ClueSystem.CLUES_NEEDED_FOR_ESCAPE,
			"Ocultos OK" if ram_ok else "Ocultos: RAM 8GB"
		]
	if clue_list == null:
		return
	clue_list.clear()
	_clue_ids.clear()
	var available: Array = ClueSystem.get_available()
	for clue in available:
		var id: String = str(clue.get("id", ""))
		_clue_ids.append(id)
		var mark: String = "✓ " if ClueSystem.is_read(id) else "• "
		var icon: Texture2D = _icon_for(clue)
		clue_list.add_item("%s%s" % [mark, str(clue.get("title", "?"))], icon)
	if body_title and (body_title.text.is_empty() or body_title.text == "Vista previa"):
		body_title.text = "Vista previa"
	if clue_body and clue_body.text.is_empty():
		clue_body.text = "Selecciona un archivo de la lista."

func _on_selected(idx: int) -> void:
	if idx < 0 or idx >= _clue_ids.size():
		return
	var clue_id: String = str(_clue_ids[idx])
	ClueSystem.mark_read(clue_id)
	for clue in ClueSystem.CLUES:
		if str(clue.get("id", "")) != clue_id:
			continue
		if body_title:
			body_title.text = str(clue.get("title", ""))
		if clue_body:
			clue_body.text = str(clue.get("body", clue.get("text", "")))
		# Imagen de la pista (foto rota, etc.) con escala uniforme
		_show_clue_image(clue_id)
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
