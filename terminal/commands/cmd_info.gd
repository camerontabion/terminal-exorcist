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


func dispatch(cmd: String, _raw: String, args: Array) -> void:
	match cmd:
		"help":
			_cmd_help(args)
		"status":
			_cmd_status(args)
		"tickets", "quests", "missions":
			_cmd_tickets(args)


# ── Commands ──────────────────────────────────────────────────────────────────

func _cmd_help(_args: Array) -> void:
	_sep()
	_println(_c("  ACHERON OPERATIONS MANUAL", C_CYAN))
	_println(_c("  Alias / real-command shown where applicable.", C_DIM))
	_sep()

	_println("  " + _c("RECONNAISSANCE", C_AMBER))
	_println("")
	_help_row("ls / map [path]",           "List files and directories at current location")
	_help_row("cd <dir>",                  "Move into a directory")
	_help_row("cat / investigate <file>",  "Read a file")
	_help_row("ps / scan",                 "List running processes — entities appear here")
	_help_row("ping -spirit <host>",       "Measure etheric proximity of a nearby entity")
	_help_row("grep [-r] <pat> <path>",    "Search file contents for a pattern")
	_println("")

	_println("  " + _c("CONNECTIONS", C_AMBER))
	_println("")
	_help_row("ssh / connect <host>",      "Open a shell on a remote server")
	_help_row("exit / disconnect",         "Close the current remote session")
	_println("")

	_println("  " + _c("EXORCISM PROTOCOL", C_AMBER))
	_println("")
	_help_row("mkdir / trap <name>",       "Create a containment field in the current directory")
	_help_row("chmod 000 / suppress <e>",  "Suppress an entity for ~30 cycles (buys time)")
	_help_row("mv / contain <pid> <field>","Move a suppressed entity into a containment field")
	_help_row("kill [-9] <pid>",           "Attempt termination — won't work on entities")
	_help_row("nullify / banish <pid>",    "Permanently destroy a contained entity")
	_println("")

	_println("  " + _c("UTILITIES", C_AMBER))
	_println("")
	_help_row("status",                    "Show etheric pressure and entity states")
	_help_row("tickets",                   "Show open mission tickets")
	_help_row("nano <file>",               "Edit a file  (:wq save  :q! discard)")
	_help_row("sudo",                      "DO NOT RUN THIS")
	_help_row("clear",                     "Clear the terminal")
	_println("")
	_sep()


func _help_row(command: String, description: String) -> void:
	_println("  " + _c("%-36s" % command, C_GREEN) + _c(description, C_DIM))


func _cmd_status(_args: Array) -> void:
	var p   := GameState.etheric_pressure
	var s   := GameState.packet_stability
	var srv := GameState.current_server if GameState.current_server != "" else "local"

	var p_color := C_GREEN if p < 40.0 else (C_AMBER if p < 70.0 else C_RED)
	var s_color := C_RED   if s < 30.0 else (C_AMBER if s < 60.0 else C_GREEN)

	_sep()
	_println(_c("  Etheric Pressure  ", C_DIM) + _c("[%s] %.1f%%" % [_bar(p), p], p_color))
	_println(_c("  Packet Stability  ", C_DIM) + _c("[%s] %.1f%%" % [_bar(s), s], s_color))
	_println(_c("  Current Server    ", C_DIM) + _c(srv, C_WHITE))

	for pid in GameState.ghost_entities:
		var e: Dictionary = GameState.ghost_entities[pid]
		if e["server"] == GameState.current_server:
			var sc: String = {"loose": C_RED, "contained": C_AMBER, "nullified": C_DIM}.get(e["state"], C_WHITE)
			_println(_c("  Entity PID %-6s" % pid, C_DIM) + _c("[%s]  %s" % [e["state"].to_upper(), e["name"]], sc))

	_sep()


func _bar(value: float, width: int = 28) -> String:
	var filled: int = roundi(remap(value, 0.0, 100.0, 0.0, float(width)))
	return _c("\u2588".repeat(filled), C_GREEN) + _c("\u2591".repeat(width - filled), C_DIM)


func _cmd_tickets(_args: Array) -> void:
	_println(_c("ACHERON CLOUD — OPEN TICKETS", C_CYAN))
	_sep()
	var status_colors := {
		"open":        C_AMBER,
		"in_progress": C_GREEN,
		"backlog":     C_DIM,
		"closed":      C_DIM,
	}
	for ticket in GameState.missions:
		var sc: String = status_colors.get(ticket.status, C_WHITE)
		_println(
			_c("  %s" % ticket.id, C_WHITE)
			+ _c("  [%s]" % ticket.priority, C_AMBER)
			+ _c("  %-12s" % ticket.status.to_upper(), sc)
			+ _c("  %s" % ticket.title, C_WHITE)
		)
		for step in ticket.steps:
			var check := _c("[x]", C_GREEN) if step.done else _c("[ ]", C_DIM)
			_println("    " + check + _c("  " + step.description, C_DIM if step.done else C_WHITE))
		_println("")
	_sep()


# ── Output delegates ──────────────────────────────────────────────────────────

func _println(text: String) -> void: _t.println(text)
func _c(t: String, color: String) -> String: return _t.c(t, color)
func _print_error(msg: String) -> void: _t.print_error(msg)
func _sep() -> void: _t.sep()
