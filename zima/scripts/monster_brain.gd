@tool
class_name MonsterBrain
extends CharacterBody3D
## Enemy behavior of the PSX Sea Horror Monsters pack (bitkiln - https://bitkiln.itch.io).
## Version 2 (PSX Sea Horror Monsters, October 2026). Version 1 is the script of PSX Horror Monsters (it has no
## version line): this one does everything version 1 does and runs that pack's monster scenes, too, so a project
## with both packs keeps this one.
##
## Put this script on a CharacterBody3D that has a collision shape and the monster model (any scene with an
## AnimationPlayer, for example one of the pack's GLB files) as children. Every monster scene of the pack
## (res://monsters/<name>/<name>.tscn) is set up like that and already uses it.
##
## States
##   IDLE    stands still (Idle clip), sometimes plays one of idle_variations, then starts to wander or walks to
##           its next patrol point (with start_dormant it waits frozen in the first frame of anim_wake until a
##           target comes within detect_range or it gets hurt; then it plays anim_wake once and hunts). A monster
##           that gives up a hunt plays anim_retract first, when it has one
##   WANDER  strolls to a random point near its start position, or to the next of patrol_points (Walk clip)
##   CHASE   runs at the target (Run clip, or Walk when use_run is off); plays anim_alert once when it spots one.
##           A stationary monster stays on its spot instead: it plays anim_stationary and turns toward the target
##           (as far as turn_limit allows) until the target comes within reach. hunt() starts a chase at once and
##           keeps it going from any distance
##   ATTACK  plays Attack or Attack2 (picked at random when both reach; a walking monster whose Attack2 reaches
##           less far steps in closer for it now and then); the blow lands attack_hit_time seconds into the clip,
##           but only if the target is still within reach and in front of the monster
##   HIT     plays Hit after damage, then hunts the attacker. A hit interrupts an attack, except in the last
##           attack_commit_time seconds before its blow lands; after a Hit the monster acts for flinch_cooldown
##           seconds before damage can make it flinch again (blows weaker than flinch_min_damage never do). An
##           attack cut short after its blow counts to the end of its clip before attack_cooldown starts
##   DEAD    plays Death once, stops blocking players, monsters and bullets, emits died; glowing eyes, lures and
##           a carried light fade out (fade_glow_on_death)
##
## Targets are the nodes in target_group ("player" by default). A target may have the methods
## take_damage(amount: float, from_position: Vector3) and is_dead() -> bool; both are optional.
##
## The models face +Z (the glTF convention), so the brain turns the body until +Z points where it goes.
## With a NavigationAgent3D child and a navigation mesh in the level the monster follows paths around walls (a new
## path every second, so a monster that was pushed aside does not walk back to a point it already passed); without
## them it heads straight for its goal and slides along whatever is in the way. When the agent has Avoidance
## Enabled (the pack's monster scenes do), monsters on a navigation mesh also steer around each other instead of
## pushing; the brain sets the agent's max_speed to the speed it wants, so a monster never dodges faster than it
## walks or runs.
## Animation names are the pack's (Idle, Walk, Run, Attack, Attack2, Hit, Death, Emerge...); change them in the
## Animations group to use the script with your own models.

## Emitted on every state change (values of State).
signal state_changed(new_state: int, old_state: int)
## A target was noticed (seen, or it hurt the monster).
signal target_spotted(new_target: Node3D)
## The monster gave up the chase (target too far, out of sight for forget_time, or dead).
signal target_lost
## An attack clip started (Attack or Attack2).
signal attack_started(animation: StringName)
## A blow landed on the target (the target's take_damage() was called).
signal attack_landed(victim: Node, amount: float)
## The monster took damage (health_left is the health after it).
signal damaged(amount: float, health_left: float)
## A dormant monster came alive (anim_wake started).
signal woke_up
## Health reached 0; the Death clip is playing.
signal died

enum State { IDLE, WANDER, CHASE, ATTACK, HIT, DEAD }

## Name shown by the demo scenes.
@export var monster_name := ""
## Off: the monster stands still and ignores targets and damage (the showcase drives the clips itself).
@export var active := true

@export_group("Target")
## Group of the nodes this monster hunts. The demo player adds itself to "player".
@export var target_group: StringName = &"player"
## A target closer than this (meters) is noticed. A dormant monster wakes up when a target comes this close.
@export var detect_range := 12.0
## The chase ends when the target gets farther away than this (not while hunt() makes it hunt the target).
@export var lose_range := 20.0
## Only notice targets that are not hidden behind walls. Damage always wakes the monster up.
@export var need_line_of_sight := true
## Physics layers that block the view (and that the monster keeps standing on when it is dead).
@export_flags_3d_physics var sight_mask := 1
## Height of the eyes above the origin, for the line of sight.
@export var eye_height := 1.5
## How far in front of the origin the eyes are (meters), for monsters whose origin sits in a wall.
@export var eye_forward := 0.0
## Seconds the monster keeps hunting a target it can no longer see (not while hunt() makes it hunt the target).
@export var forget_time := 6.0

@export_group("Movement")
## Speed while wandering, in meters per second.
@export var walk_speed := 0.8
## Speed while chasing.
@export var run_speed := 2.0
## Chase with run_speed and the Run clip. Off: chase at walk_speed with the Walk clip.
@export var use_run := true
## How quickly the speed changes (higher = snappier).
@export var acceleration := 8.0
## Turning speed in degrees per second.
@export var turn_speed := 300.0
## How far (degrees) the monster may turn away from the direction it faced when the scene started.
## 180 = no limit; 0 = it always keeps its first facing (a monster set into a wall).
@export_range(0.0, 180.0) var turn_limit := 180.0
## Never leaves its spot (an ambusher in a wall, a growth): no wandering, no chasing, no knockback, the body is
## not moved by physics. It still notices targets, turns toward them (see turn_limit) and attacks within reach.
@export var stationary := false
## Gravity in meters per second squared (0 = never falls).
@export var gravity := 9.8
## Speed (m/s) at which the feet of the Walk clip move. When set, the Walk clip plays faster or slower to
## match the real speed, so the feet do not slide when you change walk_speed. 0 = always normal speed.
@export var walk_animation_speed := 0.0
## The same for the Run clip.
@export var run_animation_speed := 0.0

