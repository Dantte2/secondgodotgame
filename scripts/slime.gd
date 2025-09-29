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
    player = get_node_or_null(player_path)
    print("Player reference is: ", player)
    _set_state(State.IDLE)

func _physics_process(delta):
    if current_state != State.DEAD:
        hurt_cooldown = max(hurt_cooldown - delta, 0.0)
        _handle_state(delta)

func _handle_state(delta):
    print("Current state:", current_state)
    match current_state:
        State.IDLE:
            _play_anim("idle")
            if _player_in_range(150):
                print("Player is in range → switching to MOVE")
                _set_state(State.MOVE)

        State.MOVE:
            _move_toward_player(delta)

        State.ATTACK:
            if not _is_anim_playing("attack"):
                _set_state(State.IDLE)

        State.HURT:
            if not _is_anim_playing("hurt"):
                _set_state(State.IDLE)

        State.SPLIT:
            _play_anim("split")
            _set_state(State.DEAD)

        State.DEAD:
            velocity = Vector2.ZERO
            _play_anim("dead")
            queue_free()

func _move_toward_player(delta):
    if player == null:
        return
    var direction = (player.global_position - global_position).normalized()
    velocity = direction * move_speed
    move_and_slide()
    _play_anim("move")
    if global_position.distance_to(player.global_position) < 40:
        print("Close enough → ATTACK")
        _set_state(State.ATTACK)
        _play_anim("attack")

func _player_in_range(range):
    if player == null:
        return false
    var dist = global_position.distance_to(player.global_position)
    print("Distance to player:", dist)
    return dist < range

func _set_state(new_state: State):
    if current_state == new_state:
        return
    print("Changing state from", current_state, "to", new_state)
    current_state = new_state

func take_damage(amount: int):
    if current_state == State.DEAD or hurt_cooldown > 0:
        return
    health -= amount
    hurt_cooldown = HURT_DURATION
    if health <= 0:
        _set_state(State.SPLIT)
    else:
        _set_state(State.HURT)
        _play_anim("hurt")

func _play_anim(anim_name: String):
    if $spriteholder/AnimatedSprite2D.animation != anim_name or !$spriteholder/AnimatedSprite2D.is_playing():
        $spriteholder/AnimatedSprite2D.play(anim_name)

func _is_anim_playing(anim_name: String) -> bool:
    return $spriteholder/AnimatedSprite2D.animation == anim_name and $spriteholder/AnimatedSprite2D.is_playing()
