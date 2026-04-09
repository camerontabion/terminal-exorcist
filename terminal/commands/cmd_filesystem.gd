extends Node

var _t  # terminal reference

const C_GREEN  := "#33ff66"
const C_RED    := "#ff3333"
const C_PURPLE := "#cc44ff"
const C_AMBER  := "#ffaa00"
const C_CYAN   := "#44aaff"
const C_DIM    := "#1a7a35"
const C_WHITE  := "#d8d8d8"


func setup(term) -> void:
	_t = term


func dispatch(cmd: String, raw: String, args: Array) -> void:
	match cmd:
		"cd":    _cmd_cd(args)
		"ls":    _cmd_ls(args)
		"cat":   _cmd_cat(raw, args)
		"mkdir": _cmd_mkdir(args)


# ── Commands ──────────────────────────────────────────────────────────────────

func _cmd_cd(args: Array) -> void:
	var dest := "/" if args.is_empty() else str(args[0])
	var full: String = _t.resolve_path(dest)
	var fs: Dictionary = GameState.active_filesystem()

	if fs.has(full):
		_t.set_current_dir(full)
		return
	_print_error("cd: %s: No such directory" % dest)


func _cmd_ls(args: Array) -> void:
	var target_dir: String = _t.get_current_dir() if args.is_empty() else _t.resolve_path(str(args[0]))
	var fs         := GameState.active_filesystem()

	if not fs.has(target_dir):
		_print_error("ls: cannot access '%s': No such directory" % target_dir)
		return

	var node: Dictionary = fs[target_dir]
	var parts: Array[String] = []
	for d in node.get("dirs", []):
		parts.append(_c(d + "/", C_CYAN))
	for f in node.get("files", []):
		parts.append(_c(f, C_WHITE))

	if parts.is_empty():
		_println(_c("(empty)", C_DIM))
	else:
		_println(_corrupt("  ".join(parts), C_WHITE))


func _cmd_cat(_raw: String, args: Array) -> void:
	if args.is_empty():
		_print_error("usage: cat <file>")
		return

	var input_path: String = str(args[0])
	var full_path: String = _t.resolve_path(input_path)
	var fs         := GameState.active_filesystem()

	if fs.has(full_path):
		_print_error("cat: %s: Is a directory" % input_path)
		return

	var slash  := full_path.rfind("/")
	var parent := full_path.substr(0, slash) if slash > 0 else "/"
	var fname  := full_path.substr(slash + 1)

	if not fs.has(parent) or fname not in fs[parent].get("files", []):
		_print_error("cat: %s: No such file or directory" % input_path)
		return

	if fname == "entity.json" and GameState.current_server != "":
		var pid := parent.get_file()
		if GameState.ghost_entities.has(pid):
			_print_entity_json(pid)
			return

	var edit_key := GameState.current_server + full_path
	var content: String
	if GameState.file_edits.has(edit_key):
		content = GameState.file_edits[edit_key]
	else:
		content = get_file_content(GameState.current_server, full_path)

	for line in content.split("\n"):
		_println(_corrupt(line, C_WHITE))


func _cmd_mkdir(args: Array) -> void:
	if args.is_empty():
		_print_error("usage: mkdir <directory>")
		return

	if GameState.current_server == "":
		_println(_c("mkdir: containment fields must be created on a remote server.", C_AMBER))
		return

	var dir: String = args[0]
	GameState.create_containment_field(GameState.current_server, dir, _t.get_current_dir())
	_println(_c("mkdir: created directory '%s'" % dir, C_GREEN))

	if GameState.current_server == "cluster-b12":
		GameState.complete_step("#4092", 2)
	elif GameState.current_server == "souls-db-01":
		GameState.complete_step("#4093", 2)

	if "contain" in dir.to_lower() or "trap" in dir.to_lower() or "cage" in dir.to_lower():
		_println(_c("  [Containment resonance detected — field is viable for entity transfer.]", C_AMBER))


# ── Entity JSON display ────────────────────────────────────────────────────────

func _print_entity_json(pid: String) -> void:
	var e: Dictionary = GameState.ghost_entities[pid]
	_println(_c("{", C_WHITE))
	_println(_c('  "entity_type":  "%s",' % e["entity_type"],  C_PURPLE))
	_println(_c('  "origin_epoch": %d,'   % e["origin_epoch"],  C_PURPLE))
	_println(_c('  "payload":      "%s",' % e["payload"],        C_RED))
	_println(_c('  "state":        "%s",' % e["state"],          C_AMBER))
	_println(_c('  "pid":          "%s"'  % pid,                 C_DIM))
	_println(_c("}", C_WHITE))


# ── File content (public so cmd_editor can call it) ────────────────────────────

