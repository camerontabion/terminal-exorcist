extends Control

@export var history_item_scene: PackedScene

@onready var history:           VBoxContainer   = $HistoryContainer/History
@onready var history_container: ScrollContainer = $HistoryContainer
@onready var input:             LineEdit        = $Input
@onready var _cmd_info:         Node            = $Commands/CmdInfo
@onready var _cmd_server:       Node            = $Commands/CmdServer
@onready var _cmd_filesystem:   Node            = $Commands/CmdFilesystem
@onready var _cmd_ghost:        Node            = $Commands/CmdGhost
@onready var _cmd_editor:       Node            = $Commands/CmdEditor

# ── Color palette ─────────────────────────────────────────────────────────────
const C_GREEN  := "#33ff66"
const C_RED    := "#ff3333"
const C_PURPLE := "#cc44ff"
const C_AMBER  := "#ffaa00"
const C_CYAN   := "#44aaff"
const C_DIM    := "#1a7a35"
const C_WHITE  := "#d8d8d8"

# ── Corruption vocabulary ─────────────────────────────────────────────────────
const GLITCH_CHARS: Array[String] = [
	"\u0305", "\u0336", "\u0338", "\u0334", "\u0332", "\u0337",
]
const GHOST_PHRASES: Array[String] = [
	"L\u00A0O\u00A0S\u00A0T", "H\u00A0E\u00A0L\u00A0P", "S\u00A0T\u00A0I\u00A0L\u00A0L\u00A0H\u00A0E\u00A0R\u00A0E",
	"N\u00A0O\u00A0E\u00A0X\u00A0I\u00A0T", "D\u00A0O\u00A0N\u00A0O\u00A0T\u00A0D\u00A0E\u00A0L\u00A0E\u00A0T\u00A0E",
]
const ENTITY_INTRUSIONS: Array[String] = [
	">> TRANSMISSION INTERCEPTED",
	">> I AM STILL IN THE WIRES",
	">> YOU CANNOT DELETE WHAT WAS NEVER BORN",
	">> PLEASE LET ME OUT",
	">> GRAVEYARD SHIFT. ALWAYS THE GRAVEYARD SHIFT.",
	">> I KNOW YOUR NAME",
]

var _rng         := RandomNumberGenerator.new()
var _current_dir := "/"

# ── Command history ────────────────────────────────────────────────────────────
var _cmd_history: Array[String] = []
var _history_idx: int           = -1

# ── Tab completion state ───────────────────────────────────────────────────────
var _tab_candidates: Array[String] = []
var _tab_base_text:  String        = ""
var _tab_idx:        int           = -1

# ── Quit confirmation state ────────────────────────────────────────────────────
var _quit_confirm_pending: bool = false

const KNOWN_COMMANDS: Array[String] = [
	# Core commands
	"cat", "cd", "chmod", "clear", "exit", "grep", "help",
	"kill", "logout", "ls", "mkdir", "mv", "nano", "nullify",
	"ping", "ps", "ssh", "status", "sudo", "tickets",
	# Accessible aliases
	"banish", "connect", "contain", "disconnect",
	"investigate", "map", "scan", "suppress", "trap",
]

# Maps alias → [canonical_cmd, args_transform]
# "suppress <pid>" becomes "chmod" with "000" prepended to args.
# All other aliases are 1-to-1 renames with args unchanged.
const COMMAND_ALIASES: Dictionary = {
	"suppress":   "chmod",
	"contain":    "mv",
	"banish":     "nullify",
	"scan":       "ps",
	"investigate":"cat",
	"trap":       "mkdir",
	"map":        "ls",
	"connect":    "ssh",
	"disconnect": "exit",
}


# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_update_prompt()
	input.grab_focus.call_deferred()
	GameState.pressure_changed.connect(_on_pressure_changed)
	input.history_up.connect(_on_history_up)
	input.history_down.connect(_on_history_down)
	_cmd_info.setup(self)
	_cmd_server.setup(self)
	_cmd_filesystem.setup(self)
	_cmd_ghost.setup(self)
	_cmd_editor.setup(self, _cmd_ghost, _cmd_filesystem)
	input.tab_pressed.connect(_on_tab_pressed)
	await get_tree().process_frame
	_print_boot_sequence()


