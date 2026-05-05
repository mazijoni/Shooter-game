extends Control

@onready var menu_panel     : Control = $MenuPanel
@onready var settings_panel : Control = $SettingsPanel


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/test_map.tscn")


func _on_settings_pressed() -> void:
	menu_panel.hide()
	settings_panel.show()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_settings_back() -> void:
	settings_panel.hide()
	menu_panel.show()
