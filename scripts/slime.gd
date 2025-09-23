extends CharacterBody2D

enum State { ATTACK, DEAD, HURT, IDLE, MOVE, SPLIT }
var current_state = State.IDLE

@export var move_speed := 40
@export var health := 3
@export var player_path: NodePath

var player: Node2D
var hurt_cooldown := 0.0
const HURT_DURATION := 0.3

func _ready():
	player = get_node(player_path)
	_set_state(State.IDLE)

func _physics_process(delta):
	if current_state != State.DEAD:
		hurt_cooldown = max(hurt_cooldown - delta, 0.0)
		_handle_state(delta)

func _handle_state(delta):
	match current_state:
		State.IDLE:
			$spriteholder/AnimatedSprite2D.play("idle")
			if _player_in_range(150):
				_set_state(State.MOVE)

		State.MOVE:
			_move_toward_player(delta)
		
		State.ATTACK:
			if not $spriteholder/AnimatedSprite2D.is_playing():
				_set_state(State.IDLE)

		State.HURT:
			if not $spriteholder/AnimatedSprite2D.is_playing():
				_set_state(State.IDLE)

		State.SPLIT:
			$spriteholder/AnimatedSprite2D.play("split")
			# You could instance smaller slimes here
			_set_state(State.DEAD)

		State.DEAD:
			velocity = Vector2.ZERO
			$spriteholder/AnimatedSprite2D.play("dead")
			queue_free()

func _move_toward_player(delta):
	if player == null:
		return

	var direction = (player.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()

	$spriteholder/AnimatedSprite2D.play("move")

	if global_position.distance_to(player.global_position) < 40:
		_set_state(State.ATTACK)
		$spriteholder/AnimatedSprite2D.play("attack")

func _player_in_range(range):
	return player != null and global_position.distance_to(player.global_position) < range

func _set_state(new_state: State):
	if current_state == new_state:
		return
	current_state = new_state

func take_damage(amount: int):
	if current_state == State.DEAD or hurt_cooldown > 0:
		return

	health -= amount
	hurt_cooldown = HURT_DURATION

	if health <= 0:
		_set_state(State.SPLIT)  # Or State.DEAD if you don't want splitting
	else:
		_set_state(State.HURT)
		$spriteholder/AnimatedSprite2D.play("hurt")
