extends Control

func _ready() -> void:
	$FilesHeader.add_theme_color_override("font_color", Color(0, 0, 0.45))
	$FilesHeader.add_theme_font_size_override("font_size", 17)
	$ClueBody.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	$ClueList.item_selected.connect(_on_selected)
	set_meta("clue_ids", [])
	_refresh()
	if not ClueSystem.clues_changed.is_connected(_refresh):
		ClueSystem.clues_changed.connect(_refresh)
	if not GameManager.upgrade_changed.is_connected(_on_upg):
		GameManager.upgrade_changed.connect(_on_upg)

func _on_upg(_c: String, _l: int) -> void:
	_refresh()

func _refresh() -> void:
	var ram_note := "  |  RAM 8GB: OK" if UpgradeSystem.has_hidden_files_access() else "  |  RAM baja: ocultos bloqueados"
	$FilesHeader.text = "Archivos  |  Pistas %d leidas  |  Escape: %d%s" % [
		ClueSystem.read_count(), ClueSystem.CLUES_NEEDED_FOR_ESCAPE, ram_note
	]
	var list: ItemList = $ClueList
	list.clear()
	var ids: Array = []
	for clue in ClueSystem.get_available():
		var id: String = str(clue.get("id", ""))
		ids.append(id)
		var mark: String = " " if ClueSystem.is_read(id) else "*"
		var hidden: String = " [oculto]" if bool(clue.get("hidden", false)) else ""
		list.add_item("%s %s%s" % [mark, str(clue.get("title", clue.get("name", "?"))), hidden])
	set_meta("clue_ids", ids)
	if ClueSystem.has_locked_hidden():
		list.add_item("(Archivos ocultos — necesita RAM 8GB)")

func _on_selected(idx: int) -> void:
	var ids: Array = get_meta("clue_ids", [])
	if idx < 0 or idx >= ids.size():
		return
	var clue_id: String = str(ids[idx])
	ClueSystem.mark_read(clue_id)
	for clue in ClueSystem.get_available():
		if str(clue.get("id", "")) != clue_id:
			continue
		$ClueBody.text = "%s\n\n%s" % [str(clue.get("title", clue.get("name", ""))), str(clue.get("body", clue.get("text", "")))]
		break
	_refresh()
