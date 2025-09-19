extends CharacterBody2D

enum State { IDLE, WALK, ATTACK1, ATTACK2, JUMP_ATTACK, HURT, DEAD }

@export var speed := 50
@export var attack_range := 100
@export var player_path: NodePath  # Assign your player in the editor

var current_state = State.IDLE
var player: Node2D
var health := 10  # Add health variable

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

func _physics_process(delta):
	_face_player()  # Flip boss to face player every frame

	match current_state:
		State.IDLE:
			_process_idle()
		State.WALK:
			_process_walk(delta)
		State.ATTACK1:
			_process_attack1()
		State.ATTACK2:
			_process_attack2()
		State.JUMP_ATTACK:
			_process_jump_attack()
		State.HURT:
			_process_hurt()
		State.DEAD:
			pass  # No actions when dead

# === FACE PLAYER ===

func _face_player():
	if player.global_position.x < global_position.x:
		$AnimatedSprite2D.flip_h = false  # Face left
	else:
		$AnimatedSprite2D.flip_h = true  # Face right

# === STATE HANDLERS ===

func _set_state(new_state):
	if current_state == new_state:
		return
	current_state = new_state

	# Always disable hitbox when changing states
	disable_hitbox()

	match current_state:
		State.IDLE:
			$AnimatedSprite2D.play("idle")
			_enable_collision(true)
		State.WALK:
			$AnimatedSprite2D.play("walk")
			_enable_collision(true)
		State.ATTACK1:
			$AnimatedSprite2D.play("attack1")
			_enable_collision(true)
		State.ATTACK2:
			$AnimatedSprite2D.play("attack2")
			_enable_collision(true)
		State.JUMP_ATTACK:
			$AnimatedSprite2D.play("jump_attack")
			_enable_collision(true)
		State.HURT:
			$AnimatedSprite2D.play("hurt")
			_enable_collision(true)
		State.DEAD:
			$AnimatedSprite2D.play("dead")
			_enable_collision(false)  # Disable collisions on death

func _enable_collision(enabled: bool):
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", not enabled)

func _process_idle():
	if _player_in_range():
		_set_state(State.ATTACK1)
	elif _player_close_enough():
		_set_state(State.WALK)

func _process_walk(delta):
	var direction = sign(player.global_position.x - global_position.x)
	velocity.x = direction * speed
	move_and_slide()

	if _player_in_range():
		_set_state(State.ATTACK1)

func _process_attack1():
	if not $AnimatedSprite2D.is_playing():
		_set_state(State.IDLE)

func _process_attack2():
	pass  # Implement as needed

func _process_jump_attack():
	pass  # Implement as needed

func _process_hurt():
	if not $AnimatedSprite2D.is_playing():
		_set_state(State.IDLE)

# === HELPER FUNCTIONS ===

func _player_close_enough() -> bool:
	return global_position.distance_to(player.global_position) < 200

func _player_in_range() -> bool:
	return global_position.distance_to(player.global_position) < attack_range

# === ATTACK HITBOX CONTROL ===

func enable_hitbox():
	$attackhitbox.monitoring = true
	$attackhitbox.set_deferred("monitorable", true)

func disable_hitbox():
	$attackhitbox.monitoring = false
	$attackhitbox.set_deferred("monitorable", false)

# === ANIMATION-BASED HITBOX TRIGGERING ===

func _on_animated_sprite_2d_frame_changed() -> void:
	var anim = $AnimatedSprite2D.animation
	var frame = $AnimatedSprite2D.frame

	if anim == "attack1":
		if frame == 3:
			enable_hitbox()
		elif frame == 6:
			disable_hitbox()