@export_group("Wander")
## Stroll around the start position when no target is around.
@export var wander := true
## How far from the start position the monster strolls (meters).
@export var wander_radius := 5.0
## Seconds of standing between two strolls (random between x and y).
@export var idle_time := Vector2(2.0, 5.0)
## Patrol instead of strolling at random: the monster walks from point to point (positions in the space of its
## parent node, in order, then from the start again) and stands idle_time seconds at each one.
@export var patrol_points := PackedVector3Array()

@export_group("Attack")
## Distance (meters, measured on the floor between the origins) at which the Attack clip starts.
@export var attack_range := 1.2
## Seconds into the Attack clip when the blow lands.
@export var attack_hit_time := 0.5
## Distance at which Attack2 starts (0 = the same as attack_range). A longer range suits leaps and charges.
@export var attack2_range := 0.0
## Seconds into the Attack2 clip when the blow lands.
@export var attack2_hit_time := 0.5
## Seconds into the Attack2 clip when a second blow lands (a double stab); 0 = one blow.
@export var attack2_second_hit_time := 0.0
## Chance to pick Attack2 when both attacks can reach. A walking monster whose Attack2 reaches less far than its
## Attack steps in closer for it with this chance before an attack (unless other monsters stand around the target).
@export_range(0.0, 1.0) var attack2_chance := 0.4
## A hit no longer interrupts an attack in its last seconds before the blow lands (nor between the two blows of a
## double attack); the damage still counts. 0 = a hit always interrupts it.
@export var attack_commit_time := 0.25
## Seconds between the end of an attack and the next one. An attack that a hit cuts short after its blow counts to
## the end of its clip, and the cooldown keeps running through Hit, so getting hit never speeds up the attacks.
@export var attack_cooldown := 0.8
## Damage of one blow.
@export var damage := 10.0
## Extra reach when the blow lands: it hits if the target is closer than the attack range plus this.
@export var hit_reach := 0.5
## The blow only hits a target within this angle (degrees) left or right of the monster's front.
@export var hit_angle := 75.0

@export_group("Health")
@export var max_health := 100.0
## Damage plays the Hit clip (and pushes the monster back a little), which interrupts attacks.
@export var flinch := true
## After a Hit reaction the monster acts for at least this many seconds before damage can make it flinch again
## (the damage of every hit still counts), so a fast-firing weapon cannot keep it from striking back.
@export var flinch_cooldown := 1.0
## Blows weaker than this never make the monster flinch (0 = every blow can). Big monsters shrug off light hits.
@export var flinch_min_damage := 0.0
## Seconds after death before the body is removed from the scene (0 = it stays).
@export var remove_after := 0.0
## Optional Area3D whose shapes cover the whole body of a long or wide monster (the collision capsule only holds
## its middle): raycasts that collide with areas hit the monster there, too. It is switched off on death.
@export var hitbox: Area3D

@export_group("Animations")
## The AnimationPlayer of the model (found on its own when empty).
@export var animation_player: AnimationPlayer
@export var anim_idle: StringName = &"Idle"
@export var anim_walk: StringName = &"Walk"
@export var anim_run: StringName = &"Run"
@export var anim_attack: StringName = &"Attack"
## Second attack, used when the model has it (leave empty for none).
@export var anim_attack2: StringName = &"Attack2"
@export var anim_hit: StringName = &"Hit"
@export var anim_death: StringName = &"Death"
## Played once when the monster spots a target (Scream, Rear, Threat...). Empty: none.
@export var anim_alert: StringName = &""
## Start frozen in the first frame of anim_wake (a lurker coiled inside its hull breach, a body on the floor...)
## and come alive with that clip when a target comes within detect_range or the monster gets hurt.
@export var start_dormant := false
## The clip of a dormant monster coming alive (e.g. Emerge).
@export var anim_wake: StringName = &""
## Play anim_wake (instead of anim_alert) every time the monster spots a target after resting in IDLE, as an
## ambusher that hides again between two hunts.
@export var wake_every_time := false
## Clip a stationary monster plays while it watches a target out of its reach (empty: anim_idle).
@export var anim_stationary: StringName = &""
## Played once when the monster gives up a hunt and goes back to rest, as an ambusher hiding again (the Tentacle
## Lurker coils back into its breach). Empty: it blends straight back to anim_idle.
@export var anim_retract: StringName = &""
## Clips played now and then while standing idle.
@export var idle_variations: PackedStringArray = PackedStringArray()
## Clips that loop. Their loop mode is set when the monster starts (the others play once).
@export var loop_animations: PackedStringArray = PackedStringArray(["Idle", "Walk", "Run"])
## Cross-fade time between clips in seconds.
@export var blend_time := 0.2

@export_group("Skin")
## Skin name -> albedo texture of the model (the pack's monster scenes list their skins here).
@export var skin_textures: Dictionary = {}:
	set(value):
		skin_textures = value
		notify_property_list_changed()
		_apply_skin_when_ready()
## The skin to show: one of the names in skin_textures. Empty = the texture inside the model.
@export var skin := "":
	set(value):
		skin = value
		_apply_skin_when_ready()

