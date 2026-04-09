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
		"kill":    _cmd_kill(args)
		"chmod":   _cmd_chmod(args)
		"mv":      _cmd_mv(args)
		"nullify": _cmd_nullify(args)


# ── Commands ──────────────────────────────────────────────────────────────────

func _cmd_kill(args: Array) -> void:
	if args.is_empty():
		_print_error("usage: kill [-9] <pid>")
		return

	var pid: String = args[-1]

	if GameState.ghost_entities.has(pid):
		var state: String = GameState.ghost_entities[pid]["state"]
		if state == "nullified":
			_println(_c("kill: (%s) No such process" % pid, C_DIM))
			return

		_println(_c("kill: (%s) — Operation not permitted" % pid, C_RED))
		await get_tree().create_timer(0.3).timeout
		_println(_c("kill: (%s) — Operation not permitted" % pid, C_RED))
		await get_tree().create_timer(0.3).timeout
		_println(_c("kill: (%s) — Operation not permitted" % pid, C_RED))
		await get_tree().create_timer(0.5).timeout
		_println(_c("  [Entity cannot be terminated by conventional signals.]", C_PURPLE))
		_println(_c("  [Containment and nullification required. See: help]", C_DIM))

		GameState.etheric_pressure = minf(GameState.etheric_pressure + 5.0, 100.0)
		_scroll()
		return

	_println(_c("Terminated.", C_DIM))


func _cmd_chmod(args: Array) -> void:
	if args.size() < 2:
		_print_error("usage: chmod <mode> <target>")
		return

	var mode:   String = args[0]
	var target: String = args[1]

	var pid := target
	if not GameState.ghost_entities.has(pid):
		pid = GameState.find_ghost_pid_by_name(target)

	if pid != "" and GameState.ghost_entities.has(pid) and mode == "000":
		_println(_c("chmod: stripping permissions from entity PID %s ..." % pid, C_AMBER))
		await get_tree().create_timer(0.6).timeout
		GameState.chmod_suppress(pid, 30)
		_println(_c("  [Entity rendered inert for ~30 cycles. Proceed with containment.]", C_GREEN))
		_scroll()
		return

	_println(_c("chmod %s %s" % [mode, target], C_DIM))


func _cmd_mv(args: Array) -> void:
	if args.size() < 2:
		_print_error("usage: mv <pid> <containment_field>")
		return

	var src:  String = args[0]
	var dest: String = args[1]

	if not GameState.ghost_entities.has(src):
		_print_error("mv: cannot stat '%s': No such file or directory" % src)
		return

	var e: Dictionary = GameState.ghost_entities[src]

	if e["state"] == "contained":
		_print_error("mv: entity PID %s is already contained in '%s'." % [src, e["field"]])
		return
	if e["state"] == "nullified":
		_print_error("mv: entity PID %s has already been nullified." % src)
		return
	if GameState.find_containment_field_key(GameState.current_server, dest) == "":
		_print_error("mv: '%s' is not a valid containment field — run mkdir first." % dest)
		return

	_println(_c("Moving entity PID %s \u2192 %s ..." % [src, dest], C_AMBER))
	await get_tree().create_timer(0.4).timeout
	_println(_corrupt("Applying logic-trap binding ...", C_DIM))
	await get_tree().create_timer(0.6).timeout

	if GameState.move_to_containment(src, dest):
		_println(_c("mv: entity %s CONTAINED in '%s'." % [src, dest], C_GREEN))
		_println(_c("    Etheric field holding. Run nullify %s to finish exorcism." % src, C_DIM))
		if GameState.current_server == "cluster-b12":
			GameState.complete_step("#4092", 3)
		elif GameState.current_server == "souls-db-01":
			GameState.complete_step("#4093", 3)
	else:
		_print_error("mv: containment failed — insufficient field resonance.")

	_scroll()


func _cmd_nullify(args: Array) -> void:
	if args.is_empty():
		_print_error("usage: nullify <pid>")
		return

	var pid: String = args[0]

	if not GameState.ghost_entities.has(pid):
		_print_error("nullify: no known entity with PID %s." % pid)
		return

	var state: String = GameState.ghost_entities[pid]["state"]

	if state == "loose":
		_print_error("nullify: entity is not contained — run mv %s <containment_field> first." % pid)
		return
	if state == "nullified":
		_println(_c("nullify: entity %s has already been nullified." % pid, C_DIM))
		return

	_println(_c("Initiating nullification sequence for entity PID %s ..." % pid, C_AMBER))
	await get_tree().create_timer(0.5).timeout
	_println(_c("  Parsing entity payload ...", C_DIM))
	await get_tree().create_timer(0.5).timeout
	_println(_c("  Overwriting \"payload\" field \u2192 null ...", C_DIM))
	await get_tree().create_timer(0.5).timeout
	_println(_c("  Severing epoch binding (%d) ..." % GameState.ghost_entities[pid]["origin_epoch"], C_DIM))
	await get_tree().create_timer(0.6).timeout
	_println(_corrupt("  Releasing entity from wire substrate ...", C_DIM))
	await get_tree().create_timer(0.7).timeout

	GameState.nullify_entity(pid)

	_println(_c("  Entity NULLIFIED. Etheric pressure dropping.", C_GREEN))
	_println("")
	if GameState.current_server == "cluster-b12":
		GameState.complete_step("#4092", 4)
		_println(_c("  Ticket #4092 — RESOLVED.", C_CYAN))
	elif GameState.current_server == "souls-db-01":
		GameState.complete_step("#4093", 4)
		_println(_c("  Ticket #4093 — RESOLVED.", C_CYAN))
	_scroll()


# ── Output delegates ──────────────────────────────────────────────────────────

func _println(text: String) -> void: _t.println(text)
func _c(t: String, color: String) -> String: return _t.c(t, color)
func _corrupt(text: String, base: String = C_GREEN) -> String: return _t.corrupt(text, base)
func _print_error(msg: String) -> void: _t.print_error(msg)
func _scroll() -> void: _t.scroll_to_bottom()