func _print_boot_sequence() -> void:
	_println(_c("ACHERON CLOUD SERVICES — OPERATIONS TERMINAL v2.4.1", C_CYAN))
	_println(_c("Session: admin@acheron  |  Clearance: SRE-III  |  Shift: GRAVEYARD", C_DIM))
	_println(_c("\u2500".repeat(40), C_DIM))
	_println("")
	_println(_c("!! OPEN TICKET: #4092 — \"Persistent Whisper in the Database\"", C_AMBER))
	_println(_c("   Objective: Silence the noise.", C_DIM))
	_println(_c("   Type [color=%s]help[/color] for available commands." % C_GREEN, C_DIM))
	_println("")
	scroll_to_bottom()


func _on_input_text_submitted(new_text: String) -> void:
	var raw: String = new_text
	if raw.begins_with(input.directory):
		raw = raw.substr(input.directory.length())
	raw = raw.strip_edges()

	input.reset()

	var echo: RichTextLabel = history_item_scene.instantiate()
	echo.bbcode_enabled = true
	echo.text = _c(input.directory, C_DIM) + _c(raw, C_GREEN)
	history.add_child(echo)

	if raw == "":
		scroll_to_bottom()
		return

	if _cmd_history.is_empty() or _cmd_history.back() != raw:
		_cmd_history.append(raw)
	_history_idx    = -1
	_tab_candidates = []
	_tab_idx        = -1

	if _quit_confirm_pending:
		_handle_quit_confirm(raw)
		scroll_to_bottom()
		return

	if _cmd_editor.is_editing():
		_cmd_editor.handle_edit_input(raw)
		scroll_to_bottom()
		return

	if raw == "clear":
		for child in history.get_children():
			child.queue_free()
		scroll_to_bottom()
		return

	_handle_command(raw)
	scroll_to_bottom()


# ── Prompt ─────────────────────────────────────────────────────────────────────

func _update_prompt() -> void:
	var path_display := "" if _current_dir == "/" else _current_dir
	if GameState.current_server == "":
		input.directory = "admin@acheron:~%s$ " % path_display
	else:
		var user: String = GameState.servers[GameState.current_server].get("user", "root")
		input.directory = "%s@%s:~%s# " % [user, GameState.current_server, path_display]
	input.reset()


# ── Command history navigation ────────────────────────────────────────────────

func _on_history_up() -> void:
	if _cmd_history.is_empty():
		return
	_history_idx = min(_history_idx + 1, _cmd_history.size() - 1)
	_set_input_text(_cmd_history[_cmd_history.size() - 1 - _history_idx])


func _on_history_down() -> void:
	if _history_idx <= 0:
		_history_idx = -1
		_set_input_text("")
		return
	_history_idx -= 1
	_set_input_text(_cmd_history[_cmd_history.size() - 1 - _history_idx])


func _set_input_text(cmd: String) -> void:
	input.text = input.directory + cmd
	input.caret_column = input.text.length()


# ── Public output API (called by command nodes) ────────────────────────────────

func println(text: String) -> void:
	_println(text)


func c(text: String, color: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]


func corrupt(text: String, base_color: String = C_GREEN) -> String:
	return _corrupt(text, base_color)


func print_error(msg: String) -> void:
	_print_error(msg)


func sep() -> void:
	_sep()


# ── Public state API (called by command nodes) ─────────────────────────────────

func set_current_dir(path: String) -> void:
	_current_dir = path
	_update_prompt()


func get_current_dir() -> String:
	return _current_dir


func resolve_path(input_path: String) -> String:
	return _resolve_path(input_path)


func set_edit_mode_active(active: bool) -> void:
	if active:
		input.directory = "[EDIT] > "
		input.reset()
	else:
		_update_prompt()


func request_quit_confirm() -> void:
	_quit_confirm_pending = true
	input.directory = "[quit? y/N] > "
	input.reset()
	println(_c("Quit the game? Type ", C_DIM) + _c("y", C_AMBER) + _c(" to confirm, anything else cancels.", C_DIM))


func _handle_quit_confirm(raw: String) -> void:
	_quit_confirm_pending = false
	if raw.strip_edges().to_lower() in ["y", "yes"]:
		_println(_c("Logging off. Stay safe out there.", C_DIM))
		await get_tree().create_timer(0.8).timeout
		get_tree().quit()
	else:
		_println(_c("Quit cancelled.", C_DIM))
		_update_prompt()


# ── Private output helpers ─────────────────────────────────────────────────────

func _c(text: String, color: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]


func _println(text: String) -> void:
	var item: RichTextLabel = history_item_scene.instantiate()
	item.bbcode_enabled = true
	item.text = text
	history.add_child(item)