@export_group("Glow")
## Fade the glowing parts (emissive surfaces: eyes, lures, glowing growths) and carried_light out during Death,
## over glow_fade_time seconds. Only this monster fades; others with the same skin keep glowing.
@export var fade_glow_on_death := true
## Seconds the glow takes to fade out after death.
@export var glow_fade_time := 1.5
## A light the monster carries (the Keeper's Ghost lantern, on a BoneAttachment3D): it takes the color of the
## current skin from light_colors and fades with the glow.
@export var carried_light: Light3D
## Skin name -> color of carried_light.
@export var light_colors: Dictionary = {}

@export_group("Hover")
## Floating monsters whose clips stand on the floor: the model floats this many meters above the floor while
## alive and sinks down on death. (The pack's floating monsters float inside their own clips and keep this 0.)
@export var hover_height := 0.0
## Up and down bob of a floating model in meters.
@export var hover_bob := 0.06
## Seconds for one bob.
@export var hover_period := 2.4
## The node that floats (default: the model, the child that holds the AnimationPlayer).
@export var model: Node3D

@export_group("Navigation")
## Follow the paths of a NavigationAgent3D child when the level has a navigation mesh.
@export var use_navigation := true

## Current state (read only, use the methods to change it).
var state: State = State.IDLE
var health := 100.0
## The node being hunted (null when there is none).
var target: Node3D = null
## Where the monster started; wandering stays around it.
var home := Vector3.ZERO

const PSX_META := &"psx_original_surface_materials"   # set by shaders/apply_psx.gd while the PSX shader is on
static var _skin_cache := {}

var _ap: AnimationPlayer = null
var _nav: NavigationAgent3D = null
var _t := 0.0                     # seconds in the current state
var _clock := 0.0
var _want := Vector3.ZERO         # wanted horizontal velocity
var _face := Vector3.ZERO         # wanted facing direction (flat)
var _cooldown := 0.0
var _flinch_wait := 0.0
var _sense_wait := 0.0
var _unseen := 0.0
var _forced := false              # a hunt() target: kept at any distance and out of sight
var _alert_left := 0.0
var _alert_wait := 0.0
var _dormant := false
var _variation_left := 0.0
var _retract_next := false        # after the clip held in IDLE (a wake-up with nobody to hunt): play anim_retract
var _idle_for := 2.0
var _goal := Vector3.ZERO
var _goal_time := 10.0
var _patrol_next := 0
var _stuck := 0.0
var _attack_anim: StringName = &""
var _attack_hit := 0.0
var _attack_len := 0.0
var _attack_reach := 0.0
var _attack_done := false
var _attack_hit2 := 0.0
var _attack_done2 := true
var _hit_len := 0.0
var _glow := 1.0                  # 1 = glowing parts as made, 0 = dark
var _glow_target := 1.0
var _glow_rate := 0.0             # change of _glow per second while fading
var _glow_own := {}               # this monster's own copies of glowing materials (made when the glow first changes)
var _light_energy := -1.0         # energy of carried_light at full glow
var _model_y := 0.0
var _hover_now := 0.0
var _home_yaw := 0.0
var _alive_layer := 0
var _alive_mask := 0
var _hitbox_layer := 0
var _nav_check := 0.0
var _nav_ok := false
var _avoid := false               # the NavigationAgent3D has avoidance on: walk with its safe velocity
var _safe_velocity := Vector3.ZERO
var _safe_time := -1.0            # _clock when the agent last sent a safe velocity
var _repath_at := 0.0             # _clock of the next new path while it follows one
var _close_in := false            # the next attack is its shorter Attack2: it steps in closer for it first
var _close_in_until := 0.0        # ...until this _clock at most (0 = not begun), then it uses Attack
var _close_in_from := 0.0         # its distance to the target when it began to step in


func _ready() -> void:
	_ap = _find_animation_player()
	if model == null and _ap != null and _ap.get_parent() is Node3D and _ap.get_parent() != self:
		model = _ap.get_parent() as Node3D
	if carried_light != null:
		_light_energy = carried_light.light_energy
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)
		_apply_skin()
		return
	health = max_health
	home = global_position
	_home_yaw = rotation.y
	_alive_layer = collision_layer
	_alive_mask = collision_mask
	if hitbox != null:
		_hitbox_layer = hitbox.collision_layer
	_nav = _find_navigation_agent()
	if _nav != null and _nav.avoidance_enabled:
		_avoid = true                   # others steer around it; a stationary monster itself never moves aside
		if not stationary:
			_nav.velocity_computed.connect(_on_velocity_computed)
	if model != null:
		_model_y = model.position.y
	_hover_now = hover_height
	_sense_wait = randf() * 0.2
	_idle_for = randf_range(idle_time.x, idle_time.y)
	add_to_group(&"monsters")
	_setup_animations()
	_apply_skin()
	if active and start_dormant and has_animation(anim_wake):
		_dormant = true
		play_animation(anim_wake, true, 0.0)
		_ap.pause()                                        # holds the first frame until it wakes up
		return
	play_animation(anim_idle, true, 0.0)
	if _ap != null and _ap.has_animation(anim_idle):
		_ap.seek(randf() * _length(anim_idle), true)      # monsters of one kind do not breathe in sync


func _validate_property(property: Dictionary) -> void:
	if property.name == "skin" and not skin_textures.is_empty():
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(skin_names())


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if _find_animation_player() == null:
		warnings.append("No AnimationPlayer found: add the monster model (a scene with an AnimationPlayer) as a child.")
	return warnings


# ============================================================================================ public
## True once health has reached 0.
func is_dead() -> bool:
	return state == State.DEAD


## True while a start_dormant monster still waits for its wake-up.
func is_dormant() -> bool:
	return _dormant


## Name of the current state ("IDLE", "CHASE"...).
func state_name() -> String:
	return str(State.keys()[state])


## True while the monster follows a hunt() target that it has not seen close by or reached yet.
func is_forced_hunt() -> bool:
	return _forced


## The model's AnimationPlayer (null when there is none).
func get_animation_player() -> AnimationPlayer:
	return _ap if _ap != null else _find_animation_player()


