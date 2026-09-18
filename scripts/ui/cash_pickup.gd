extends Control
class_name CashPickup

var accumulated_amount: float = 0.0

@onready var texture_rect: TextureRect = $TextureRect
@onready var anim_timer: Timer = $Timer
@onready var button: Button = $Button

var hand1 = preload("res://assets/Icons Pc/hand1.png")
var hand2 = preload("res://assets/Icons Pc/hand2.png")
var current_frame = 0

var dragging = false
var drag_offset = Vector2()
var original_pos = Vector2()
var original_global_pos = Vector2()

func _ready() -> void:
	hide()
	GameManager.cash_payment_pending.connect(_on_cash_payment_pending)
	anim_timer.timeout.connect(_on_anim_timer_timeout)
	button.button_down.connect(_on_button_down)
	button.button_up.connect(_on_button_up)
	anim_timer.wait_time = 0.5

func _process(delta: float) -> void:
	if dragging:
		var target_global = get_global_mouse_position() - drag_offset
		var diff = target_global - original_global_pos
		var dist = diff.length()
		
		var max_dist = 120.0 # A partir de aquí empieza la resistencia
		if dist > max_dist:
			var extra = dist - max_dist
			# Movimiento se resiste con logaritmo
			var resisted_extra = 40.0 * log(1.0 + extra / 30.0)
			global_position = original_global_pos + diff.normalized() * (max_dist + resisted_extra)
			
			# La animación se hace más lenta a medida que se estira más (struggle)
			var struggle_factor = clampf(extra / 200.0, 0.0, 1.0)
			anim_timer.wait_time = lerp(0.12, 0.45, struggle_factor)
		else:
			global_position = target_global
			anim_timer.wait_time = 0.12

func _on_button_down() -> void:
	if dragging: return
	dragging = true
	drag_offset = get_global_mouse_position() - global_position
	original_global_pos = global_position
	original_pos = position
	anim_timer.wait_time = 0.12 # animacion rapida de "moverse"
	anim_timer.start()

func _on_button_up() -> void:
	if not dragging: return
	dragging = false
	
	# Volver a la posicion original y luego cobrar
	var tw = create_tween()
	tw.tween_property(self, "position", original_pos, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_collect_and_hide)

var sfx_cash = preload("res://assets/audio/sfx/cash.mp3")

func _collect_and_hide() -> void:
	if accumulated_amount > 0:
		GameManager.add_money(accumulated_amount)
		accumulated_amount = 0.0
		
		var audio = AudioStreamPlayer.new()
		audio.stream = sfx_cash
		add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free)
	
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(hide)
	tw.tween_callback(anim_timer.stop)
	
	anim_timer.wait_time = 0.5

var sfx_notification = preload("res://assets/audio/sfx/notification.mp3")

func _on_cash_payment_pending(amount: float) -> void:
	accumulated_amount += amount
	if not visible:
		show()
		
		var audio = AudioStreamPlayer.new()
		audio.stream = sfx_notification
		add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free)
		
		current_frame = 0
		texture_rect.texture = hand2 # Inicia con hand2 como solicitaste
		anim_timer.wait_time = 0.5
		anim_timer.start()
		
		# Feedback visual para llamar la atencion
		var tw = create_tween()
		scale = Vector2.ZERO
		tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_anim_timer_timeout() -> void:
	current_frame = (current_frame + 1) % 2
	if current_frame == 0:
		texture_rect.texture = hand2
	else:
		texture_rect.texture = hand1
