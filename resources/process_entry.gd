class_name ProcessEntry
extends Resource

@export var pid:          String = ""
@export var user:         String = "root"
@export var cpu:          String = "0.0"
@export var mem:          String = "0.0%"
@export var process_name: String = ""
@export var is_ghost:     bool   = false


func to_dict() -> Dictionary:
	return {
		"pid":   pid,
		"user":  user,
		"cpu":   cpu,
		"mem":   mem,
		"name":  process_name,
		"ghost": is_ghost,
	}