## True when the model has a clip with this name.
func has_animation(anim: StringName) -> bool:
	var ap := get_animation_player()
	return ap != null and anim != &"" and ap.has_animation(anim)


## Plays a clip with a cross-fade (blend < 0 uses blend_time). restart: play it again from the start when it
## is already playing. Returns false when the model has no such clip.
func play_animation(anim: StringName, restart := false, blend := -1.0) -> bool:
	if not has_animation(anim):
		return false
	var ap := get_animation_player()
	ap.speed_scale = 1.0
	if ap.is_playing() and ap.current_animation == anim and not restart:
		return true
	ap.play(anim, blend_time if blend < 0.0 else blend)
	if restart:
		ap.seek(0.0, true)
	return true


## Damages the monster. from_position (optional) is where the damage came from; source (optional) is the
## attacker, which the monster then hunts. Plays Hit (see flinch), or Death when health reaches 0.
func take_damage(amount: float, from_position: Vector3 = Vector3.INF, source: Node = null) -> void:
	if state == State.DEAD or not active or amount <= 0.0 or Engine.is_editor_hint():
		return
	health = maxf(health - amount, 0.0)
	damaged.emit(amount, health)
	if health <= 0.0:
		_die()
		return
	var was_dormant := _dormant
	if target == null:
		var attacker := source as Node3D
		if attacker == null or not attacker.is_in_group(target_group):
			attacker = _nearest_target(lose_range, false)
		if attacker != null:
			_acquire(attacker, false)
	if _dormant:                        # hurt, but nobody to hunt: wake up anyway, then hide again
		_wake()
		_variation_left = _length(anim_wake)
		_retract_next = true
	var away := Vector3.ZERO
	if from_position != Vector3.INF:
		away = _flat(global_position - from_position)
		if away.length() > 0.01:
			_face = -away.normalized()
	if not flinch or _flinch_wait > 0.0 or amount < flinch_min_damage or was_dormant or _committed() \
			or not has_animation(anim_hit):
		return                          # it takes the damage without a Hit reaction
	if state == State.ATTACK and _attack_done:
		# cut short after its blow: the attack still counts to the end of its clip and attack_cooldown runs from
		# there, so a monster that gets hit never strikes sooner than an unhurt one
		_cooldown = maxf(_cooldown, maxf(_attack_len - _t, 0.0) + attack_cooldown)
	_hit_len = _length(anim_hit)
	_flinch_wait = _hit_len + flinch_cooldown         # counted from the end of the Hit clip
	_alert_left = 0.0
	if not stationary and away.length() > 0.01:
		velocity += away.normalized() * 1.2           # knocked back a little
	_set_state(State.HIT)
	play_animation(anim_hit, true, 0.05)


## Kills the monster at once.
func kill() -> void:
	if state != State.DEAD:
		health = 0.0
		_die()


## Brings a dead monster back (full health, collision on, glowing again, IDLE).
func revive() -> void:
	health = max_health
	collision_layer = _alive_layer
	collision_mask = _alive_mask
	if hitbox != null:
		hitbox.collision_layer = _hitbox_layer
	if _avoid:
		_nav.avoidance_enabled = true
	target = null
	_forced = false
	_flinch_wait = 0.0
	_dormant = false
	_hover_now = hover_height
	set_glow(1.0)
	_set_state(State.IDLE)
	play_animation(anim_idle, true)


## Brightness of the glowing parts and of carried_light: 1 = as made, 0 = dark. The glowing surfaces of this
## monster get materials of their own the first time it changes, so other monsters keep their glow.
func set_glow(amount: float) -> void:
	_glow = clampf(amount, 0.0, 1.0)
	_glow_target = _glow
	_glow_rate = 0.0
	_update_glow()


## Fades the glow to amount (0..1) over seconds (death does this when fade_glow_on_death is on).
func fade_glow(amount: float, seconds: float) -> void:
	_glow_target = clampf(amount, 0.0, 1.0)
	if seconds <= 0.0:
		set_glow(_glow_target)
		return
	_glow_rate = maxf(absf(_glow_target - _glow), 0.01) / seconds


## The current glow (1 = as made, 0 = dark).
func get_glow() -> float:
	return _glow


## Starts hunting a node right away (it does not need to be seen first), for alarms, triggers and scripted
## scares. forced (the default): the monster keeps coming however far away or hidden the target is (lose_range
## and forget_time do not count) until the target dies, or until the monster sees it close by (within detect_range
## and lose_range) or gets within attack_range of it; from then on the normal rules apply. forced off: the normal
## rules apply at once.
func hunt(new_target: Node3D, forced := true) -> void:
	if new_target != null and state != State.DEAD:
		_acquire(new_target, true)
		_forced = forced


## Names of the skins in skin_textures.
func skin_names() -> PackedStringArray:
	var names := PackedStringArray()
	for k in skin_textures.keys():
		names.append(str(k))
	return names


## Switches to the next skin of skin_textures and returns its name.
func next_skin() -> String:
	var names := skin_names()
	if names.is_empty():
		return skin
	skin = names[(names.find(skin) + 1) % names.size()]
	return skin


# ============================================================================================ loop
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not active:
		if _avoid and _nav.velocity != Vector3.ZERO:
			_nav.velocity = Vector3.ZERO    # switched off: it stands still for the avoidance of the others, too
		return
	_clock += delta
	_t += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_flinch_wait = maxf(_flinch_wait - delta, 0.0)
	_alert_wait = maxf(_alert_wait - delta, 0.0)
	if state != State.DEAD:
		_sense(delta)
	match state:
		State.IDLE:
			_do_idle(delta)
		State.WANDER:
			_do_wander()
		State.CHASE:
			_do_chase(delta)
		State.ATTACK:
			_do_attack()
		State.HIT:
			_do_hit()
		State.DEAD:
			_want = Vector3.ZERO
	_move(delta)
	_update_hover(delta)


