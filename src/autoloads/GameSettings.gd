extends Node

const CONFIG_PATH := "user://settings.cfg"

# mouse_sensitivity is a multiplier: 1.0 = default, range 0.1–3.0
var mouse_sensitivity : float = 1.0
var master_volume     : float = 1.0
var fullscreen        : bool  = false
var sprint_toggle     : bool  = false


func _ready() -> void:
	_load()
	_apply_volume()
	_apply_fullscreen()


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))


func _apply_fullscreen() -> void:
	if OS.has_feature("editor"):
		return  # embedded editor window doesn't support fullscreen
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen \
			else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input",   "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("input",   "sprint_toggle",     sprint_toggle)
	cfg.set_value("audio",   "master_volume",     master_volume)
	cfg.set_value("display", "fullscreen",        fullscreen)
	cfg.save(CONFIG_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	mouse_sensitivity = cfg.get_value("input",   "mouse_sensitivity", 1.0)
	sprint_toggle     = cfg.get_value("input",   "sprint_toggle",     false)
	master_volume     = cfg.get_value("audio",   "master_volume",     1.0)
	fullscreen        = cfg.get_value("display", "fullscreen",        false)
