extends Control

signal back_pressed

@onready var sensitivity_slider : HSlider    = $Center/VBox/SensRow/SensitivitySlider
@onready var sens_value_label   : Label      = $Center/VBox/SensRow/SensValueLabel
@onready var volume_slider      : HSlider    = $Center/VBox/VolRow/VolumeSlider
@onready var vol_value_label    : Label      = $Center/VBox/VolRow/VolValueLabel
@onready var fullscreen_check   : CheckButton = $Center/VBox/FSRow/FullscreenCheck
@onready var sprint_toggle_check : CheckButton = $Center/VBox/SprintRow/SprintToggleCheck


func _ready() -> void:
	# Block signal callbacks while populating controls from saved values
	sensitivity_slider.set_block_signals(true)
	volume_slider.set_block_signals(true)
	fullscreen_check.set_block_signals(true)
	sprint_toggle_check.set_block_signals(true)

	sensitivity_slider.value        = GameSettings.mouse_sensitivity
	volume_slider.value             = GameSettings.master_volume
	fullscreen_check.button_pressed  = GameSettings.fullscreen
	sprint_toggle_check.button_pressed = GameSettings.sprint_toggle

	sensitivity_slider.set_block_signals(false)
	volume_slider.set_block_signals(false)
	fullscreen_check.set_block_signals(false)
	sprint_toggle_check.set_block_signals(false)

	_refresh_labels()


func _refresh_labels() -> void:
	sens_value_label.text = "%.1fx" % sensitivity_slider.value
	vol_value_label.text  = "%d%%" % roundi(volume_slider.value * 100.0)


func _on_sensitivity_changed(value: float) -> void:
	GameSettings.mouse_sensitivity = value
	GameSettings.save()
	_refresh_labels()


func _on_volume_changed(value: float) -> void:
	GameSettings.master_volume = value
	GameSettings._apply_volume()
	GameSettings.save()
	_refresh_labels()


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	GameSettings.fullscreen = toggled_on
	GameSettings._apply_fullscreen()
	GameSettings.save()


func _on_sprint_toggle_toggled(toggled_on: bool) -> void:
	GameSettings.sprint_toggle = toggled_on
	GameSettings.save()


func _on_back_pressed() -> void:
	back_pressed.emit()
