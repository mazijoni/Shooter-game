extends CharacterBody3D

# ── Movement ──────────────────────────────────────────────────────────────────
const WALK_SPEED    := 5.0
const RUN_SPEED     := 10.0
const ACCEL         := 22.0
const DECEL         := 18.0
const AIR_ACCEL     := 7.0

# ── Jump ──────────────────────────────────────────────────────────────────────
const JUMP_FORCE        := 5.2
const WALL_JUMP_UP      := 5.5
const WALL_JUMP_AWAY    := 4.5
const WALL_JUMP_FORWARD := 5.5
const COYOTE_TIME       := 0.13
const JUMP_BUFFER_TIME  := 0.15

# ── Slide ─────────────────────────────────────────────────────────────────────
const SLIDE_BOOST_ADD   := 4.5
const SLIDE_MAX_SPEED   := 17.0
const SLIDE_FRICTION    := 6.0
const SLIDE_DURATION    := 0.75
const SLIDE_COOLDOWN    := 0.55

# ── Sprint Effect ─────────────────────────────────────────────────────────────
const SPRINT_FX_FADE_IN   := 6.0    # effect_power lerp-in speed
const SPRINT_FX_FADE_OUT  := 10.0   # effect_power lerp-out speed
const SPRINT_FX_ANIM_FULL := 20.0   # animation_speed when not in slow-mo
const SPRINT_FX_ANIM_SLOW := 4.0    # animation_speed when in slow-mo

# ── Slow-mo ───────────────────────────────────────────────────────────────────
const SLOWMO_SCALE          := 0.25
const SLOWMO_MAX_STAMINA    := 5.0
const SLOWMO_DRAIN_RATE     := 1.0
const SLOWMO_RECHARGE_RATE  := 0.4
const SLOWMO_RECHARGE_DELAY := 1.5

# ── Camera ────────────────────────────────────────────────────────────────────
const MOUSE_SENS        := 0.002   # base value; multiplied by GameSettings.mouse_sensitivity
const CAM_SMOOTH        := 14.0
const CAM_LOOK_LAG      := 35.0
const CAM_TILT_SPEED    := 4.0
const CAM_TILT_MAX      := 0.018
const STAND_CAM_Y       := 1.6
const SLIDE_CAM_Y       := 0.65

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var camera_arm   : Node3D           = $CameraArm
@onready var camera       : Camera3D         = $CameraArm/Camera3D
@onready var stand_col    : CollisionShape3D = $StandShape
@onready var slide_col    : CollisionShape3D = $SlideShape
@onready var ray_left     : RayCast3D        = $WallLeft
@onready var ray_right    : RayCast3D        = $WallRight
@onready var slowmo_bar   : ProgressBar      = $HUD/SlowmoBar
@onready var _speed_lines : ColorRect        = $SpeedLinesLayer/SpeedLines

var _gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")

# ── Runtime state ─────────────────────────────────────────────────────────────
var _coyote_t     := 0.0
var _jump_buf_t   := 0.0
var _slide_t      := 0.0
var _slide_cool_t := 0.0

var _sliding             := false
var _sprinting           := false
var _slowmo              := false
var _slowmo_stamina      := SLOWMO_MAX_STAMINA
var _slowmo_recharge_t   := 0.0
var _blocked_wall_normal := Vector3.ZERO
var _delta_yaw           := 0.0
var _delta_pitch         := 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_delta_yaw   -= event.relative.x * MOUSE_SENS * GameSettings.mouse_sensitivity
		_delta_pitch -= event.relative.y * MOUSE_SENS * GameSettings.mouse_sensitivity


func _process(delta: float) -> void:
	_tick_slowmo(_real(delta))
	_apply_look(delta)
	_smooth_camera(delta)
	_tilt_camera(delta)
	_update_sprint_fx(_real(delta))


func _apply_look(delta: float) -> void:
	var factor := clampf(CAM_LOOK_LAG * delta, 0.0, 1.0) if _slowmo else 1.0

	rotate_y(_delta_yaw * factor)
	_delta_yaw *= (1.0 - factor)

	var new_pitch := camera_arm.rotation.x + _delta_pitch * factor
	camera_arm.rotation.x = clampf(new_pitch, deg_to_rad(-85), deg_to_rad(85))
	_delta_pitch *= (1.0 - factor)


func _physics_process(delta: float) -> void:
	var rd := _real(delta)
	_tick_timers(rd)

	if is_on_floor():
		_blocked_wall_normal = Vector3.ZERO

	_apply_gravity(delta)
	_update_coyote(rd)
	_handle_jump()
	_handle_wall_jump()
	_handle_movement(delta)
	_handle_slide(delta, rd)

	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta


# ── Movement ──────────────────────────────────────────────────────────────────