func _process(delta: float) -> void:
	if _glow_rate <= 0.0:
		return
	_glow = move_toward(_glow, _glow_target, _glow_rate * delta)
	if is_equal_approx(_glow, _glow_target):
		_glow = _glow_target
		_glow_rate = 0.0
	_update_glow()


func _set_state(new_state: State) -> void:
	if new_state == state:
		_t = 0.0
		return
	var old := state
	state = new_state
	_t = 0.0
	_stuck = 0.0
	_retract_next = false
	if new_state == State.CHASE:
		_plan_attack()
	state_changed.emit(new_state, old)


func _enter_idle() -> void:
	var gave_up := state == State.CHASE or state == State.ATTACK or state == State.HIT
	_set_state(State.IDLE)
	_idle_for = randf_range(idle_time.x, idle_time.y)
	_variation_left = 0.0
	_retract_next = false
	if gave_up and play_animation(anim_retract, true, 0.15):
		_variation_left = _length(anim_retract)      # _do_idle holds the clip to its end, then plays anim_idle
		return
	play_animation(anim_idle)


func _do_idle(delta: float) -> void:
	_want = Vector3.ZERO
	if _dormant:
		return
	if _variation_left > 0.0:
		_variation_left -= delta
		if _variation_left <= 0.0:
			_t = 0.0
			if _retract_next and play_animation(anim_retract, true, 0.15):
				_variation_left = _length(anim_retract)
			else:
				play_animation(anim_idle)
			_retract_next = false
		return
	play_animation(anim_idle)
	if _t < _idle_for:
		return
	if not idle_variations.is_empty() and randf() < 0.35:
		var pick := StringName(idle_variations[randi() % idle_variations.size()])
		if play_animation(pick, true):
			_variation_left = _length(pick)
			_idle_for = randf_range(idle_time.x, idle_time.y)
			return
	if stationary:
		_t = 0.0
		_idle_for = randf_range(idle_time.x, idle_time.y)
	elif not patrol_points.is_empty():
		_goal = _patrol_point(_patrol_next)
		_patrol_next = (_patrol_next + 1) % patrol_points.size()
		_start_walk()
	elif wander and wander_radius > 0.3:
		var angle := randf() * TAU
		_goal = home + Vector3(sin(angle), 0.0, cos(angle)) * randf_range(wander_radius * 0.35, wander_radius)
		_start_walk()
	else:
		_t = 0.0
		_idle_for = randf_range(idle_time.x, idle_time.y)


func _start_walk() -> void:
	_goal_time = 4.0 + 2.0 * _flat(_goal - global_position).length() / maxf(walk_speed, 0.1)
	_set_nav_target(_goal, true)
	_set_state(State.WANDER)


## Patrol point i in world space (the points are given in the parent's space).
func _patrol_point(i: int) -> Vector3:
	var p := patrol_points[i]
	var parent := get_parent() as Node3D
	return parent.to_global(p) if parent != null else p


func _do_wander() -> void:
	var to := _goal - global_position
	to.y = 0.0
	var arrived := to.length() < 0.5 or (_nav_ready() and _nav.is_navigation_finished() and _t > 0.3)
	if arrived or _t > _goal_time or _stuck > 1.2:
		_enter_idle()
		return
	_go_to(_goal, walk_speed)
	_animate_move(anim_walk, walk_animation_speed, walk_speed)


func _do_chase(delta: float) -> void:
	if target == null:
		_enter_idle()
		return
	var to := _flat(target.global_position - global_position)
	_face = to.normalized() if to.length() > 0.01 else _face
	if _alert_left > 0.0:
		_alert_left -= delta
		_want = Vector3.ZERO
		return
	var dist := to.length()
	var high := absf(target.global_position.y - global_position.y) > 1.8
	if not high and _cooldown <= 0.0 and _start_attack(dist):
		return
	if stationary:
		_want = Vector3.ZERO           # watches the target from its spot
		if not play_animation(anim_stationary):
			play_animation(anim_idle)
		return
	if dist <= (_reach2() if _close_in else attack_range) * 0.85 and not high:
		_want = Vector3.ZERO           # close enough: wait for the next attack
		play_animation(anim_idle)
		return
	var speed := run_speed if use_run else walk_speed
	_go_to(target.global_position, speed)
	if use_run and has_animation(anim_run):
		_animate_move(anim_run, run_animation_speed, speed)
	else:
		_animate_move(anim_walk, walk_animation_speed, speed)


## Reach of Attack2 (attack2_range, or attack_range when that is 0).
func _reach2() -> float:
	return attack2_range if attack2_range > 0.0 else attack_range


## Before each attack (when a chase starts or goes on): a walking monster whose Attack2 reaches less far than its
## Attack (it stops at its attack range, so it would hardly ever come that close) decides whether it steps in closer
## for Attack2 this time (attack2_chance). Not when other monsters already stand around the target.
func _plan_attack() -> void:
	_close_in = not stationary and has_animation(anim_attack2) and _reach2() < attack_range \
			and randf() < attack2_chance and not _crowded()
	_close_in_until = 0.0


## True when another living monster stands near the target (within this monster's attack range + 0.5 m).
func _crowded() -> bool:
	if target == null:
		return false
	for node in get_tree().get_nodes_in_group(&"monsters"):
		var other := node as MonsterBrain
		if other != null and other != self and not other.is_dead() \
				and _flat(other.global_position - target.global_position).length() < attack_range + 0.5:
			return true
	return false


