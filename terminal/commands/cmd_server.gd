extends Node

var _t   # terminal reference
var _rng := RandomNumberGenerator.new()

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
		"ssh":            _cmd_ssh(args)
		"exit", "logout": _cmd_exit(args)
		"ps":             _cmd_ps(args)
		"ping":           _cmd_ping(raw, args)
		"grep":           _cmd_grep(raw, args)
		"sudo":           _cmd_sudo(args)


# ── Commands ──────────────────────────────────────────────────────────────────

func _cmd_ps(_args: Array) -> void:
	if GameState.current_server == "":
		_println(_c("  PID    USER       CPU    MEM    COMMAND", C_DIM))
		_println(_c("  1      root       0.0    0.1%   systemd", C_WHITE))
		_println(_c("  412    admin      0.1    0.3%   bash", C_WHITE))
		return

	var srv: Dictionary = GameState.servers[GameState.current_server]
	_println(_c("  PID    USER       CPU    MEM    COMMAND", C_DIM))
	_println(_c("  " + "─".repeat(40), C_DIM))

	for proc in srv["processes"]:
		var pid:   String = proc["pid"]
		var ghost: bool   = proc.get("ghost", false)

		if ghost and not GameState.ghost_entities.has(pid):
			continue

		var state: String = ""
		if ghost:
			state = GameState.ghost_entities[pid]["state"]

		if ghost and state == "nullified":
			continue

		if ghost and GameState.ghost_entities[pid]["chmod_ticks"] > 0:
			continue

		var line := "  %-6s %-10s %-6s %-6s %s" % [
			proc["pid"], proc["user"], proc["cpu"], proc["mem"], proc["name"]
		]

		if ghost:
			var suffix := "  [CONTAINED]" if state == "contained" else ""
			var color  := C_AMBER if state == "contained" else C_RED
			_println(_c(line + suffix, color))
			if GameState.current_server == "cluster-b12":
				GameState.complete_step("#4092", 1)
			elif GameState.current_server == "souls-db-01":
				GameState.complete_step("#4093", 1)
		else:
			_println(_corrupt(line, C_WHITE))


func _cmd_ssh(args: Array) -> void:
	if args.is_empty():
		_print_error("usage: ssh [user@]host")
		return

	var target: String = args[0]
	var host:   String = target.split("@")[-1]

	if not GameState.servers.has(host):
		_println(_c("ssh: connect to host %s: Connection refused" % host, C_RED))
		return

	_println(_c("Connecting to %s ..." % host, C_DIM))
	GameState.current_server = host
	_t.set_current_dir("/")

	await get_tree().create_timer(0.5).timeout

	_println(_c("Connected to %s." % host, C_GREEN))
	if host == "cluster-b12":
		GameState.complete_step("#4092", 0)
	elif host == "souls-db-01":
		GameState.complete_step("#4093", 0)
	_println(_c("Linux acheron-cloud 6.6.0-sre #1 SMP PREEMPT x86_64 GNU/Linux", C_DIM))
	_println("")

	var ghost := GameState.get_loose_ghost_on_server(host)
	if not ghost.is_empty():
		await get_tree().create_timer(0.7).timeout
		_println(_corrupt("Last login: ???  pts/??", C_DIM))
		await get_tree().create_timer(0.5).timeout
		_println(_c("WARNING: Anomalous process signature detected in active session.", C_AMBER))

	_scroll()


func _cmd_exit(_args: Array) -> void:
	if GameState.current_server == "":
		_t.request_quit_confirm()
		return
	_println(_c("Connection to %s closed." % GameState.current_server, C_DIM))
	GameState.current_server = ""
	_t.set_current_dir("/")