func _handle_movement(delta: float) -> void:
	if _sliding:
		velocity.x = move_toward(velocity.x, 0.0, SLIDE_FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0.0, SLIDE_FRICTION * delta)
		return

	var speed  := RUN_SPEED if _sprinting else WALK_SPEED
	var dir    := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish   := (transform.basis * Vector3(dir.x, 0.0, dir.y)).normalized()
	var accel  := ACCEL if is_on_floor() else AIR_ACCEL
	var decel  := DECEL if is_on_floor() else AIR_ACCEL * 0.4

	if wish.length() > 0.01:
		velocity.x = move_toward(velocity.x, wish.x * speed, accel * delta)
		velocity.z = move_toward(velocity.z, wish.z * speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		velocity.z = move_toward(velocity.z, 0.0, decel * delta)


# ── Jump ──────────────────────────────────────────────────────────────────────

func _update_coyote(rd: float) -> void:
	if is_on_floor():
		_coyote_t = COYOTE_TIME
	else:
		_coyote_t = max(0.0, _coyote_t - rd)


func _handle_jump() -> void:
	if _jump_buf_t > 0.0 and _coyote_t > 0.0:
		velocity.y  = JUMP_FORCE
		_coyote_t   = 0.0
		_jump_buf_t = 0.0
		if _sliding:
			_end_slide()


func _handle_wall_jump() -> void:
	if _jump_buf_t <= 0.0 or is_on_floor():
		return
	var normal := _wall_normal()
	if normal == Vector3.ZERO:
		return
	if _blocked_wall_normal != Vector3.ZERO and normal.dot(_blocked_wall_normal) > 0.85:
		_jump_buf_t = 0.0
		return

	var dir  := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (transform.basis * Vector3(dir.x, 0.0, dir.y)).normalized()

	var lateral := Vector3(velocity.x, 0.0, velocity.z)
	velocity = lateral * 0.4 \
			 + normal  * WALL_JUMP_AWAY \
			 + Vector3.UP * WALL_JUMP_UP \
			 + wish    * WALL_JUMP_FORWARD

	_jump_buf_t          = 0.0
	_coyote_t            = 0.0
	_blocked_wall_normal = normal


func _wall_normal() -> Vector3:
	if is_on_wall():
		return get_wall_normal()
	if ray_left.is_colliding():
		return ray_left.get_collision_normal()
	if ray_right.is_colliding():
		return ray_right.get_collision_normal()
	return Vector3.ZERO


# ── Slide ─────────────────────────────────────────────────────────────────────

func _handle_slide(_delta: float, rd: float) -> void:
	if _sliding:
		_slide_t -= rd
		if _slide_t <= 0.0:
			_end_slide()
		return

	if _slide_cool_t > 0.0:
		return

	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if Input.is_action_just_pressed("slide") and is_on_floor() and flat_speed > 2.0:
		_start_slide()


func _start_slide() -> void:
	_sliding      = true
	_slide_t      = SLIDE_DURATION
	_slide_cool_t = SLIDE_COOLDOWN

	var flat_vel  := Vector2(velocity.x, velocity.z)
	var cur_speed := flat_vel.length()
	var dir := flat_vel.normalized() if cur_speed > 0.5 else \
			Vector2(-transform.basis.z.x, -transform.basis.z.z).normalized()
	var boosted := minf(cur_speed + SLIDE_BOOST_ADD, SLIDE_MAX_SPEED)
	velocity.x = dir.x * boosted
	velocity.z = dir.y * boosted

	stand_col.disabled = true
	slide_col.disabled = false


func _end_slide() -> void:
	_sliding = false
	stand_col.disabled = false
	slide_col.disabled = true


# ── Slow-mo ───────────────────────────────────────────────────────────────────

func _tick_slowmo(rd: float) -> void:
	if Input.is_action_just_pressed("slowmo"):
		if _slowmo:
			_deactivate_slowmo()
		elif _slowmo_stamina > 0.0:
			_activate_slowmo()

	if _slowmo:
		_slowmo_stamina -= SLOWMO_DRAIN_RATE * rd
		if _slowmo_stamina <= 0.0:
			_slowmo_stamina = 0.0
			_deactivate_slowmo()
		_slowmo_recharge_t = SLOWMO_RECHARGE_DELAY
	else:
		if _slowmo_recharge_t > 0.0:
			_slowmo_recharge_t -= rd
		else:
			_slowmo_stamina = minf(_slowmo_stamina + SLOWMO_RECHARGE_RATE * rd, SLOWMO_MAX_STAMINA)

	slowmo_bar.value = _slowmo_stamina / SLOWMO_MAX_STAMINA


func _activate_slowmo() -> void:
	_slowmo           = true
	Engine.time_scale = SLOWMO_SCALE


func _deactivate_slowmo() -> void:
	_slowmo           = false
	Engine.time_scale = 1.0


# ── Camera ────────────────────────────────────────────────────────────────────

func _smooth_camera(delta: float) -> void:
	var target_y := SLIDE_CAM_Y if _sliding else STAND_CAM_Y
	camera_arm.position.y = lerp(camera_arm.position.y, target_y, CAM_SMOOTH * delta)


func _tilt_camera(delta: float) -> void:
	var strafe := Input.get_axis("move_left", "move_right")
	camera.rotation.z = lerp(camera.rotation.z, -strafe * CAM_TILT_MAX, CAM_TILT_SPEED * delta)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _tick_timers(rd: float) -> void:
	_jump_buf_t   = max(0.0, _jump_buf_t - rd)
	_slide_cool_t = max(0.0, _slide_cool_t - rd)

	if Input.is_action_just_pressed("jump"):
		_jump_buf_t = JUMP_BUFFER_TIME

	if GameSettings.sprint_toggle:
		if Input.is_action_just_pressed("run"):
			_sprinting = not _sprinting
	else:
		_sprinting = Input.is_action_pressed("run")


## Returns real-world delta regardless of Engine.time_scale.
func _real(delta: float) -> float:
	return delta / Engine.time_scale if Engine.time_scale > 0.0 else delta


# ── Sprint Effect ─────────────────────────────────────────────────────────────

func _update_sprint_fx(rd: float) -> void:
	var mat := _speed_lines.material as ShaderMaterial
	var moving  := Vector2(velocity.x, velocity.z).length() > 3.0
	var target  := 1.0 if (_sprinting and moving) else 0.0
	var current := mat.get_shader_parameter("effect_power") as float
	var speed   := SPRINT_FX_FADE_IN if target > current else SPRINT_FX_FADE_OUT
	mat.set_shader_parameter("effect_power", move_toward(current, target, speed * rd))
	mat.set_shader_parameter("animation_speed",
			SPRINT_FX_ANIM_SLOW if _slowmo else SPRINT_FX_ANIM_FULL)
