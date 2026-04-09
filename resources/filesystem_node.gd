class_name FilesystemNode
extends Resource

## The absolute path this node represents, e.g. "/proc" or "/var/log".
@export var path:          String          = "/"
@export var subdirectories: Array[String]  = []
@export var files:          Array[String]  = []


func to_dict() -> Dictionary:
	return { "dirs": subdirectories.duplicate(), "files": files.duplicate() }