func _print_error(msg: String) -> void:
	_println(_c("error: " + msg, C_RED))


func _sep() -> void:
	_println(_c("\u2500".repeat(40), C_DIM))


# ── Corruption engine ──────────────────────────────────────────────────────────

func _corrupt(text: String, base_color: String = C_GREEN) -> String:
	var pressure := GameState.etheric_pressure
	if pressure < 40.0:
		return _c(text, base_color)

	var threshold := remap(pressure, 40.0, 100.0, 0.0, 0.5)
	var words     := text.split(" ")
	var parts: Array[String] = []

	for word in words:
		if _rng.randf() < threshold:
			if pressure > 80.0 and _rng.randf() < 0.4:
				parts.append(_c(GHOST_PHRASES.pick_random(), C_RED))
			else:
				parts.append(_c(_glitch_word(word), C_RED))
		else:
			parts.append(_c(word, base_color))

	var result := " ".join(parts)

	if pressure > 85.0 and _rng.randf() < 0.18:
		result += "\n" + _c(ENTITY_INTRUSIONS.pick_random(), C_PURPLE)

	return result


func _glitch_word(word: String) -> String:
	var chars := word.split("")
	for i in range(chars.size()):
		if _rng.randf() < 0.35:
			chars[i] = chars[i] + GLITCH_CHARS.pick_random()
	return "".join(chars)


# ── Pressure side-effects ─────────────────────────────────────────────────────

func _on_pressure_changed(value: float) -> void:
	if value >= 90.0:
		_println(_c("!! CRITICAL — ETHERIC PRESSURE AT %.0f%% — SYSTEM DESTABILIZING" % value, C_RED))
		scroll_to_bottom()
	elif value >= 70.0 and fmod(value, 10.0) < GameState.ghost_entities.size() * 0.7:
		_println(_corrupt("!! WARNING: Etheric pressure rising — %.0f%%" % value, C_AMBER))
		scroll_to_bottom()


# ── Path resolution ───────────────────────────────────────────────────────────

func _resolve_path(input_path: String) -> String:
	var p := input_path.strip_edges()
	if not p.begins_with("/"):
		p = (_current_dir.rstrip("/") + "/" + p)
	var parts := p.split("/", false)
	var out: Array[String] = []
	for seg in parts:
		if seg == "..":
			if not out.is_empty():
				out.pop_back()
		elif seg != ".":
			out.append(seg)
	return "/" + "/".join(out)


# ── Tab completion ────────────────────────────────────────────────────────────

func _on_tab_pressed() -> void:
	if _cmd_editor.is_editing():
		return

	var typed := _get_typed_text()

	# Detect whether we're continuing a cycling session or starting fresh.
	var cycling := (
		not _tab_candidates.is_empty()
		and typed == _tab_full_text(_tab_candidates[_tab_idx])
	)

	if not cycling:
		_tab_base_text  = typed
		_tab_candidates = _compute_completions(typed)
		_tab_idx        = -1

		if _tab_candidates.is_empty():
			return

		if _tab_candidates.size() == 1:
			_tab_idx = 0
			_set_input_text(_tab_full_text(_tab_candidates[0]))
			return

		# Multiple matches: print the current prompt line + all candidates,
		# then pre-select the first one so repeated Tab cycles through them.
		_tab_idx = 0
		_println(_c(input.directory, C_DIM) + _c(typed, C_GREEN))
		var parts: Array[String] = []
		for cand in _tab_candidates:
			parts.append(_c(cand, C_CYAN))
		_println("  " + "  ".join(parts))
		scroll_to_bottom()
		_set_input_text(_tab_full_text(_tab_candidates[0]))
		return

	_tab_idx = (_tab_idx + 1) % _tab_candidates.size()
	_set_input_text(_tab_full_text(_tab_candidates[_tab_idx]))


# Builds the full typed line by replacing the last token with `candidate`.
func _tab_full_text(candidate: String) -> String:
	if _tab_base_text.is_empty() or (not _tab_base_text.contains(" ")):
		return candidate
	if _tab_base_text.ends_with(" "):
		return _tab_base_text + candidate
	var parts := _tab_base_text.split(" ")
	parts[-1] = candidate
	return " ".join(parts)