func _start_attack(dist: float) -> bool:
	var reach2 := _reach2()
	var can1 := has_animation(anim_attack) and dist <= attack_range
	var can2 := has_animation(anim_attack2) and dist <= reach2
	if not can1 and not can2:
		return false
	if _close_in and not can2:
		# steps in closer for its shorter Attack2: for 1.5 s at most, 0.5 s when it does not get closer, and not
		# once others stand around the target; then it uses Attack
		if _close_in_until <= 0.0:
			_close_in_until = _clock + 1.5
			_close_in_from = dist
		var blocked := _clock > _close_in_until - 1.0 and dist > _close_in_from - 0.1
		if _clock < _close_in_until and not blocked and not _crowded():
			return false
		_close_in = false
	if turn_limit < 180.0 and target != null and not _can_face(target.global_position):
		return false                   # it cannot turn far enough to reach the target
	var second := can2 and (not can1 or _close_in or randf() < attack2_chance)
	_attack_anim = anim_attack2 if second else anim_attack
	_attack_hit = attack2_hit_time if second else attack_hit_time
	_attack_reach = (reach2 if second else attack_range) + hit_reach
	_attack_len = _length(_attack_anim)
	_attack_done = false
	_attack_hit2 = attack2_second_hit_time if second else 0.0
	_attack_done2 = _attack_hit2 <= 0.0
	_want = Vector3.ZERO
	_set_state(State.ATTACK)
	play_animation(_attack_anim, true, 0.1)
	attack_started.emit(_attack_anim)
	return true


func _do_attack() -> void:
	_want = Vector3.ZERO
	if target != null and not _attack_done:
		var to := _flat(target.global_position - global_position)
		if to.length() > 0.01:
			_face = to.normalized()
	if not _attack_done and _t >= _attack_hit:
		_attack_done = true
		_land_blow()
	if _attack_done and not _attack_done2 and _t >= _attack_hit2:
		_attack_done2 = true            # the second blow of a double attack
		_land_blow()
	if _t >= _attack_len:
		_cooldown = maxf(attack_cooldown - (_t - _attack_len), 0.0)     # counted from the end of the clip
		if target != null:
			_set_state(State.CHASE)
		else:
			_enter_idle()


## True from attack_commit_time seconds before the blow of an attack until its last blow has landed: a hit does
## not interrupt the attack then.
func _committed() -> bool:
	if state != State.ATTACK or attack_commit_time <= 0.0:
		return false
	if not _attack_done:
		return _t >= _attack_hit - attack_commit_time
	return not _attack_done2


func _land_blow() -> void:
	if target == null or not is_instance_valid(target) or _is_dead(target):
		return
	var to := target.global_position - global_position
	if absf(to.y) > 2.0:
		return
	to.y = 0.0
	if to.length() > _attack_reach:
		return
	var front := global_transform.basis.z
	front.y = 0.0
	if to.length() > 0.2 and front.length() > 0.01 and rad_to_deg(front.angle_to(to)) > hit_angle:
		return
	if target.has_method("take_damage"):
		target.call("take_damage", damage, global_position)
	attack_landed.emit(target, damage)


func _do_hit() -> void:
	_want = Vector3.ZERO
	if _t >= _hit_len:
		if target != null:
			_set_state(State.CHASE)
		else:
			_enter_idle()


func _die() -> void:
	_set_state(State.DEAD)
	_want = Vector3.ZERO
	velocity = Vector3(0.0, minf(velocity.y, 0.0), 0.0)
	target = null
	_forced = false
	_dormant = false
	play_animation(anim_death, true, 0.1)
	collision_layer = 0                 # bullets, players and monsters pass through the body
	collision_mask = sight_mask         # ...but it still lies on the level geometry
	if hitbox != null:
		hitbox.collision_layer = 0
	if _avoid:
		_nav.avoidance_enabled = false  # the others walk over the body instead of steering around it
	if fade_glow_on_death:
		fade_glow(0.0, glow_fade_time)
	died.emit()
	if remove_after > 0.0:
		get_tree().create_timer(remove_after).timeout.connect(queue_free)


func _wake() -> bool:
	_dormant = false
	if not play_animation(anim_wake, true):
		return false
	woke_up.emit()
	return true


# ============================================================================================ senses
func _sense(delta: float) -> void:
	_sense_wait -= delta
	if _sense_wait > 0.0:
		return
	_sense_wait = 0.2
	if target != null and (not is_instance_valid(target) or not target.is_inside_tree() or _is_dead(target)):
		_drop_target()
	if target == null:
		var found := _nearest_target(detect_range, need_line_of_sight)
		if found != null:
			_acquire(found, true)
		return
	var dist := _flat(target.global_position - global_position).length()
	if _forced:
		# a hunt() target: followed from any distance, seen or not, until the monster reaches it or sees it close by
		# (within detect_range, and within lose_range, so that the normal rules do not drop it right away)
		var close := minf(detect_range, lose_range)
		if dist <= attack_range or (dist <= close and (not need_line_of_sight or _can_see(target))):
			_forced = false
			_unseen = 0.0
		return
	if dist > lose_range:
		_drop_target()
		return
	if not need_line_of_sight or _can_see(target):
		_unseen = 0.0
	else:
		_unseen += 0.2
		if _unseen > forget_time:
			_drop_target()


func _acquire(new_target: Node3D, alert: bool) -> void:
	var was_hunting := target != null
	target = new_target
	_unseen = 0.0
	if not was_hunting:
		target_spotted.emit(new_target)
	if state == State.IDLE or state == State.WANDER:
		var resting := state == State.IDLE and _variation_left <= 0.0
		_set_state(State.CHASE)
		_alert_left = 0.0
		if _dormant or (wake_every_time and resting and has_animation(anim_wake)):
			if _wake():
				_alert_left = _length(anim_wake)
				_alert_wait = 12.0
		elif alert and _alert_wait <= 0.0 and play_animation(anim_alert, true, 0.15):
			_alert_left = _length(anim_alert)
			_alert_wait = 12.0