func _cmd_ping(raw: String, args: Array) -> void:
	if args.is_empty():
		_print_error("usage: ping [-spirit] <host>")
		return

	var spirit_mode: bool = "-spirit" in raw
	var host: String = args[-1]

	if spirit_mode:
		_println(_c("PING -spirit %s (measuring etheric proximity) ..." % host, C_CYAN))
		await get_tree().create_timer(0.5).timeout

		var ghost := GameState.get_loose_ghost_on_server(GameState.current_server)
		if not ghost.is_empty():
			var base_dist := roundi(remap(GameState.etheric_pressure, 0.0, 100.0, 14.0, 0.5))
			for i in range(4):
				await get_tree().create_timer(0.4).timeout
				var d: int = max(base_dist - i, 0)
				_println(_c(
					"64 bytes from entity(%s): meters=%.1f  ttl=???" % [ghost["pid"], d + _rng.randf()],
					C_RED
				))
			await get_tree().create_timer(0.2).timeout
			_println(_c(
				"--- entity is approaching. distance: %.1f meters from physical hardware ---" % (
					max(base_dist - 3, 0) + _rng.randf() * 0.5
				),
				C_AMBER
			))
		else:
			for _i in range(4):
				await get_tree().create_timer(0.3).timeout
				_println(_c("64 bytes from %s: meters=\u221e  ttl=64" % host, C_DIM))
			_println(_c("--- no etheric entities detected in proximity ---", C_GREEN))

		_scroll()
		return

	_println(_c("PING %s (0.0.0.0) 56 bytes of data." % host, C_DIM))
	for i in range(4):
		await get_tree().create_timer(0.3).timeout
		var ms := _rng.randi_range(1, 120)
		_println(_corrupt("64 bytes from %s: icmp_seq=%d ttl=64 time=%d ms" % [host, i + 1, ms], C_WHITE))
	_println(_c("--- %s ping statistics ---" % host, C_DIM))
	_scroll()


func _cmd_grep(raw: String, args: Array) -> void:
	if args.size() < 2:
		_print_error("usage: grep [-r] <pattern> <path>")
		return

	var pattern := raw.to_lower()
	var path: String = args[-1]

	_println(_c("grep: scanning %s ..." % path, C_DIM))

	if "help me" in pattern or "help_me" in pattern:
		await get_tree().create_timer(1.1).timeout
		_println(_c("access.log:1882:  # if anyone reads this — do NOT run sudo", C_RED))
		await get_tree().create_timer(0.25).timeout
		_println(_c("access.log:1883:  # it opened something. we abandoned the session.", C_RED))
		await get_tree().create_timer(0.25).timeout
		_println(_c(".hidden/NOTE_JENKINS: i deleted -666. it came back.", C_PURPLE))
		await get_tree().create_timer(0.25).timeout
		_println(_c(".hidden/NOTE_JENKINS: it was still running on Tuesday.", C_PURPLE))
		await get_tree().create_timer(0.25).timeout
		_println(_c(".hidden/NOTE_JENKINS: it knows my name now", C_RED))
		await get_tree().create_timer(0.25).timeout
		_println(_c(".hidden/NOTE_JENKINS: do not read proc/-666/entity.json", C_RED))
		_scroll()
		return

	if "lost" in pattern or "still" in pattern or "please" in pattern:
		await get_tree().create_timer(0.8).timeout
		_println(_corrupt("error.log: I AM STILL IN THE WIRES", C_RED))
		_scroll()
		return

	await get_tree().create_timer(0.4).timeout
	_println(_c("grep: no matches found.", C_DIM))


func _cmd_sudo(_args: Array) -> void:
	_println(_c("[sudo] password for admin: ", C_DIM))
	await get_tree().create_timer(1.3).timeout
	_println(_c("SUDO INVOKED — PRIVILEGE ESCALATION DETECTED BY ENTITY", C_RED))
	await get_tree().create_timer(0.3).timeout
	_println(_c(">> ELEVATED CONTEXT ACCESSED", C_PURPLE))
	await get_tree().create_timer(0.2).timeout
	_println(_c(">> DO NOT INVOKE SUDO AGAIN", C_RED))
	GameState.etheric_pressure = minf(GameState.etheric_pressure + 20.0, 100.0)
	_scroll()


# ── Output delegates ──────────────────────────────────────────────────────────

func _println(text: String) -> void: _t.println(text)
func _c(t: String, color: String) -> String: return _t.c(t, color)
func _corrupt(text: String, base: String = C_GREEN) -> String: return _t.corrupt(text, base)
func _print_error(msg: String) -> void: _t.print_error(msg)
func _scroll() -> void: _t.scroll_to_bottom()
