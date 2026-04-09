class_name ServerData
extends Resource

@export var server_id:   String                  = ""
@export var login_user:  String                  = "root"
@export var processes:   Array[ProcessEntry]     = []
@export var filesystem:  Array[FilesystemNode]   = []
@export var ghosts:      Array[GhostEntity]      = []


## Converts the filesystem array into the dict GameState works with at runtime.
## { "/path": { "dirs": [...], "files": [...] } }
func build_filesystem_dict() -> Dictionary:
	var result: Dictionary = {}
	for node: FilesystemNode in filesystem:
		result[node.path] = node.to_dict()
	return result


## Converts the process list into the Array[Dictionary] format for ps rendering.
func build_process_list() -> Array:
	var result: Array = []
	for p: ProcessEntry in processes:
		result.append(p.to_dict())
	return result


func to_dict() -> Dictionary:
	return {
		"user":       login_user,
		"processes":  build_process_list(),
		"filesystem": build_filesystem_dict(),
	}
