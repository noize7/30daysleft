extends Control
## =============================================================================
## ShopApp — UI de Mejoras (escena separada, ajustable en el editor)
## =============================================================================

signal buy_requested(category: String)
signal category_selected(category: String)

@onready var title_label: Label = $Root/TitleLabel
@onready var money_label: Label = $Root/MoneyLabel
@onready var shop_list: ItemList = $Root/HBox/ShopList
@onready var details_label: Label = $Root/HBox/RightCol/ShopDetails
@onready var buy_button: Button = $Root/HBox/RightCol/BuyButton
@onready var feedback_label: Label = $Root/FeedbackLabel
@onready var goal_label: Label = $Root/GoalLabel

var _selected_idx: int = 0
## Escala de iconos de la lista (se puede sobreescribir desde Main / DesktopUI).
var icon_scale: float = 1.0

func _ready() -> void:
	_style()
	if shop_list and not shop_list.item_selected.is_connected(_on_item_selected):
		shop_list.item_selected.connect(_on_item_selected)
	if buy_button and not buy_button.pressed.is_connected(_on_buy):
		buy_button.pressed.connect(_on_buy)
	refresh()

func set_icon_scale(new_scale: float) -> void:
	icon_scale = clampf(new_scale, 0.5, 3.0)
	if shop_list:
		var s: int = int(round(28.0 * icon_scale))
		shop_list.fixed_icon_size = Vector2i(s, s)
	refresh()

func _style() -> void:
	if title_label:
		title_label.add_theme_color_override("font_color", Color(0.0, 0.0, 0.45))
		title_label.add_theme_font_size_override("font_size", 26)
	if money_label:
		money_label.add_theme_color_override("font_color", Color(0.0, 0.4, 0.0))
		money_label.add_theme_font_size_override("font_size", 21)
	if details_label:
		details_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12))
		details_label.add_theme_font_size_override("font_size", 19)
	if feedback_label:
		feedback_label.add_theme_font_size_override("font_size", 19)
	if goal_label:
		goal_label.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
		goal_label.add_theme_font_size_override("font_size", 18)
	if shop_list:
		var s: int = int(round(28.0 * icon_scale))
		shop_list.fixed_icon_size = Vector2i(s, s)
		shop_list.icon_mode = ItemList.ICON_MODE_LEFT
	if buy_button:
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.141, 0.369, 0.863)
		bs.set_corner_radius_all(4)
		bs.content_margin_left = 8
		bs.content_margin_right = 8
		bs.content_margin_top = 6
		bs.content_margin_bottom = 6
		buy_button.add_theme_stylebox_override("normal", bs)
		var bh := bs.duplicate()
		bh.bg_color = Color(0.235, 0.506, 0.953)
		buy_button.add_theme_stylebox_override("hover", bh)
		buy_button.add_theme_color_override("font_color", Color.WHITE)

func refresh() -> void:
	if title_label:
		title_label.text = "Tienda de mejoras  |  Meta: $%.0f" % GameManager.MONEY_GOAL
	if money_label:
		money_label.text = "Dinero disponible: $%.0f" % GameManager.money
	if goal_label:
		goal_label.text = "Meta de escape: $%.0f — transfiérela en el Banco a la cuenta del correo." % GameManager.MONEY_GOAL
	if shop_list == null:
		return
	shop_list.clear()
	# Iconos por categoría (cambia los PNG en assets/Icons Pc/ con los tuyos)
	for cat in UpgradeSystem.CATEGORY_ORDER:
		var line: String = UpgradeSystem.get_status_line(cat)
		var icon: Texture2D = UpgradeSystem.get_category_icon(cat)
		if icon:
			shop_list.add_item(line, icon)
		else:
			shop_list.add_item(line)
	if UpgradeSystem.CATEGORY_ORDER.size() > 0:
		_selected_idx = clampi(_selected_idx, 0, UpgradeSystem.CATEGORY_ORDER.size() - 1)
		shop_list.select(_selected_idx)
		_update_details(_selected_idx)

func _on_item_selected(idx: int) -> void:
	if SoundSystem:
		SoundSystem.play_click(true)
	_selected_idx = idx
	_update_details(idx)
	if idx >= 0 and idx < UpgradeSystem.CATEGORY_ORDER.size():
		category_selected.emit(UpgradeSystem.CATEGORY_ORDER[idx])

func _update_details(idx: int) -> void:
	if idx < 0 or idx >= UpgradeSystem.CATEGORY_ORDER.size():
		return
	var cat: String = UpgradeSystem.CATEGORY_ORDER[idx]
	var cur: Dictionary = UpgradeSystem.get_current(cat)
	var nxt: Dictionary = UpgradeSystem.get_next(cat)
	if details_label:
		var txt: String = "Actual:\n%s\n\n%s" % [str(cur.get("name", "")), str(cur.get("desc", ""))]
		if not nxt.is_empty():
			txt += "\n\nSiguiente:\n%s\n%s\nCoste: $%d" % [
				str(nxt.get("name", "")), str(nxt.get("desc", "")), int(nxt.get("cost", 0))
			]
		else:
			txt += "\n\n(Nivel máximo alcanzado)"
		details_label.text = txt
	if buy_button:
		if not UpgradeSystem.can_upgrade(cat):
			buy_button.disabled = true
			buy_button.text = "Nivel máximo"
		else:
			var cost: int = UpgradeSystem.get_next_cost(cat)
			buy_button.disabled = GameManager.money < float(cost)
			buy_button.text = "Comprar ($%d)" % cost

func _on_buy() -> void:
	if SoundSystem:
		SoundSystem.play_button()
	if _selected_idx < 0 or _selected_idx >= UpgradeSystem.CATEGORY_ORDER.size():
		return
	var cat: String = UpgradeSystem.CATEGORY_ORDER[_selected_idx]
	var ok: bool = UpgradeSystem.try_buy(cat)
	if feedback_label:
		if ok:
			feedback_label.text = "✓ Compra: %s" % UpgradeSystem.CATEGORY_LABELS.get(cat, cat)
			feedback_label.add_theme_color_override("font_color", Color(0.0, 0.45, 0.0))
			if is_instance_valid(VFXSystem):
				VFXSystem.spawn_sparkles(buy_button.global_position + buy_button.size * 0.5, 12)
				VFXSystem.spawn_toast("Mejora instalada", 1.8, Color(0.6, 1.0, 0.7))
				VFXSystem.flash_screen(Color(0.4, 0.9, 0.5, 0.12), 0.2)
		else:
			feedback_label.text = "No se pudo comprar (dinero o nivel máx)."
			feedback_label.add_theme_color_override("font_color", Color(0.6, 0.0, 0.0))
	refresh()
	buy_requested.emit(cat)

func set_feedback(text: String, ok: bool = true) -> void:
	if feedback_label:
		feedback_label.text = text
		feedback_label.add_theme_color_override("font_color", Color(0.0, 0.45, 0.0) if ok else Color(0.6, 0.0, 0.0))
