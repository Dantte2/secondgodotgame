extends CharacterBody2D

# Movement constants
const MOVE_SPEED = 200

const GRAVITY = 1500  # stronger gravity for snappier fall
const FALL_MULTIPLIER = 3.0  # faster fall speed
const LOW_JUMP_MULTIPLIER = 4.0  # cut jump height if jump released early
const JUMP_VELOCITY = -800  # stronger jump

# States
enum PlayerState { IDLE, WALK, JUMP, ATTACK, DASH }
var state = PlayerState.IDLE

# Combo attack variables
var attack_index = 0
var combo_window = false
var combo_buffered = false

# Dash variables
var is_dashing = false
var dash_speed = 500
var dash_time = 0.3
var dash_timer = 0.0
var can_dash = true
const DASH_COOLDOWN = 0.5  # shorter cooldown

# Hitbox related
var enemies_hit = []


func _ready():
	$SpriteHolder/AnimatedSprite2D.animation = "idle"
	$SpriteHolder/AnimatedSprite2D.play()
	
	# Make sure hitbox is off initially
	$SpriteHolder/attackhitbox.monitoring = false
	$SpriteHolder/attackhitbox.monitorable = false
	
	# Connect hitbox signal
	$SpriteHolder/attackhitbox.connect("body_entered", Callable(self, "_on_attackhitbox_body_entered"))

	# Connect slash effect animation finished signal to hide it
	$SpriteHolder/attackhitbox/SlashEffect.connect("animation_finished", Callable(self, "_on_slash_animation_finished"))
	$SpriteHolder/attackhitbox/SlashEffect.hide()

	z_index = 10

func _on_slash_animation_finished():
	$SpriteHolder/attackhitbox/SlashEffect.hide()

func _input(event):
	if event.is_action_pressed("attack"):
		if state == PlayerState.ATTACK:
			if combo_window:
				combo_buffered = true
		elif state != PlayerState.DASH:  # can attack if not dashing
			start_attack(1)
	elif event.is_action_pressed("dash"):
		if can_dash and state not in [PlayerState.DASH, PlayerState.ATTACK]:
			start_dash()

# --- COMBO ATTACK SYSTEM ---
func start_attack(index):
	state = PlayerState.ATTACK
	attack_index = index
	combo_window = false
	combo_buffered = false
	
	flip_attack_hitbox()

	$SpriteHolder/attackhitbox.monitoring = true
	$SpriteHolder/attackhitbox.monitorable = true
	
	enemies_hit.clear()
	
	# Play main attack animation on player sprite
	$SpriteHolder/AnimatedSprite2D.play("attack%d" % attack_index)

	# Play corresponding slash animation on SlashEffect
	var slash_effect = $SpriteHolder/attackhitbox/SlashEffect
	match attack_index:
		1:
			slash_effect.animation = "slash3"
		2:
			slash_effect.animation = "slash2"
		3:
			slash_effect.animation = "slash3"
	slash_effect.show()
	slash_effect.play()

	var combo_open_time = 0.15
	var combo_close_time = 0.4
	await get_tree().create_timer(combo_open_time).timeout
	combo_window = true
	await get_tree().create_timer(combo_close_time - combo_open_time).timeout
	combo_window = false

	$SpriteHolder/attackhitbox.monitoring = false
	$SpriteHolder/attackhitbox.monitorable = false

	await get_tree().create_timer(0.1).timeout

	if combo_buffered and attack_index < 3:
		combo_buffered = false
		start_attack(attack_index + 1)
	else:
		attack_index = 0
		state = PlayerState.IDLE
		$SpriteHolder/AnimatedSprite2D.play("idle")

# --- DASH ---
func start_dash():
	if not can_dash:
		return

	can_dash = false
	state = PlayerState.DASH
	is_dashing = true
	dash_timer = dash_time
	$SpriteHolder/AnimatedSprite2D.play("dash")
	start_dash_cooldown()

func start_dash_cooldown():
	await get_tree().create_timer(DASH_COOLDOWN).timeout
	can_dash = true

# --- PHYSICS ---
func _physics_process(delta):
	update_facing_direction()

	match state:
		PlayerState.IDLE, PlayerState.WALK:
			handle_movement(delta)
		PlayerState.JUMP:
			handle_jump(delta)
		PlayerState.ATTACK:
			velocity.x = 0
			apply_gravity(delta)
			move_and_slide()
		PlayerState.DASH:
			handle_dash(delta)

	update_animation()

