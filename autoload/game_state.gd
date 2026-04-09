extends Node

signal pressure_changed(value: float)
signal stability_changed(value: float)
signal ghost_state_changed(pid: String, new_state: String)

const MAX_PRESSURE := 100.0
const MAX_STABILITY := 100.0

# ── Runtime state ──────────────────────────────────────────────────────────────
var etheric_pressure:  float           = 15.0
var packet_stability:  float           = 87.0
var current_server:    String          = ""
var ghost_entities:    Dictionary      = {}   # pid -> dict (includes runtime state)
var containment_fields: Array[String]  = []
var servers:           Dictionary      = {}   # server_id -> dict
var file_edits:        Dictionary      = {}   # "server_id/path" -> String content
var missions:          Array           = []   # Array of TicketData resources

var local_filesystem: Dictionary = {
	"/":                  { "dirs": ["Documents", "Downloads", "Desktop", ".ssh", ".config"], "files": [] },
	"/Documents":         { "dirs": [], "files": ["incident_notes.txt", "quarterly_report.pdf"] },
	"/Downloads":         { "dirs": [], "files": ["acheron_vpn_setup.sh"] },
	"/Desktop":           { "dirs": [], "files": ["ARCHIVE_7.zip"] },
	"/.ssh":              { "dirs": [], "files": ["id_rsa", "id_rsa.pub", "known_hosts"] },
	"/.config":           { "dirs": ["acheron-cli"], "files": [] },
	"/.config/acheron-cli": { "dirs": [], "files": ["config.toml"] },
}

# ── Helpers ────────────────────────────────────────────────────────────────────

func active_filesystem() -> Dictionary:
	if current_server == "":
		return local_filesystem
	return servers[current_server]["filesystem"]


# ── Boot ───────────────────────────────────────────────────────────────────────

func _ready() -> void:
	var world: WorldData
	if ResourceLoader.exists("res://data/world.tres"):
		world = load("res://data/world.tres")
	else:
		world = _build_default_world()

	_setup_from_world(world)

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_tick)
	add_child(timer)


# ── World loading ──────────────────────────────────────────────────────────────

func _setup_from_world(world: WorldData) -> void:
	servers = {}
	ghost_entities = {}
	missions = world.tickets

	for srv: ServerData in world.servers:
		servers[srv.server_id] = srv.to_dict()
		for ghost: GhostEntity in srv.ghosts:
			ghost.state       = "loose"
			ghost.chmod_ticks = 0
			ghost.field       = ""
			ghost_entities[ghost.pid] = ghost.to_dict()


# ── Default world (used when no res://data/world.tres exists) ──────────────────
# Create a ServerData, populate it, return it. Same pattern for any new server.

func _build_default_world() -> WorldData:
	var world := WorldData.new()

	# ── cluster-b12 ──────────────────────────────────────────────────────────
	var b12 := ServerData.new()
	b12.server_id  = "cluster-b12"
	b12.login_user = "root"

	b12.processes = [
		_proc("1421", "www-data", "0.1", "0.5%", "nginx"),
		_proc("2204", "postgres", "0.3", "1.2%", "postgres"),
		_proc("3317", "root",     "0.0", "0.1%", "sshd"),
		_proc("5590", "root",     "0.0", "0.2%", "systemd"),
		_proc("-666", "????",     "??",  "??",   "\u2316WHISPER\u2316", true),
	]

	b12.filesystem = [
		_fsnode("/",          ["proc", "var"], ["nginx.conf", "access.log", "error.log"]),
		_fsnode("/proc",      ["-666"],        []),
		_fsnode("/proc/-666", [],              ["entity.json"]),
		_fsnode("/var",       ["log"],         []),
		_fsnode("/var/log",   [],              ["syslog"]),
	]

	var whisper := GhostEntity.new()
	whisper.pid              = "-666"
	whisper.entity_name      = "WHISPER"
	whisper.process_label    = "\u2316WHISPER\u2316"
	whisper.entity_type      = "Pre-Digital_Scream"
	whisper.origin_epoch     = 1994
	whisper.payload          = "I_AM_STILL_IN_THE_WIRES"
	whisper.pressure_per_sec = 0.6
	whisper.server_id        = "cluster-b12"
	b12.ghosts = [whisper]

	world.servers.append(b12)

	# ── souls-db-01 ──────────────────────────────────────────────────────────
	var sdb := ServerData.new()
	sdb.server_id  = "souls-db-01"
	sdb.login_user = "admin"

	sdb.processes = [
		_proc("910",  "postgres", "0.4", "2.1%", "postgres: souls_db"),
		_proc("1337", "????",     "??",  "??",   "\u2588BINDING\u2588", true),
	]

	sdb.filesystem = [
		_fsnode("/",          ["proc", "var"], ["souls_db.conf", "schema.sql"]),
		_fsnode("/proc",      ["1337"],        []),
		_fsnode("/proc/1337", [],              ["entity.json"]),
		_fsnode("/var",       ["log"],         []),
		_fsnode("/var/log",   [],              ["db.log"]),
	]

	var binding := GhostEntity.new()
	binding.pid              = "1337"
	binding.entity_name      = "BINDING"
	binding.process_label    = "\u2588BINDING\u2588"
	binding.entity_type      = "Clock_Anchor"
	binding.origin_epoch     = 2001
	binding.payload          = "ID_66_IS_BOUND_TO_YOUR_SYSTEM_CLOCK"
	binding.pressure_per_sec = 0.4
	binding.server_id        = "souls-db-01"
	sdb.ghosts = [binding]

	world.servers.append(sdb)

	# ── Tickets ───────────────────────────────────────────────────────────────
	world.tickets.append(_ticket("#4092", "Persistent Whisper in the Database", "P0", [
		"SSH into cluster-b12",
		"Identify the anomalous process",
		"Create a containment field",
		"Move entity into containment",
		"Nullify the entity",
	]))

	var t2 := _ticket("#4093", "Clock Anchor Detected in souls-db-01", "P1", [
		"SSH into souls-db-01",
		"Locate entity PID 1337",
		"Create a containment field",
		"Move entity into containment",
		"Nullify the entity",
	])
	t2.status = "backlog"
	world.tickets.append(t2)

	return world


