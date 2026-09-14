extends Control
## App Mejoras — UI en escena separada (ajustable en el editor)

func _ready() -> void:
	_style()
	$ShopList.item_selected.connect(_on_selected)
	$RightPanel/BuyButton.pressed.connect(_on_buy)
	set_meta("selected_shop_idx", 0)
	_refresh()
	if not GameManager.money_changed.is_connected(_on_money):
		GameManager.money_changed.connect(_on_money)
	if not GameManager.upgrade_changed.is_connected(_on_upgrade):
		GameManager.upgrade_changed.connect(_on_upgrade)

func _style() -> void:
	$ShopTitle.add_theme_color_override("font_color", Color(0.0, 0.0, 0.45))
	$ShopTitle.add_theme_font_size_override("font_size", 18)
	$ShopMoney.add_theme_color_override("font_color", Color(0.0, 0.4, 0.0))
	$ShopMoney.add_theme_font_size_override("font_size", 16)
	$RightPanel/ShopDetails.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12))
	$RightPanel/ShopDetails.add_theme_font_size_override("font_size", 15)
	$ShopGoal.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
	$ShopGoal.add_theme_font_size_override("font_size", 13)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.141, 0.369, 0.863)
	bs.set_corner_radius_all(4)
	$RightPanel/BuyButton.add_theme_stylebox_override("normal", bs)
	var bh := bs.duplicate()
	bh.bg_color = Color(0.235, 0.506, 0.953)
	$RightPanel/BuyButton.add_theme_stylebox_override("hover", bh)
	$RightPanel/BuyButton.add_theme_color_override("font_color", Color.WHITE)

func _on_money(_m: float) -> void:
	_refresh()

func _on_upgrade(_c: String, _l: int) -> void:
	_refresh()

func _refresh() -> void:
	$ShopMoney.text = "Dinero disponible: $%.0f" % GameManager.money
	var list: ItemList = $ShopList
	list.clear()
	for cat in UpgradeSystem.CATEGORY_ORDER:
		list.add_item(UpgradeSystem.get_status_line(cat))
	var sel: int = clampi(int(get_meta("selected_shop_idx", 0)), 0, maxi(0, UpgradeSystem.CATEGORY_ORDER.size() - 1))
	if UpgradeSystem.CATEGORY_ORDER.size() > 0:
		list.select(sel)
		_on_selected(sel)

func _on_selected(idx: int) -> void:
	set_meta("selected_shop_idx", idx)
	if idx < 0 or idx >= UpgradeSystem.CATEGORY_ORDER.size():
		return
	var cat: String = UpgradeSystem.CATEGORY_ORDER[idx]
	var cur: Dictionary = UpgradeSystem.get_current(cat)
	var nxt: Dictionary = UpgradeSystem.get_next(cat)
	var txt: String = "Actual:\n%s\n\n%s" % [str(cur.get("name", "")), str(cur.get("desc", ""))]
	if not nxt.is_empty():
		txt += "\n\nSiguiente:\n%s\n%s\nCoste: $%d" % [
			str(nxt.get("name", "")), str(nxt.get("desc", "")), int(nxt.get("cost", 0))
		]
	else:
		txt += "\n\n(Nivel maximo alcanzado)"
	$RightPanel/ShopDetails.text = txt
	var buy: Button = $RightPanel/BuyButton
	if not UpgradeSystem.can_upgrade(cat):
		buy.disabled = true
		buy.text = "Nivel maximo"
	else:
		var cost: int = UpgradeSystem.get_next_cost(cat)
		buy.disabled = GameManager.money < float(cost)
		buy.text = "Comprar ($%d)" % cost

func _on_buy() -> void:
	var idx: int = int(get_meta("selected_shop_idx", 0))
	if idx < 0 or idx >= UpgradeSystem.CATEGORY_ORDER.size():
		return
	var cat: String = UpgradeSystem.CATEGORY_ORDER[idx]
	var ok: bool = UpgradeSystem.try_buy(cat)
	if ok:
		$ShopFeedback.add_theme_color_override("font_color", Color(0.0, 0.45, 0.0))
		$ShopFeedback.text = "Compra realizada: %s" % UpgradeSystem.CATEGORY_LABELS.get(cat, cat)
	else:
		$ShopFeedback.add_theme_color_override("font_color", Color(0.7, 0.1, 0.1))
		$ShopFeedback.text = "No se pudo comprar (dinero o nivel max)."
	_refresh()
