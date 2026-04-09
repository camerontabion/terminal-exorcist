class_name GhostEntity
extends Resource

@export var pid:              String = ""
@export var entity_name:      String = ""
@export var entity_type:      String = ""
@export var origin_epoch:     int    = 0
@export var payload:          String = ""
@export var pressure_per_sec: float  = 0.5
## The server_id this entity inhabits (must match a ServerData.server_id).
@export var server_id:        String = ""
## Display name shown in ps output — supports Unicode for creepiness.
@export var process_label:    String = ""

# ── Runtime state ──────────────────────────────────────────────────────────────
var state:       String = "loose"  # loose | contained | nullified
var chmod_ticks: int    = 0
var field:       String = ""


func to_dict() -> Dictionary:
	return {
		"pid":              pid,
		"name":             entity_name,
		"entity_type":      entity_type,
		"origin_epoch":     origin_epoch,
		"payload":          payload,
		"state":            state,
		"pressure_per_sec": pressure_per_sec,
		"server":           server_id,
		"chmod_ticks":      chmod_ticks,
		"field":            field,
	}
