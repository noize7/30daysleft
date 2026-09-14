extends Control
## ShopApp — Mejoras (escena separada, editable en el editor)

@onready var shop_title: Label = $ShopTitle
@onready var shop_money: Label = $ShopMoney
@onready var shop_list: ItemList = $ShopList
@onready var shop_details: Label = $RightCol/ShopDetails
@onready var buy_button: Button = $RightCol/BuyButton
@onready var shop_feedback: Label = $ShopFeedback
@onready var shop_goal: Label = $ShopGoal

var _selected_idx: int = 0

func _ready() -> void:
	shop_list.item_selected.connect(_on_selected)
	buy_button.pressed.connect(_on_buy)
	_style()
	refresh()
	if not GameManager.money_changed.is_connected(_on_money):
		GameManager.money_changed.connect(_on_money)
	if not GameManager.upgrade_changed.is_connected(_on_upgrade):
		GameManager.upgrade_changed.connect(_on_upgrade)

func _style() -> void:
	shop_title.add_theme_color_override("font_color", Color(0.0, 0.0, 0.45))
	shop_title.add_theme_font_size_override("font_size", 18)
	shop_money.add_theme_color_override("font_color", Color(0.0, 0.4, 0.0))
	shop_money.add_theme_font_size_override("font_size", 16)
	shop_details.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	shop_details.add_theme_font_size_override("font_size", 14)
	shop_goal.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
	shop_goal.add_theme_font_size_override("font_size", 13)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.141, 0.369, 0.863)
	bs.set_corner_radius_all(4)
	buy_button.add_theme_stylebox_override("normal", bs)
	var bh := bs.duplicate()
	bh.bg_color = Color(0.235, 0.506, 0.953)
	buy_button.add_theme_stylebox_override("hover", bh)
	buy_button.add_theme_color_override("font_color", Color.WHITE)
	buy_button.add_theme_font_size_override("font_size", 16)

func _on_money(_m: float) -> void:
	refresh()

func _on_upgrade(_c: String, _l: int) -> void:
	refresh()

func refresh() -> void:
	if not is_instance_valid(shop_list):
		return
	shop_money.text = "Dinero disponible: $%.0f" % GameManager.money
	shop_list.clear()
	for cat in UpgradeSystem.CATEGORY_ORDER:
		shop_list.add_item(UpgradeSystem.get_status_line(cat))
	if UpgradeSystem.CATEGORY_ORDER.size() > 0:
		_selected_idx = clampi(_selected_idx, 0, UpgradeSystem.CATEGORY_ORDER.size() - 1)
		shop_list.select(_selected_idx)
		_on_selected(_selected_idx)

func _on_selected(idx: int) -> void:
	_selected_idx = idx
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
		var cost: int = int(nxt.get("cost", 0))
		buy_button.disabled = GameManager.money < float(cost)
		buy_button.text = "Comprar ($%d)" % cost
	else:
		txt += "\n\n(Nivel maximo)"
		buy_button.disabled = true
		buy_button.text = "Nivel maximo"
	shop_details.text = txt

func _on_buy() -> void:
	if _selected_idx < 0 or _selected_idx >= UpgradeSystem.CATEGORY_ORDER.size():
		return
	var cat: String = UpgradeSystem.CATEGORY_ORDER[_selected_idx]
	var ok: bool = UpgradeSystem.try_buy(cat)
	if ok:
		shop_feedback.add_theme_color_override("font_color", Color(0.0, 0.45, 0.0))
		shop_feedback.text = "Compra: %s" % UpgradeSystem.CATEGORY_LABELS.get(cat, cat)
	else:
		shop_feedback.add_theme_color_override("font_color", Color(0.6, 0.0, 0.0))
		shop_feedback.text = "No se pudo comprar"
	refresh()
