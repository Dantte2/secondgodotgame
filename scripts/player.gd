extends CharacterBody2D

# Movement constants
const MOVE_SPEED = 200
const JUMP_VELOCITY = -400
const GRAVITY = 1000

# States
enum PlayerState { IDLE, WALK, JUMP, ATTACK, DASH, DASH_ATTACK }
var state = PlayerState.IDLE

# Combo attack variables
var attack_index = 0
var combo_window = false
var combo_buffered = false

# Dash variables
var is_dashing = false
var can_dash_attack = false
var dash_speed = 500
var dash_time = 0.3
var dash_timer = 0.0
var can_dash = true
const DASH_COOLDOWN = 1.0

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

func _input(event):
	if event.is_action_pressed("attack"):
		if state == PlayerState.ATTACK:
			if combo_window:
				combo_buffered = true
		elif state not in [PlayerState.DASH, PlayerState.DASH_ATTACK]:
			start_attack(1)
	elif event.is_action_pressed("dash"):
		if can_dash and state not in [PlayerState.DASH, PlayerState.DASH_ATTACK, PlayerState.ATTACK]:
			start_dash()
		elif state == PlayerState.DASH and can_dash_attack:
			start_dash_attack()

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
	
	$SpriteHolder/AnimatedSprite2D.play("attack%d" % attack_index)

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

# --- DASH AND DASH ATTACK ---
func start_dash():
	if not can_dash:
		return

	can_dash = false
	state = PlayerState.DASH
	is_dashing = true
	can_dash_attack = true
	dash_timer = dash_time
	$SpriteHolder/AnimatedSprite2D.play("dash")
	start_dash_cooldown()

func start_dash_cooldown():
	await get_tree().create_timer(DASH_COOLDOWN).timeout
	can_dash = true

func start_dash_attack():
	state = PlayerState.DASH_ATTACK
	can_dash_attack = false
	$SpriteHolder/AnimatedSprite2D.play("dash_attack")
	await dash_attack_timer()

func dash_attack_timer():
	await get_tree().create_timer(0.3).timeout
	state = PlayerState.IDLE
	$SpriteHolder/AnimatedSprite2D.play("idle")

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
		PlayerState.DASH_ATTACK:
			velocity.x = 0
			apply_gravity(delta)
			move_and_slide()

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
	apply_gravity(delta)
	move_and_slide()
	if is_on_floor():
		state = PlayerState.IDLE

func apply_gravity(delta):
	velocity.y += GRAVITY * delta

func handle_dash(delta):
	dash_timer -= delta
	velocity.x = dash_speed * facing_direction()
	velocity.y = 0
	move_and_slide()

	if can_dash_attack and Input.is_action_pressed("attack"):
		start_dash_attack()
		return

	if dash_timer <= 0:
		is_dashing = false
		can_dash_attack = false
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
	if state not in [PlayerState.ATTACK, PlayerState.DASH, PlayerState.DASH_ATTACK]:
		match state:
			PlayerState.IDLE:
				if $SpriteHolder/AnimatedSprite2D.animation != "idle":
					$SpriteHolder/AnimatedSprite2D.play("idle")
			PlayerState.WALK:
				if $SpriteHolder/AnimatedSprite2D.animation != "walk":
					$SpriteHolder/AnimatedSprite2D.play("walk")
			PlayerState.JUMP:
				if $SpriteHolder/AnimatedSprite2D.animation != "jump":
					$SpriteHolder/AnimatedSprite2D.play("jump")

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
			body.take_damage(1)  # Adjust damage amount as needed
