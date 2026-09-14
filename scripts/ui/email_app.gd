extends Control
## EmailApp — Bandeja de correo (escena separada)

@onready var header: Label = $EmailHeader
@onready var list: ItemList = $EmailList
@onready var body: Label = $EmailBody

var _ids: Array = []

func _ready() -> void:
	list.item_selected.connect(_on_selected)
	header.add_theme_color_override("font_color", Color(0.0, 0.0, 0.45))
	header.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	body.add_theme_font_size_override("font_size", 15)
	refresh()
	if not EmailSystem.emails_changed.is_connected(refresh):
		EmailSystem.emails_changed.connect(refresh)
	if not GameManager.sanity_changed.is_connected(_on_sanity):
		GameManager.sanity_changed.connect(_on_sanity)

func _on_sanity(_s: float) -> void:
	refresh()

func refresh() -> void:
	var unread: int = EmailSystem.unread_count()
	header.text = "Correo  |  Sin leer: %d  |  Cordura: %d%%" % [unread, int(GameManager.sanity)]
	list.clear()
	_ids.clear()
	var inbox: Array = EmailSystem.get_inbox()
	for mail in inbox:
		var id: String = str(mail.get("id", ""))
		_ids.append(id)
		var mark: String = " " if EmailSystem.is_read(id) else "*"
		var fake: String = " [!?]" if bool(mail.get("is_fake", false)) else ""
		list.add_item("%s %s%s" % [mark, str(mail.get("subject", "")), fake])
	body.text = "Selecciona un correo"

func _on_selected(idx: int) -> void:
	if idx < 0 or idx >= _ids.size():
		return
	var email_id: String = str(_ids[idx])
	EmailSystem.mark_read(email_id)
	for mail in EmailSystem.EMAILS:
		if str(mail["id"]) != email_id:
			continue
		var fake_note: String = "\n\n---\n(Este mensaje podria ser falso.)" if bool(mail.get("is_fake", false)) else ""
		body.text = "De: %s\n\n%s%s" % [str(mail.get("from", "")), str(mail.get("body", "")), fake_note]
		break
	refresh()
	# re-select after refresh
	if idx < list.item_count:
		list.select(idx)
