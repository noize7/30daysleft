extends Control

func _ready() -> void:
	$Header.add_theme_color_override("font_color", Color(0, 0, 0.45))
	$Header.add_theme_font_size_override("font_size", 17)
	$EmailBody.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	$EmailList.item_selected.connect(_on_selected)
	set_meta("email_ids", [])
	_refresh()
	if not EmailSystem.emails_changed.is_connected(_refresh):
		EmailSystem.emails_changed.connect(_refresh)
	if not GameManager.sanity_changed.is_connected(_on_sanity):
		GameManager.sanity_changed.connect(_on_sanity)

func _on_sanity(_s: float) -> void:
	_refresh()

func _refresh() -> void:
	var unread: int = EmailSystem.unread_count()
	$Header.text = "Correo  |  No leidos: %d  |  Cordura: %d%%" % [unread, int(GameManager.sanity)]
	var list: ItemList = $EmailList
	list.clear()
	var ids: Array = []
	var inbox: Array = EmailSystem.get_inbox()
	for mail in inbox:
		var id: String = str(mail.get("id", ""))
		ids.append(id)
		var mark: String = " " if EmailSystem.is_read(id) else "*"
		list.add_item("%s %s" % [mark, str(mail.get("subject", "?"))])
	set_meta("email_ids", ids)

func _on_selected(idx: int) -> void:
	var ids: Array = get_meta("email_ids", [])
	if idx < 0 or idx >= ids.size():
		return
	var email_id: String = str(ids[idx])
	EmailSystem.mark_read(email_id)
	for mail in EmailSystem.EMAILS:
		if str(mail["id"]) != email_id:
			continue
		var fake_note: String = "\n\n---\n(Este mensaje podria ser falso.)" if bool(mail.get("is_fake", false)) else ""
		$EmailBody.text = "De: %s\n\n%s%s" % [str(mail.get("from", "")), str(mail.get("body", "")), fake_note]
		break
	_refresh()