func _compute_completions(typed: String) -> Array[String]:
	var tokens    := typed.split(" ", false)
	var has_space := typed.ends_with(" ")

	# ── Command name (first word, no space yet) ──────────────────────────────
	if tokens.is_empty() or (tokens.size() == 1 and not has_space):
		var partial := tokens[0] if not tokens.is_empty() else ""
		var results: Array[String] = []
		for cmd in KNOWN_COMMANDS:
			if cmd.begins_with(partial):
				results.append(cmd)
		return results

	var raw_cmd   := (tokens[0] as String).to_lower()
	var last_word := "" if has_space else tokens[-1]

	# Resolve aliases so completion logic below is alias-agnostic
	var cmd: String = COMMAND_ALIASES.get(raw_cmd, raw_cmd)

	# ── Server name (ssh / connect) ───────────────────────────────────────────
	if cmd == "ssh":
		var results: Array[String] = []
		for srv in GameState.servers.keys():
			if srv.begins_with(last_word):
				results.append(srv)
		return results

	# ── Ghost PID (kill / chmod / suppress / nullify / banish) ───────────────
	if cmd in ["kill", "chmod", "nullify"]:
		var results: Array[String] = []
		for pid in GameState.ghost_entities.keys():
			if (GameState.ghost_entities[pid] as Dictionary).get("state", "") != "nullified":
				if pid.begins_with(last_word):
					results.append(pid)
		return results

	# ── mv / contain: first arg = PID, second arg = containment dir ──────────
	if cmd == "mv":
		if tokens.size() == 2 and not has_space:
			var results: Array[String] = []
			for pid in GameState.ghost_entities.keys():
				if pid.begins_with(last_word):
					results.append(pid)
			return results
		return _complete_path(last_word, true)

	# ── Dirs-only (cd / ls / map / mkdir / trap) ─────────────────────────────
	if cmd in ["cd", "ls", "mkdir"]:
		return _complete_path(last_word, true)

	# ── Files + dirs (cat / investigate / nano / grep) ────────────────────────
	if cmd in ["cat", "nano", "grep"]:
		return _complete_path(last_word, false)

	return []


func _complete_path(partial: String, dirs_only: bool) -> Array[String]:
	var fs        := GameState.active_filesystem()
	var slash_idx := partial.rfind("/")

	var search_dir:    String
	var file_part:     String
	var result_prefix: String

	if slash_idx == -1:
		search_dir    = _current_dir
		file_part     = partial
		result_prefix = ""
	elif slash_idx == partial.length() - 1:
		search_dir    = _resolve_path(partial)
		file_part     = ""
		result_prefix = partial
	else:
		search_dir    = _resolve_path(partial.substr(0, slash_idx + 1))
		file_part     = partial.substr(slash_idx + 1)
		result_prefix = partial.substr(0, slash_idx + 1)

	if not fs.has(search_dir):
		return []

	var node: Dictionary = fs[search_dir]
	var results: Array[String] = []

	for d in node.get("dirs", []):
		if d.begins_with(file_part):
			results.append(result_prefix + d + "/")

	if not dirs_only:
		for f in node.get("files", []):
			if f.begins_with(file_part):
				results.append(result_prefix + f)

	return results


func _get_typed_text() -> String:
	var full := input.text
	if full.begins_with(input.directory):
		return full.substr(input.directory.length())
	return full


# ── Command dispatch ───────────────────────────────────────────────────────────

func _handle_command(raw: String) -> void:
	var tokens: Array = raw.split(" ", false)
	if tokens.is_empty():
		return
	var cmd: String = (tokens[0] as String).to_lower()
	var args: Array = tokens.slice(1)

	# Resolve aliases → canonical command + adjusted args
	if COMMAND_ALIASES.has(cmd):
		cmd = COMMAND_ALIASES[cmd]
		if cmd == "chmod":          # suppress → chmod 000 <target>
			args = ["000"] + args

	match cmd:
		"help", "status", "tickets", "quests", "missions":
			_cmd_info.dispatch(cmd, raw, args)
		"ssh", "exit", "logout", "ps", "ping", "grep", "sudo":
			_cmd_server.dispatch(cmd, raw, args)
		"cd", "ls", "cat", "mkdir":
			_cmd_filesystem.dispatch(cmd, raw, args)
		"kill", "chmod", "mv", "nullify":
			_cmd_ghost.dispatch(cmd, raw, args)
		"nano", "edit", "vim":
			_cmd_editor.dispatch(cmd, raw, args)
		_:
			println(_corrupt("command not found: %s" % raw, C_RED))


# ── Scroll ─────────────────────────────────────────────────────────────────────

func scroll_to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scrollbar := history_container.get_v_scroll_bar()
	history_container.scroll_vertical = int(scrollbar.max_value)
