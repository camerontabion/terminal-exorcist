extends LineEdit

signal history_up
signal history_down
signal tab_pressed

var directory: String = ">  "


func reset() -> void:
	text = directory
	caret_column = len(text)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	var at_edge := caret_column <= directory.length()

	match event.keycode:
		KEY_BACKSPACE:
			if event.meta_pressed or event.ctrl_pressed:
				# Cmd/Ctrl+Backspace: erase typed input but keep the prompt
				if not at_edge:
					text = text.substr(0, directory.length())
					caret_column = directory.length()
				accept_event()
			elif event.alt_pressed and at_edge:
				# Option+Backspace at prompt boundary: block
				accept_event()
			elif at_edge:
				accept_event()
		KEY_DELETE:
			if caret_column < directory.length():
				accept_event()
		KEY_LEFT:
			if at_edge:
				accept_event()
		KEY_HOME:
			caret_column = directory.length()
			accept_event()
		KEY_UP:
			history_up.emit()
			accept_event()
		KEY_DOWN:
			history_down.emit()
			accept_event()
		KEY_TAB:
			tab_pressed.emit()
			accept_event()


func _input(event: InputEvent) -> void:
	if not has_focus():
		return
	if event is InputEventMouseButton and event.pressed:
		await get_tree().process_frame
		if caret_column < directory.length():
			caret_column = directory.length()
