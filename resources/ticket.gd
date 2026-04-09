class_name TicketData
extends Resource

@export var id:       String            = "#0000"
@export var title:    String            = ""
@export var priority: String            = "P1"   # P0 | P1 | P2
@export var steps:    Array[TicketStep] = []

# ── Runtime state ──────────────────────────────────────────────────────────────
var status: String = "open"  # open | in_progress | closed | backlog


func complete_step(index: int) -> void:
	if index < steps.size():
		steps[index].done = true
	if steps.all(func(s: TicketStep) -> bool: return s.done):
		status = "closed"
	elif status == "open" or status == "backlog":
		status = "in_progress"


func to_dict() -> Dictionary:
	var step_list: Array[Dictionary] = []
	for s: TicketStep in steps:
		step_list.append({ "desc": s.description, "done": s.done })
	return {
		"id":     id,
		"title":  title,
		"priority": priority,
		"status": status,
		"steps":  step_list,
	}