# --- MOVEMENT AND JUMP ---
func handle_movement(delta):
	var dir = 0
	if Input.is_action_pressed("move_left"):
		dir -= 1
	if Input.is_action_pressed("move_right"):
		dir += 1

	velocity.x = dir * MOVE_SPEED

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			state = PlayerState.JUMP
		elif dir != 0:
			state = PlayerState.WALK
		else:
			state = PlayerState.IDLE
	else:
		apply_gravity(delta)

	move_and_slide()

func handle_jump(delta):
	var dir = 0
	if Input.is_action_pressed("move_left"):
		dir -= 1
	if Input.is_action_pressed("move_right"):
		dir += 1

	velocity.x = dir * MOVE_SPEED

	# Apply better gravity like Hollow Knight
	if velocity.y < 0:  # Going up
		if not Input.is_action_pressed("jump"):
			velocity.y += GRAVITY * LOW_JUMP_MULTIPLIER * delta
		else:
			velocity.y += GRAVITY * delta
	else:  # Falling
		velocity.y += GRAVITY * FALL_MULTIPLIER * delta

	move_and_slide()

	if is_on_floor():
		state = PlayerState.IDLE

func apply_gravity(delta):
	if velocity.y < 0:
		if not Input.is_action_pressed("jump"):
			velocity.y += GRAVITY * LOW_JUMP_MULTIPLIER * delta
		else:
			velocity.y += GRAVITY * delta
	else:
		velocity.y += GRAVITY * FALL_MULTIPLIER * delta

# --- DASH ---
func handle_dash(delta):
	dash_timer -= delta
	velocity.x = dash_speed * facing_direction()
	velocity.y = 0
	move_and_slide()

	if dash_timer <= 0:
		is_dashing = false
		state = PlayerState.IDLE
		$SpriteHolder/AnimatedSprite2D.play("idle")

func facing_direction():
	# Return 1 for right, -1 for left based on SpriteHolder scale
	return -1 if $SpriteHolder.scale.x > 0 else 1

# --- FLIP THE SPRITE HOLDER FOR VISUAL FLIP ---
func update_facing_direction():
	if Input.is_action_pressed("move_left"):
		$SpriteHolder.scale.x = 1
	elif Input.is_action_pressed("move_right"):
		$SpriteHolder.scale.x = -1

# --- ANIMATION UPDATING ---
func update_animation():
	if state in [PlayerState.ATTACK, PlayerState.DASH]:
		return

	if not is_on_floor() and velocity.y > 0:
		if $SpriteHolder/AnimatedSprite2D.animation != "fall":
			$SpriteHolder/AnimatedSprite2D.play("fall")
		return

	match state:
		PlayerState.IDLE:
			if $SpriteHolder/AnimatedSprite2D.animation != "idle":
				$SpriteHolder/AnimatedSprite2D.play("idle")

		PlayerState.WALK:
			if $SpriteHolder/AnimatedSprite2D.animation != "walk":
				$SpriteHolder/AnimatedSprite2D.play("walk")

		PlayerState.JUMP:
			if velocity.y < 0:
				if $SpriteHolder/AnimatedSprite2D.animation != "jump":
					$SpriteHolder/AnimatedSprite2D.play("jump")

		PlayerState.DASH:
			if $SpriteHolder/AnimatedSprite2D.animation != "dash":
				$SpriteHolder/AnimatedSprite2D.play("dash")

# --- Flip attack hitbox position ---
func flip_attack_hitbox():
	var hb_pos = $SpriteHolder/attackhitbox.position
	if $SpriteHolder.scale.x < 0:
		$SpriteHolder/attackhitbox.position.x = abs(hb_pos.x)
	else:
		$SpriteHolder/attackhitbox.position.x = -abs(hb_pos.x)

# --- Hitbox collision handling ---
func _on_attackhitbox_body_entered(body):
	if body.is_in_group("enemies") and body not in enemies_hit:
		enemies_hit.append(body)
		if body.has_method("take_damage"):
			body.take_damage(1)  # Adjust damage amount here
