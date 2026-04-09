extends Node

var _t      # terminal reference
var _ghost  # cmd_ghost reference — needed for nullify-from-edit
var _fs     # cmd_filesystem reference — needed for get_file_content

enum Mode { NORMAL, EDITING }
var _mode:       Mode          = Mode.NORMAL
var _edit_path:  String        = ""
var _edit_lines: Array[String] = []

const C_GREEN  := "#33ff66"
const C_RED    := "#ff3333"
const C_PURPLE := "#cc44ff"
const C_AMBER  := "#ffaa00"
const C_CYAN   := "#44aaff"
const C_DIM    := "#1a7a35"
const C_WHITE  := "#d8d8d8"


func setup(term, ghost, fs) -> void:
	_t     = term
	_ghost = ghost
	_fs    = fs


func is_editing() -> bool:
	return _mode == Mode.EDITING


func dispatch(cmd: String, _raw: String, args: Array) -> void:
	match cmd:
		"nano", "edit", "vim": _cmd_nano(args)


# ── Commands ──────────────────────────────────────────────────────────────────

func _cmd_nano(args: Array) -> void:
	if args.is_empty():
		_print_error("usage: nano <file>")
		return

	var full_path: String = _t.resolve_path(str(args[0]))
	var fs        := GameState.active_filesystem()

	if fs.has(full_path):
		_print_error("nano: %s: Is a directory" % str(args[0]))
		return

	var slash  := full_path.rfind("/")
	var parent := full_path.substr(0, slash) if slash > 0 else "/"
	var fname  := full_path.substr(slash + 1)

	if not fs.has(parent) or fname not in fs[parent].get("files", []):
		_print_error("nano: %s: No such file or directory" % str(args[0]))
		return

	var edit_key := GameState.current_server + full_path
	var content: String
	if GameState.file_edits.has(edit_key):
		content = GameState.file_edits[edit_key]
	else:
		content = _fs.get_file_content(GameState.current_server, full_path)

	_edit_lines = Array(content.split("\n"))
	_edit_path  = full_path
	_mode       = Mode.EDITING

	var host_label: String = GameState.current_server if GameState.current_server != "" else "local"
	var user_label: String = "admin" if GameState.current_server == "" else str(GameState.servers[GameState.current_server].get("user", "root"))
	_sep()
	_println(_c("  NANO  %s@%s:%s" % [user_label, host_label, full_path], C_CYAN))
	_println(_c("  :wq = save & exit   :q! = discard   <n>: text = replace line n", C_DIM))
	_sep()
	_print_edit_buffer()
	_println(_c("  \u2500 edit mode active \u2500", C_AMBER))
	_t.set_edit_mode_active(true)


func handle_edit_input(raw: String) -> void:
	if raw == ":q!" or raw == ":quit!":
		_exit_edit_mode(false)
		return
	if raw == ":wq" or raw == ":w" or raw == ":x" or raw == "save":
		_exit_edit_mode(true)
		return

	var colon_idx := raw.find(":")
	if colon_idx > 0:
		var num_str := raw.substr(0, colon_idx).strip_edges()
		if num_str.is_valid_int():
			var n := num_str.to_int() - 1
			if n >= 0 and n < _edit_lines.size():
				_edit_lines[n] = raw.substr(colon_idx + 1).strip_edges()
				_println(_c("  line %d updated." % (n + 1), C_GREEN))
				_print_edit_buffer()
				return
			else:
				_println(_c("  line %d out of range (1\u2013%d)." % [n + 1, _edit_lines.size()], C_RED))
				return

	_edit_lines.append(raw)
	_println(_c("  line %d appended." % _edit_lines.size(), C_DIM))
	_print_edit_buffer()


func _print_edit_buffer() -> void:
	for i in range(_edit_lines.size()):
		var num  := _c("%3d" % (i + 1), C_DIM)
		var line := _edit_lines[i]
		var color := C_RED if ("payload" in line.to_lower() or "PLEASE" in line or "LET ME" in line) else C_WHITE
		_println(num + _c("  \u2502  ", C_DIM) + _c(line, color))


func _exit_edit_mode(save: bool) -> void:
	if save:
		var new_content := "\n".join(_edit_lines)
		var edit_key    := GameState.current_server + _edit_path
		GameState.file_edits[edit_key] = new_content
		_println(_c("  Written %d lines to %s." % [_edit_lines.size(), _edit_path], C_GREEN))

		# Editing entity.json with NULL_SIGNAL payload triggers nullification
		if _edit_path.ends_with("entity.json"):
			var parts := _edit_path.split("/", false)
			var pid := parts[parts.size() - 2] if parts.size() >= 2 else ""
			if GameState.ghost_entities.has(pid):
				for line in _edit_lines:
					if "NULL_SIGNAL" in line or '"payload": "null"' in line.to_lower():
						_println(_c("  Payload rewritten — triggering nullification ...", C_AMBER))
						_mode       = Mode.NORMAL
						_edit_path  = ""
						_edit_lines = []
						_t.set_edit_mode_active(false)
						_ghost.dispatch("nullify", "", [pid])
						return
	else:
		_println(_c("  Edit discarded.", C_DIM))

	_mode       = Mode.NORMAL
	_edit_path  = ""
	_edit_lines = []
	_sep()
	_t.set_edit_mode_active(false)


# ── Output delegates ──────────────────────────────────────────────────────────

func _println(text: String) -> void: _t.println(text)
func _c(t: String, color: String) -> String: return _t.c(t, color)
func _print_error(msg: String) -> void: _t.print_error(msg)
func _sep() -> void: _t.sep()
