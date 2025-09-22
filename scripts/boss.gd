extends CharacterBody2D

enum State { IDLE, WALK, ATTACK1, ATTACK2, JUMP_ATTACK, SMASH, HURT, DEAD }

@export var speed := 50
@export var attack_range := 100
@export var aggro_range := 300
@export var smash_chance := 0.3
@export var attack2_cooldown_duration := 10.0  # seconds
@export var player_path: NodePath

var current_state = State.IDLE
var player: Node2D
var health := 10

var attack2_cooldown := 0.0

func _ready():
	player = get_node(player_path)
	_set_state(State.IDLE)

	if has_node("hpbar"):
		$hpbar.max_value = health
		$hpbar.value = health

func take_damage(amount):
	health -= amount
	if has_node("hpbar"):
		$hpbar.value = health

	if health <= 0:
		_set_state(State.DEAD)
	else:
		_set_state(State.HURT)
	z_index = 5

func _physics_process(delta):
	_face_player()
	attack2_cooldown = max(attack2_cooldown - delta, 0.0)

	match current_state:
		State.IDLE:
			_process_idle()
		State.WALK:
			_process_walk(delta)
		State.ATTACK1:
			_process_attack1()
		State.ATTACK2:
			_process_attack2(delta)
		State.JUMP_ATTACK:
			_process_jump_attack()
		State.SMASH:
			_process_smash()
		State.HURT:
			_process_hurt()
		State.DEAD:
			pass

# === FACE PLAYER ===
func _face_player():
	if player.global_position.x < global_position.x:
		$SpriteHolder.scale.x = 1
	else:
		$SpriteHolder.scale.x = -1
	flip_attack_hitbox()

func flip_attack_hitbox():
	var base_pos_x = abs($SpriteHolder/attackhitbox.position.x)
	if $SpriteHolder/attackhitbox.scale.x < 0:
		$SpriteHolder/attackhitbox.position.x = -base_pos_x
	else:
		$SpriteHolder/attackhitbox.position.x = base_pos_x

# === STATE HANDLERS ===
func _set_state(new_state):
	if current_state == new_state:
		return
	current_state = new_state
	disable_hitbox()

	match current_state:
		State.IDLE:
			$SpriteHolder/AnimatedSprite2D.play("idle")
			_enable_collision(true)
		State.WALK:
			$SpriteHolder/AnimatedSprite2D.play("walk")
			_enable_collision(true)
		State.ATTACK1:
			$SpriteHolder/AnimatedSprite2D.play("attack1")
			_enable_collision(true)
		State.ATTACK2:
			$SpriteHolder/AnimatedSprite2D.play("attack2")
			_enable_collision(true)
		State.JUMP_ATTACK:
			$SpriteHolder/AnimatedSprite2D.play("jump_attack")
			_enable_collision(true)
		State.SMASH:
			$SpriteHolder/AnimatedSprite2D.play("smash")
			_enable_collision(true)
		State.HURT:
			$SpriteHolder/AnimatedSprite2D.play("hurt")
			_enable_collision(true)
		State.DEAD:
			$SpriteHolder/AnimatedSprite2D.play("dead")
			_enable_collision(false)

func _enable_collision(enabled: bool):
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", not enabled)

# === AI ===
func _process_idle():
	var dist = global_position.distance_to(player.global_position)

	if dist < attack_range:
		if randf() < smash_chance:
			_set_state(State.SMASH)
		else:
			_set_state(State.ATTACK1)
	elif dist < aggro_range:
		if attack2_cooldown <= 0:
			_set_state(State.ATTACK2)
		else:
			_set_state(State.WALK)  
	else:
		_set_state(State.IDLE)


func _process_walk(delta):
	var dist = global_position.distance_to(player.global_position)
	var direction = sign(player.global_position.x - global_position.x)
	velocity.x = direction * speed
	move_and_slide()

	if dist < attack_range:
		if randf() < smash_chance:
			_set_state(State.SMASH)
		else:
			_set_state(State.ATTACK1)
	elif dist < aggro_range:
		if attack2_cooldown <= 0:
			_set_state(State.ATTACK2)
		# else: keep walking
	else:
		_set_state(State.IDLE)


# === ATTACK STATES ===

func _process_attack1():
	if not $SpriteHolder/AnimatedSprite2D.is_playing():
		_set_state(State.IDLE)

func _process_attack2(delta):
	var direction = sign(player.global_position.x - global_position.x)
	velocity.x = direction * speed * 2
	move_and_slide()

	if not $SpriteHolder/AnimatedSprite2D.is_playing():
		attack2_cooldown = attack2_cooldown_duration
		_set_state(State.IDLE)

func _process_jump_attack():
	pass

func _process_smash():
	if not $SpriteHolder/AnimatedSprite2D.is_playing():
		_set_state(State.IDLE)

func _process_hurt():
	if not $SpriteHolder/AnimatedSprite2D.is_playing():
		_set_state(State.IDLE)

# === ATTACK HITBOX ===

func enable_hitbox():
	$SpriteHolder/attackhitbox.monitoring = true
	$SpriteHolder/attackhitbox.set_deferred("monitorable", true)

func disable_hitbox():
	$SpriteHolder/attackhitbox.monitoring = false
	$SpriteHolder/attackhitbox.set_deferred("monitorable", false)

# === ANIMATION FRAME HITBOX EVENTS ===

func _on_animated_sprite_2d_frame_changed() -> void:
	var anim = $SpriteHolder/AnimatedSprite2D.animation
	var frame = $SpriteHolder/AnimatedSprite2D.frame

	if anim == "attack1":
		if frame == 3:
			enable_hitbox()
		elif frame == 6:
			disable_hitbox()
	elif anim == "smash":
		if frame == 4:
			enable_hitbox()
		elif frame == 8:
			disable_hitbox()
