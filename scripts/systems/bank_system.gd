extends Node
## =============================================================================
## BankSystem — Historial de transacciones narrativas
## =============================================================================
## No modifica el saldo. Solo presenta movimientos que pueden funcionar como
## evidencia y alimentar InvestigationSystem.

signal transactions_changed

const TRANSACTIONS: Array = [
	{
		"id": "starter_payment",
		"day": 1,
		"date": "01/05",
		"merchant": "WORKGRID",
		"amount": 125.00,
		"kind": "credit",
		"note": "Primer pago recibido.",
		"note_en": "First payment received."
	},
	{
		"id": "meridian_payment",
		"day": 5,
		"date": "14/05",
		"merchant": "HOTEL MERIDIAN",
		"amount": -183.50,
		"kind": "debit",
		"note": "Pago con tarjeta. Habitación 217.",
		"note_en": "Card payment. Room 217."
	},
	{
		"id": "safehouse_payment",
		"day": 16,
		"date": "16/05",
		"merchant": "MOTEL NORTH",
		"amount": -72.00,
		"kind": "debit",
		"note": "Reserva cancelada. El registro está incompleto.",
		"note_en": "Reservation cancelled. The record is incomplete."
	},
	{
		"id": "unknown_credit",
		"day": 21,
		"date": "21/05",
		"merchant": "UNKNOWN RELAY",
		"amount": 450.00,
		"kind": "credit",
		"note": "Concepto: SILENCIO.",
		"note_en": "Reference: SILENCE."
	}
]

var seen_transactions: Array[String] = []

func _ready() -> void:
	call_deferred("_refresh_for_current_day")

func _refresh_for_current_day() -> void:
	transactions_changed.emit()

func get_transactions() -> Array:
	var result: Array = []
	var current_day := GameManager.day if GameManager else 1
	for tx in TRANSACTIONS:
		if int(tx.get("day", 999)) <= current_day:
			result.append(tx)
	return result

func get_transaction(transaction_id: String) -> Dictionary:
	for tx in TRANSACTIONS:
		if str(tx.get("id", "")) == transaction_id:
			return tx.duplicate(true)
	return {}

func mark_seen(transaction_id: String) -> void:
	var tx := get_transaction(transaction_id)
	if tx.is_empty():
		return
	if transaction_id in seen_transactions:
		return
	seen_transactions.append(transaction_id)
	if InvestigationSystem and InvestigationSystem.has_method("register_transaction_seen"):
		InvestigationSystem.register_transaction_seen(transaction_id)
	transactions_changed.emit()

func reset() -> void:
	seen_transactions.clear()
	transactions_changed.emit()

func get_save_data() -> Dictionary:
	return {"seen_transactions": seen_transactions.duplicate()}

func load_save_data(data: Dictionary) -> void:
	seen_transactions.clear()
	for id in data.get("seen_transactions", []):
		seen_transactions.append(str(id))
	transactions_changed.emit()
