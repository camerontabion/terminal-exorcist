extends Resource
class_name TicketStep

@export var description: String = ""

# ── Runtime state (reset each session, not saved to .tres) ────────────────────
var done: bool = false
