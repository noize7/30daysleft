extends Control
## Alias / respaldo — usar scripts/apps/files_app.gd

@onready var header: Label = get_node_or_null("FilesHeader")
@onready var list: ItemList = get_node_or_null("ClueList")
@onready var body: Label = get_node_or_null("ClueBody")

func _ready() -> void:
	if header:
		header.text = "Archivos"
		header.add_theme_color_override("font_color", Color(0.0, 0.15, 0.45))
		header.add_theme_font_size_override("font_size", 20)
