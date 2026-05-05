extends CanvasLayer

@onready var pause_panel    : Control = $Bg/PausePanel
@onready var settings_panel : Control = $Bg/SettingsPanel


func _ready() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		if not visible:
			_pause()
		elif settings_panel.visible:
			_on_settings_back()
		else:
			_resume()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	show()
	pause_panel.show()
	settings_panel.hide()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _resume() -> void:
	hide()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_resume_pressed() -> void:
	_resume()


func _on_settings_pressed() -> void:
	pause_panel.hide()
	settings_panel.show()


func _on_settings_back() -> void:
	settings_panel.hide()
	pause_panel.show()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