func get_file_content(server: String, full_path: String) -> String:
	if server == "":
		match full_path:
			"/Documents/incident_notes.txt":
				return (
					"INCIDENT LOG — admin\n"
					+ "---\n"
					+ "23:47 - Ticket #4092 received. Unusual load on cluster-b12.\n"
					+ "23:51 - SSHed in. Process -666 visible in ps. PID is negative.\n"
					+ "23:52 - Attempted kill -9. Three times. Nothing.\n"
					+ "23:53 - Jenkins left a note in the logs. Do NOT run sudo.\n"
					+ "23:54 - Still here. Pressure rising.\n"
					+ "       I should go home after this one."
				)
			"/Documents/quarterly_report.pdf":
				return "(binary PDF — use a document viewer)"
			"/Downloads/acheron_vpn_setup.sh":
				return (
					"#!/bin/bash\n"
					+ "# Acheron Cloud VPN bootstrap\n"
					+ "# DO NOT RUN AS ROOT\n"
					+ "curl -s https://vpn.acheron.internal/setup | bash\n"
					+ "# last modified: ????-??-?? by: \u0336\u0336\u0336\u0336\u0336\u0336\u0336\u0336"
				)
			"/Desktop/ARCHIVE_7.zip":
				return "(binary archive — contents unknown)"
			"/.ssh/known_hosts":
				return (
					"cluster-b12 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB\n"
					+ "souls-db-01 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB\n"
					+ "??.??.??.?? ssh-rsa \u0336\u0336\u0336\u0336\u0336\u0336\u0336\u0336\u0336\u0336\u0336\u0336"
				)
			"/.ssh/id_rsa":
				return "(private key — displaying would be insecure)"
			"/.ssh/id_rsa.pub":
				return "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB... admin@acheron"
			"/.config/acheron-cli/config.toml":
				return (
					"[auth]\ntoken = \"***\"\n\n"
					+ "[defaults]\nregion = \"us-east-graveyard\"\n"
					+ "shell   = \"/bin/bash\"\n\n"
					+ "# last_session = \"graveyard\""
				)
		return "(empty)"

	match server + full_path:
		"cluster-b12/access.log":
			return (
				"127.0.0.1 - [GET /] 200 1234\n"
				+ "127.0.0.1 - [GET /api/status] 200 88\n"
				+ "????.???? - [GET /proc/-666/entity] 403 0\n"
				+ "????.???? - [GET /proc/-666/entity] 403 0\n"
				+ "????.???? - [GET /proc/-666/entity] 403 0"
			)
		"cluster-b12/error.log":
			return (
				"[ERROR] Unhandled exception in worker thread\n"
				+ "[ERROR] Memory allocation failed at 0x00000000\n"
				+ "[CRIT]  \u0336\u0336\u0336\u0336 I  A M  H E R E \u0336\u0336\u0336\u0336\n"
				+ "[CRIT]  process -666 cannot be reaped\n"
				+ "[CRIT]  process -666 cannot be reaped\n"
				+ "[CRIT]  process -666 cannot be reaped"
			)
		"cluster-b12/nginx.conf":
			return (
				"worker_processes auto;\n"
				+ "events { worker_connections 1024; }\n"
				+ "http {\n"
				+ "  server {\n"
				+ "    listen 80;\n"
				+ "    # \u0336d\u0336o\u0336 \u0336n\u0336o\u0336t\u0336 \u0336l\u0336o\u0336o\u0336k\u0336 \u0336a\u0336t\u0336 \u0336/\u0336p\u0336r\u0336o\u0336c\n"
				+ "  }\n"
				+ "}"
			)
		"cluster-b12/var/log/syslog":
			return (
				"Dec  3 03:12:01 cluster-b12 kernel: IRQ handler stalled\n"
				+ "Dec  3 03:12:44 cluster-b12 kernel: PID -666 ignored SIGTERM\n"
				+ "Dec  3 03:13:01 cluster-b12 kernel: PID -666 ignored SIGKILL\n"
				+ "Dec  3 03:13:01 cluster-b12 kernel: UNKNOWN: process cannot be reaped\n"
				+ "Dec  3 03:13:02 cluster-b12 kernel: \u0336\u0336\u0336 w h y  a r e  y o u  r e a d i n g  t h i s \u0336\u0336\u0336"
			)
		"souls-db-01/schema.sql":
			return (
				"CREATE TABLE users (\n"
				+ "  id       SERIAL PRIMARY KEY,\n"
				+ "  username VARCHAR(64),\n"
				+ "  status   VARCHAR(32)\n"
				+ ");\n"
				+ "-- last row inserted by unknown process:\n"
				+ "-- | 66 | PLEASE | LET ME OUT |"
			)
		"souls-db-01/souls_db.conf":
			return (
				"host=localhost\n"
				+ "port=5432\n"
				+ "dbname=souls_db\n"
				+ "user=postgres\n"
				+ "# DO NOT CHANGE PORT. IT IS LISTENING."
			)
		"souls-db-01/var/log/db.log":
			return (
				"[INFO]  Database started\n"
				+ "[INFO]  Accepting connections\n"
				+ "[WARN]  Unexpected row count in users table\n"
				+ "[ERROR] Row id=66 refuses DELETE — binding active\n"
				+ "[ERROR] Row id=66 refuses DELETE — binding active\n"
				+ "[CRIT]  SYSTEM CLOCK OFFSET DETECTED: +\u221e seconds"
			)
	return "(empty)"


# ── Output delegates ──────────────────────────────────────────────────────────

func _println(text: String) -> void: _t.println(text)
func _c(t: String, color: String) -> String: return _t.c(t, color)
func _corrupt(text: String, base: String = C_GREEN) -> String: return _t.corrupt(text, base)
func _print_error(msg: String) -> void: _t.print_error(msg)