func _drop_target() -> void:
	_forced = false
	if target == null:
		return
	target = null
	target_lost.emit()
	if state == State.CHASE:
		_enter_idle()


func _nearest_target(max_range: float, need_sight: bool) -> Node3D:
	var best: Node3D = null
	var best_dist := max_range
	for node in get_tree().get_nodes_in_group(target_group):
		var candidate := node as Node3D
		if candidate == null or candidate == self or _is_dead(candidate):
			continue
		var dist := _flat(candidate.global_position - global_position).length()
		if dist <= best_dist and (not need_sight or _can_see(candidate)):
			best = candidate
			best_dist = dist
	return best


func _can_see(other: Node3D) -> bool:
	var from := global_position + Vector3.UP * eye_height + _flat(global_transform.basis.z).normalized() * eye_forward
	var to := other.global_position + Vector3.UP * minf(eye_height, 1.2)
	var query := PhysicsRayQueryParameters3D.create(from, to, sight_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == other


func _is_dead(node: Node) -> bool:
	return node.has_method("is_dead") and bool(node.call("is_dead"))


# ============================================================================================ moving
func _go_to(goal: Vector3, speed: float) -> void:
	var next := goal
	if _nav_ready():
		_set_nav_target(goal, false)
		var p := _nav.get_next_path_position()      # also keeps the agent's path up to date
		if not _nav.is_navigation_finished():
			p = _path_ahead(p)
			if _flat(p - global_position).length() > 0.05:
				next = p
	var dir := _flat(next - global_position)
	if dir.length() < 0.05:
		_want = Vector3.ZERO
		return
	dir = dir.normalized()
	_want = dir * speed
	_face = dir


## The first point of the agent's path that is farther away than path_desired_distance on the floor plan. (The
## agent measures that distance in 3D, so a navigation mesh baked a little above the floor could hold it at a point.)
func _path_ahead(fallback: Vector3) -> Vector3:
	var path := _nav.get_current_navigation_path()
	if path.is_empty():
		return fallback
	for i in range(_nav.get_current_navigation_path_index(), path.size()):
		if _flat(path[i] - global_position).length() > _nav.path_desired_distance:
			return path[i]
	return path[path.size() - 1]


## Sets the agent's goal when it moved more than 0.5 m (or force). It also asks for a new path once a second, so a
## monster that the others pushed off its path does not walk back to a path point it already passed.
func _set_nav_target(goal: Vector3, force: bool) -> void:
	if _nav_ready() and (force or _clock >= _repath_at or _nav.target_position.distance_to(goal) > 0.5):
		_nav.target_position = goal
		_repath_at = _clock + 1.0


func _nav_ready() -> bool:
	if not use_navigation or _nav == null:
		return false
	if _clock >= _nav_check:
		_nav_check = _clock + 1.0
		var map := _nav.get_navigation_map()
		_nav_ok = map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0 \
				and not NavigationServer3D.map_get_regions(map).is_empty()
	return _nav_ok


func _move(delta: float) -> void:
	if stationary:
		velocity = Vector3.ZERO        # stays exactly where it was put, even half inside a wall
	else:
		var want := _want
		if _avoid and state != State.DEAD:
			# the agent works out a velocity that keeps clear of the other agents (it arrives with
			# velocity_computed; Godot 4.3 sends a zero velocity while the map has no navigation mesh, so then the
			# monster walks as it wants); a monster that stands still to attack or watch does not step aside
			var top := maxf(_want.length(), 0.01)            # the agent may not pick a faster way around the others
			if not is_equal_approx(_nav.max_speed, top):
				_nav.max_speed = top
			_nav.velocity = _want
			if _want.length() > 0.1 and _nav_ready() and _clock - _safe_time < 0.25:
				want = _safe_velocity.limit_length(_want.length())
		var flat_velocity := Vector3(velocity.x, 0.0, velocity.z).lerp(want, 1.0 - exp(-acceleration * delta))
		velocity.x = flat_velocity.x
		velocity.z = flat_velocity.z
		if gravity > 0.0 and not is_on_floor():
			velocity.y -= gravity * delta
		elif gravity <= 0.0:
			velocity.y = 0.0
		move_and_slide()
	var wanted := _want.length()
	if wanted > 0.1 and _t > 0.5 and Vector3(velocity.x, 0.0, velocity.z).length() < wanted * 0.25:
		_stuck += delta
	else:
		_stuck = maxf(_stuck - delta, 0.0)
	if _face.length_squared() > 0.0001 and state != State.DEAD:
		var yaw := _local_yaw(_face)
		if turn_limit < 180.0:
			var off := clampf(angle_difference(_home_yaw, yaw), -deg_to_rad(turn_limit), deg_to_rad(turn_limit))
			yaw = _home_yaw + off
		rotation.y = rotate_toward(rotation.y, yaw, deg_to_rad(turn_speed) * delta)


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	_safe_velocity = Vector3(safe_velocity.x, 0.0, safe_velocity.z)
	_safe_time = _clock


## rotation.y that turns the model's +Z toward a world direction.
func _local_yaw(direction: Vector3) -> float:
	var parent_yaw := 0.0
	var parent := get_parent() as Node3D
	if parent != null:
		parent_yaw = parent.global_rotation.y
	return atan2(direction.x, direction.z) - parent_yaw


## True when the monster can turn (within turn_limit) so that point lies inside hit_angle of its front.
func _can_face(point: Vector3) -> bool:
	var to := _flat(point - global_position)
	if to.length() < 0.2:
		return true
	var off := absf(angle_difference(_home_yaw, _local_yaw(to)))
	return rad_to_deg(maxf(off - deg_to_rad(turn_limit), 0.0)) <= hit_angle


func _animate_move(anim: StringName, clip_speed: float, top_speed: float) -> void:
	if not play_animation(anim):
		play_animation(anim_idle)
		return
	if clip_speed > 0.0 and _ap != null:
		var speed := maxf(Vector3(velocity.x, 0.0, velocity.z).length(), top_speed * 0.5)
		_ap.speed_scale = clampf(speed / clip_speed, 0.5, 2.0)


func _update_hover(delta: float) -> void:
	if model == null or hover_height <= 0.0:
		return
	var want := 0.0 if state == State.DEAD else hover_height
	_hover_now = move_toward(_hover_now, want, delta * maxf(hover_height, 0.1) * 1.5)
	var bob := 0.0
	if state != State.DEAD and hover_period > 0.0:
		bob = sin(_clock * TAU / hover_period) * hover_bob
	model.position.y = _model_y + _hover_now + bob


# ============================================================================================ setup
func _setup_animations() -> void:
	if _ap == null:
		push_warning("%s: no AnimationPlayer found under the monster." % name)
		return
	for anim_name in loop_animations:
		if _ap.has_animation(anim_name):
			_ap.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR


func _find_animation_player() -> AnimationPlayer:
	if animation_player != null:
		return animation_player
	var found := find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null


func _find_navigation_agent() -> NavigationAgent3D:
	for child in get_children():
		if child is NavigationAgent3D:
			return child as NavigationAgent3D
	return null


func _length(anim: StringName) -> float:
	var ap := get_animation_player()
	if ap == null or not ap.has_animation(anim):
		return 0.0
	return ap.get_animation(anim).length


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# ============================================================================================ skins
func _apply_skin_when_ready() -> void:
	if is_node_ready():
		_apply_skin()


## Puts the skin texture on every surface of the model (surface override materials shared by all monsters
## with the same skin) and the skin's color on carried_light. Works while the PSX shader of shaders/apply_psx.gd
## is on, too.
func _apply_skin() -> void:
	if carried_light != null and light_colors.has(skin):
		carried_light.light_color = light_colors[skin]
	var texture: Texture2D = null
	if skin != "" and skin_textures.has(skin):
		texture = skin_textures[skin] as Texture2D
	var root: Node = model if model != null else self
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var originals: Array = mi.get_meta(PSX_META) if mi.has_meta(PSX_META) else []
		for s in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(s)
			var own_texture: Texture2D = (base as BaseMaterial3D).albedo_texture if base is BaseMaterial3D else null
			var wanted := texture if texture != null else own_texture
			var skinned := _skinned(base, own_texture, wanted)
			var override: Material = null if skinned == base else skinned
			if s < originals.size():
				originals[s] = override
				var psx := mi.get_surface_override_material(s)
				if psx is ShaderMaterial:
					mi.set_surface_override_material(s, _skinned(psx, own_texture, wanted))
			else:
				mi.set_surface_override_material(s, override)
	if _glow < 1.0:
		_update_glow()                  # a dimmed monster keeps its dimmed glow in the new skin


static func _skinned(material: Material, own_texture: Texture2D, texture: Texture2D) -> Material:
	if material == null or texture == null:
		return material
	var current: Texture2D = null
	if material is BaseMaterial3D:
		current = (material as BaseMaterial3D).albedo_texture
	elif material is ShaderMaterial:
		current = (material as ShaderMaterial).get_shader_parameter("albedo_texture") as Texture2D
	if current == texture or current == null:
		return material
	var key := "%d:%d" % [material.get_instance_id(), texture.get_instance_id()]
	if _skin_cache.has(key):
		return _skin_cache[key]
	var copy := material.duplicate() as Material
	if copy is BaseMaterial3D:
		var m := copy as BaseMaterial3D
		m.albedo_texture = texture
		if m.emission_texture != null and (m.emission_texture == current or m.emission_texture == own_texture):
			m.emission_texture = texture
	elif copy is ShaderMaterial:
		var sm := copy as ShaderMaterial
		sm.set_shader_parameter("albedo_texture", texture)
		var emission := sm.get_shader_parameter("emission_texture") as Texture2D
		if emission != null and (emission == current or emission == own_texture):
			sm.set_shader_parameter("emission_texture", texture)
	_skin_cache[key] = copy
	return copy


# ============================================================================================ glow
## Sets the emission of every glowing surface of the model to _glow times its value as made, and the energy of
## carried_light. The surfaces get this monster's own copies of their materials the first time, and so do the
## materials that the PSX swapper (shaders/apply_psx.gd) keeps for restore().
func _update_glow() -> void:
	if carried_light != null:
		if _light_energy < 0.0:
			_light_energy = carried_light.light_energy
		carried_light.light_energy = _light_energy * _glow
	if _glow >= 1.0 and _glow_own.is_empty():
		return                          # never dimmed: the shared materials glow as made
	var root: Node = model if model != null else self
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var originals: Array = mi.get_meta(PSX_META) if mi.has_meta(PSX_META) else []
		for s in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if source == null or not source.emission_enabled or source.emission_energy_multiplier <= 0.0:
				continue
			var energy := source.emission_energy_multiplier * _glow
			var shown := mi.get_active_material(s)
			var own := _own_glow_material(shown)
			if own != null:
				if own != shown:
					mi.set_surface_override_material(s, own)
				_set_emission_energy(own, energy)
			if s < originals.size():
				var before: Material = source
				if originals[s] != null:
					before = originals[s] as Material
				var kept := _own_glow_material(before)
				originals[s] = kept
				_set_emission_energy(kept, energy)


func _own_glow_material(material: Material) -> Material:
	if material == null:
		return null
	if _glow_own.has(material):
		return material
	var copy := material.duplicate() as Material
	_glow_own[copy] = true
	return copy


static func _set_emission_energy(material: Material, energy: float) -> void:
	if material is BaseMaterial3D:
		(material as BaseMaterial3D).emission_energy_multiplier = energy
	elif material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("emission_energy", energy)