# ── Resource factory helpers ───────────────────────────────────────────────────

func _proc(pid: String, user: String, cpu: String, mem: String,
		pname: String, ghost: bool = false) -> ProcessEntry:
	var p      := ProcessEntry.new()
	p.pid          = pid
	p.user         = user
	p.cpu          = cpu
	p.mem          = mem
	p.process_name = pname
	p.is_ghost     = ghost
	return p


func _fsnode(path: String, subdirs: Array[String], files: Array[String]) -> FilesystemNode:
	var n              := FilesystemNode.new()
	n.path             = path
	n.subdirectories   = subdirs
	n.files            = files
	return n


func _ticket(id: String, title: String, priority: String,
		step_descs: Array) -> TicketData:
	var t      := TicketData.new()
	t.id       = id
	t.title    = title
	t.priority = priority
	for desc: String in step_descs:
		var s          := TicketStep.new()
		s.description  = desc
		t.steps.append(s)
	return t


# ── Tick ───────────────────────────────────────────────────────────────────────

func _on_tick() -> void:
	for pid in ghost_entities:
		var e: Dictionary = ghost_entities[pid]
		if e["chmod_ticks"] > 0:
			e["chmod_ticks"] -= 1

	var gain := 0.0
	for pid in ghost_entities:
		var e: Dictionary = ghost_entities[pid]
		if e["state"] == "loose" and e["server"] == current_server and e["chmod_ticks"] <= 0:
			gain += e["pressure_per_sec"]

	if gain > 0.0:
		etheric_pressure = minf(etheric_pressure + gain, MAX_PRESSURE)
		packet_stability  = maxf(packet_stability  - gain * 0.25, 0.0)
		pressure_changed.emit(etheric_pressure)
		stability_changed.emit(packet_stability)


# ── Containment ────────────────────────────────────────────────────────────────

func create_containment_field(server: String, field_name: String, parent_dir: String = "/") -> void:
	var key := server + parent_dir.rstrip("/") + "/" + field_name
	if containment_fields.has(key):
		return
	containment_fields.append(key)
	if servers.has(server):
		var fs: Dictionary = servers[server]["filesystem"]
		if not fs.has(parent_dir):
			fs[parent_dir] = { "dirs": [], "files": [] }
		if not fs[parent_dir]["dirs"].has(field_name):
			fs[parent_dir]["dirs"].append(field_name)
		var new_path := parent_dir.rstrip("/") + "/" + field_name
		if not fs.has(new_path):
			fs[new_path] = { "dirs": [], "files": [] }


func has_containment_field(server: String, field_name: String, parent_dir: String = "/") -> bool:
	return containment_fields.has(server + parent_dir.rstrip("/") + "/" + field_name)


func find_containment_field_key(server: String, field_name: String) -> String:
	for key: String in containment_fields:
		if key.begins_with(server) and key.ends_with("/" + field_name):
			return key
	return ""


# ── Ghost entity actions ───────────────────────────────────────────────────────

func move_to_containment(pid: String, field: String) -> bool:
	if not ghost_entities.has(pid):
		return false
	var e: Dictionary = ghost_entities[pid]
	if e["state"] != "loose":
		return false
	if find_containment_field_key(e["server"], field) == "":
		return false
	e["state"] = "contained"
	e["field"]  = field
	ghost_state_changed.emit(pid, "contained")
	return true


func nullify_entity(pid: String) -> bool:
	if not ghost_entities.has(pid):
		return false
	var e: Dictionary = ghost_entities[pid]
	if e["state"] != "contained":
		return false
	e["state"] = "nullified"
	ghost_state_changed.emit(pid, "nullified")
	etheric_pressure = maxf(etheric_pressure - 35.0, 0.0)
	packet_stability  = minf(packet_stability  + 20.0, MAX_STABILITY)
	pressure_changed.emit(etheric_pressure)
	stability_changed.emit(packet_stability)
	return true


func chmod_suppress(pid: String, ticks: int = 30) -> bool:
	if not ghost_entities.has(pid):
		return false
	ghost_entities[pid]["chmod_ticks"] = ticks
	return true


func get_loose_ghost_on_server(server: String) -> Dictionary:
	for pid in ghost_entities:
		var e: Dictionary = ghost_entities[pid]
		if e["server"] == server and e["state"] == "loose" and e["chmod_ticks"] <= 0:
			return e
	return {}


func find_ghost_pid_by_name(target: String) -> String:
	for pid in ghost_entities:
		if ghost_entities[pid]["name"].to_lower() in target.to_lower():
			return pid
	return ""


# ── Mission / ticket tracking ──────────────────────────────────────────────────

func complete_step(mission_id: String, step_index: int) -> void:
	for ticket in missions:
		if ticket.id == mission_id:
			ticket.complete_step(step_index)
			return
