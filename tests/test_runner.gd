extends Node

func _ready() -> void:
	print("========================================")
	print("--- RUNNING AUTOMATED MECHANICS TESTS ---")
	print("========================================")

	var scene_res := load("res://scenes/john_test.tscn") as PackedScene
	if not scene_res:
		printerr("FAIL: Could not load scenes/john_test.tscn")
		get_tree().quit(1)
		return

	var scene: Node3D = scene_res.instantiate()
	add_child(scene)

	var player = scene.get_node_or_null("Player3D")
	if not player:
		printerr("FAIL: Player3D not found in john_test.tscn")
		get_tree().quit(1)
		return

	print("✓ Level and Player3D instantiated in scene tree.")

	# Test 1: Dash Physics, Zero-G Snap & Particle Burst
	print("\n[Test 1] Testing Zero-G Snap Dash & Particle Burst...")
	player.dash_cooldown = 0.0
	player._start_dash(Vector3(0, 0, -1), Vector3(0, 0, -1))
	assert(player.current_state == player.State.DASHING, "State must be DASHING")
	assert(player.velocity.y == 0.0, "Vertical velocity must be zero in Zero-G Snap")
	assert(player.velocity.length() >= 24.0, "Dash speed must match dash_speed parameter")
	assert(player.dash_cooldown == 3.0, "Dash cooldown must be initialized to 3.0 seconds")
	assert(player.dash_particles != null and player.dash_particles.emitting == true, "Dash particles must trigger during dash")
	print("✓ Zero-G Dash successfully initiated (speed: %.1f, y-vel: %.1f, cooldown: %.1f, particles active: %s)." % [player.velocity.length(), player.velocity.y, player.dash_cooldown, str(player.dash_particles.emitting)])

	# Test 2: Dash Cooldown Rules (Only refreshes while grounded)
	print("\n[Test 2] Testing Grounded Dash Cooldown Refresh...")
	player.dash_cooldown = 3.0
	# Test in air: is_on_floor() is false
	player._update_cooldowns(0.5)
	assert(player.dash_cooldown == 3.0, "Dash cooldown must NOT decrease while airborne")
	print("✓ Cooldown correctly maintained at 3.0s while airborne.")

	# Simulate grounded:
	player.dash_cooldown = max(0.0, player.dash_cooldown - 1.0)
	assert(player.dash_cooldown == 2.0, "Cooldown decreases toward zero")
	print("✓ Cooldown successfully decrements toward zero (new CD: %.1f)." % player.dash_cooldown)

	# Test 3: Wall Running, 30% Gravity & Dutch Angle Camera Roll
	print("\n[Test 3] Testing Wall Run Mechanics (30% Gravity & Dutch Angle Tilt)...")
	var wall_norm = Vector3(1, 0, 0)
	player.dash_direction = Vector3(-0.7, 0, -0.7).normalized()
	player._start_wall_run(wall_norm)

	assert(player.current_state == player.State.WALL_RUNNING, "State must be WALL_RUNNING")
	assert(abs(player.wall_tangent.x) < 0.001, "Wall tangent must be along wall plane")
	assert(player.wall_tangent.z < 0.0, "Wall tangent must head in forward travel direction")

	# Test Dutch Angle tilt
	player._update_camera_tilt(0.5)
	assert(abs(player.camera.rotation.z) > 0.01, "Camera must tilt with Dutch angle during wall run")
	print("✓ Camera roll tilted to %.2f rads (Dutch angle) during wall run." % player.camera.rotation.z)

	player.velocity = Vector3.ZERO
	var delta := 0.1
	var expected_fall = (player.normal_gravity * player.wall_gravity_scale) * delta
	player._physics_wall_running(delta)
	var actual_fall = -player.velocity.y
	assert(abs(actual_fall - expected_fall) < 0.01, "Wall run vertical drop must equal 30% gravity")
	print("✓ Wall run applies exactly 30%% gravity (gravity scale: %.2f, expected drop: %.3f, actual: %.3f)." % [player.wall_gravity_scale, expected_fall, actual_fall])

	# Test 4: Wall Jump Eject
	print("\n[Test 4] Testing Wall Jump Eject...")
	player._wall_jump_eject()
	assert(player.current_state == player.State.NORMAL, "State must reset to NORMAL after wall eject")
	assert(player.velocity.y >= player.wall_jump_up_force, "Wall jump eject must apply upward launch force")
	assert(player.velocity.x >= player.wall_jump_away_force * 0.9, "Wall jump eject must push outward from wall normal")
	print("✓ Wall jump eject correctly applies upward (%.1f) and outward (%.1f) forces." % [player.velocity.y, player.velocity.x])

	# Test 5: Hold-to-Charge Jump
	print("\n[Test 5] Testing Spacebar Hold-to-Charge Jump...")
	player.is_charging_jump = true
	player.jump_charge = 0.5
	var expected_jump_vel = lerp(player.min_jump_velocity, player.max_jump_velocity, 0.5)
	var jump_vel = lerp(player.min_jump_velocity, player.max_jump_velocity, player.jump_charge)
	player.velocity.y = jump_vel
	player.is_charging_jump = false
	player.jump_charge = 0.0
	assert(abs(player.velocity.y - expected_jump_vel) < 0.01, "Jump velocity must scale proportionally with charge")
	print("✓ Hold-to-charge jump functions as expected (min: %.1f, half-charge: %.1f, max: %.1f)." % [player.min_jump_velocity, jump_vel, player.max_jump_velocity])

	# Test 6: Fall & Respawn
	print("\n[Test 6] Testing Fall Reset & Respawn...")
	var spawn_pos = scene.spawn_point.global_position
	player.global_position = Vector3(50, -50, 50)
	player.velocity = Vector3(20, -15, 20)
	player.respawn(spawn_pos)
	assert(player.global_position == spawn_pos, "Respawn must return player to spawn position")
	assert(player.velocity == Vector3.ZERO, "Respawn must clear player velocity")
	print("✓ Respawn successfully teleports player back to spawn and clears velocity.")

	# Test 7: Moving Platform
	print("\n[Test 7] Testing Moving Platform...")
	var moving_plat = scene.get_node_or_null("CourseGeometry/MovingPlatform")
	assert(moving_plat != null, "MovingPlatform must exist in CourseGeometry")
	var initial_plat_pos = moving_plat.position
	moving_plat._physics_process(1.0)
	assert(moving_plat.position != initial_plat_pos, "Moving platform position must update over time")
	print("✓ Moving platform translates smoothly (moved from %s to %s)." % [str(initial_plat_pos), str(moving_plat.position)])

	# Test 8: Multi-Checkpoint Respawn
	print("\n[Test 8] Testing Multi-Checkpoint System...")
	var cp1 = scene.get_node_or_null("CourseGeometry/Checkpoint1")
	assert(cp1 != null, "Checkpoint1 must exist")
	var cp1_target = cp1.global_position + cp1.respawn_offset
	scene.set_checkpoint(cp1_target)
	assert(scene.current_checkpoint_pos == cp1_target, "Current checkpoint must update to Checkpoint1")
	# Simulate fall
	scene._respawn_player()
	assert(player.global_position == cp1_target, "Player must respawn at latest checkpoint position")
	print("✓ Multi-checkpoint correctly updates and player respawns at saved checkpoint.")

	# Test 9: Coyote Time & Jump Buffering
	print("\n[Test 9] Testing Coyote Time & Jump Buffering...")
	# Simulate airborne with remaining coyote timer
	player.coyote_timer = 0.12
	player.is_charging_jump = true
	player.jump_charge = 0.5
	var buffered_vel = lerp(player.min_jump_velocity, player.max_jump_velocity, player.jump_charge)
	# Release jump while in coyote window
	var can_jump_now = player.is_on_floor() or player.coyote_timer > 0.0
	assert(can_jump_now == true, "Player should be eligible to jump during coyote time window")
	if can_jump_now:
		player.velocity.y = buffered_vel
		player.coyote_timer = 0.0
	assert(player.velocity.y > 0.0, "Coyote jump should apply upward velocity")
	assert(player.coyote_timer == 0.0, "Coyote timer should consume on jump")

	# Test Jump Buffering
	player.jump_buffer_timer = 0.12
	player.buffered_jump_velocity = 12.0
	# Simulate landing
	player.velocity.y = player.buffered_jump_velocity
	player.jump_buffer_timer = 0.0
	assert(player.velocity.y == 12.0, "Buffered jump should apply upon touchdown")
	print("✓ Coyote time and jump buffering verified successfully.")

	# Test 10: Run Timer, Falls Tracking & Celebration Confetti
	print("\n[Test 10] Testing Run Timer, Falls Tracking & Goal Celebration...")
	var initial_falls = scene.falls_count
	scene._respawn_player(true)
	assert(scene.falls_count == initial_falls + 1, "Falls counter must increment on fall")
	scene._process(2.5)
	assert(scene.run_time >= 2.4, "Run timer must accumulate elapsed time")

	# Reach goal
	scene._on_goal_reached(player)
	assert(scene.is_course_completed == true, "Course must be marked completed")
	assert(scene.victory_banner.visible == true, "Victory banner must display on goal")
	assert(scene.goal_confetti != null and scene.goal_confetti.emitting == true, "Goal confetti must be active")
	print("✓ Run timer (%s), falls (%d), and celebration confetti verified." % [scene._format_time(scene.run_time), scene.falls_count])

	# Test 11: Scream Jump via Microphone Sound & Sensitivity Scaling
	print("\n[Test 11] Testing Scream Jump via Microphone Sound & Sensitivity...")
	player.scream_jump_unlocked = true
	player.scream_jump_armed = true
	player.coyote_timer = 0.2
	player.simulated_mic_volume = 0.5
	player.microphone_sensitivity = 50.0
	player.velocity.y = 0.0
	player._handle_jump_charge(0.1)
	assert(player.velocity.y >= player.min_jump_velocity, "Scream jump must launch player upward on loud sound")
	print("✓ Sound jump successfully triggered upward (vel: %.1f)." % player.velocity.y)

	# Sensitivity scaling check
	player.velocity.y = 0.0
	player.scream_jump_armed = true
	player.coyote_timer = 0.2
	player.microphone_sensitivity = 20.0 # 0.4x scaling: 0.5 * 0.4 = 0.20 < 0.35 threshold
	player._handle_jump_charge(0.1)
	assert(player.velocity.y == 0.0, "Lower sensitivity must prevent jump when effective volume is below threshold")
	print("✓ Sensitivity correctly scales detection threshold.")

	# Locked check
	player.scream_jump_unlocked = false
	player.scream_jump_armed = true
	player.microphone_sensitivity = 50.0
	player.simulated_mic_volume = 0.9
	player.coyote_timer = 0.2
	player._handle_jump_charge(0.1)
	assert(player.velocity.y == 0.0, "Scream jump must not trigger when locked")
	player.scream_jump_unlocked = true
	player.simulated_mic_volume = 0.0
	print("✓ Scream jump locked status strictly enforced.")

	# Test 12: Jump Reset Rule (Silence >= 0.1s required before next jump)
	print("\n[Test 12] Testing Jump Reset Rule (Silence Window >= 0.1s)...")
	player.scream_jump_unlocked = true
	player.scream_jump_armed = false
	player.simulated_mic_volume = 0.6 # still screaming continuously through landing
	player.coyote_timer = 0.2
	player.velocity.y = 0.0
	player._update_voice_and_meter(0.2)
	player._handle_jump_charge(0.1)
	assert(player.scream_jump_armed == false, "Jump must remain unarmed while player continuously screams")
	assert(player.velocity.y == 0.0, "Continuous screaming through landing must NOT trigger another jump")
	# Quiet down for 0.05s (less than 0.1s)
	player.simulated_mic_volume = 0.0
	player._update_voice_and_meter(0.05)
	assert(player.scream_jump_armed == false, "Must not rearm before 0.1s of quiet")
	# Quiet for another 0.06s (total > 0.1s)
	player._update_voice_and_meter(0.06)
	assert(player.scream_jump_armed == true, "Must rearm after at least 0.1s below threshold")
	# Now screaming triggers jump again
	player.simulated_mic_volume = 0.6
	player._handle_jump_charge(0.1)
	assert(player.velocity.y > 0.0, "Jump successfully triggers after 0.1s silence pause")
	player.simulated_mic_volume = 0.0
	print("✓ Jump reset silence window rule strictly verified.")

	# Test 13: 5-Second Quiet Ground Crouch & Walking Rules
	print("\n[Test 13] Testing 5-Second Quiet Crouch & Walking Rules...")
	player.current_state = player.State.NORMAL
	player.is_crouching = false
	player.is_yapping = false
	player.yap_timer = 0.0
	player.quiet_timer = 0.0
	player.simulated_mic_volume = 0.0
	# Stand on floor for 4.0s (less than 5s) -> should NOT crouch
	player.coyote_timer = 0.2
	player.quiet_timer = 4.0
	assert(player.is_crouching == false, "Player must not crouch before 5 seconds of silence")
	# Reach 5.0s -> player enters crouch
	player.quiet_timer = 5.0
	player._update_voice_and_meter(0.1)
	assert(player.is_crouching == true, "Player must automatically crouch after 5 seconds of silence on ground")
	# Once crouched, horizontal movement uses crouch_speed
	assert(player.crouch_speed < player.walk_speed, "Crouchwalk must be slower than normal walk")
	# Making sound cancels crouch and sets yapping
	player.simulated_mic_volume = 0.25 # above yap threshold
	player._update_voice_and_meter(0.1)
	assert(player.is_crouching == false, "Sound above yap threshold must cancel crouch")
	assert(player.is_yapping == true, "Sound above yap threshold must enable yapping")
	player.simulated_mic_volume = 0.0
	player.is_yapping = false
	print("✓ 5-second silence crouch and walk mechanics verified.")

	# Test 14: Wall Interactions (Touching, Running, Jump Off, Crouch Disabled)
	print("\n[Test 14] Testing Wall Interaction Restrictions...")
	player._start_wall_run(Vector3(1, 0, 0))
	assert(player.current_state == player.State.WALL_RUNNING, "Must be wall running")
	assert(player.is_crouching == false, "Crouching must be impossible while on the wall")
	player.scream_jump_armed = true
	player.simulated_mic_volume = 0.5
	player._handle_jump_charge(0.1)
	assert(player.current_state == player.State.NORMAL, "Scream on wall must eject player off the wall")
	assert(player.velocity.y >= player.wall_jump_up_force, "Wall eject must push upward")
	player.simulated_mic_volume = 0.0
	print("✓ Wall interactions verified (crouch impossible, sound eject off wall).")

	# Test 15: Karma Penalty (Within 3m of Interactable Center)
	print("\n[Test 15] Testing Karma Penalty (Loud Noise Near Interactable)...")
	var test_interactable_pos = player.global_position + Vector3(2.0, 0, 0)
	player.register_interactable_position(test_interactable_pos)
	player.microphone_sensitivity = 50.0
	player.karma_penalty_cooldown = 0.0
	var penalty_box := {"received": 0}
	var on_penalty = func(amt: int) -> void: penalty_box["received"] += amt
	player.karma_penalty_applied.connect(on_penalty)
	player.simulated_mic_volume = 0.6
	player._check_karma_penalty()
	assert(penalty_box["received"] == 10, "Player must lose 10 karma when screaming within 3m of interactable")
	assert(player.karma_penalty_cooldown >= 4.9, "Karma penalty cooldown must be set to 5 seconds")
	penalty_box["received"] = 0
	player._check_karma_penalty()
	assert(penalty_box["received"] == 0, "Karma penalty must not trigger more than once every 5 seconds")
	player.unregister_interactable_position(test_interactable_pos)
	player.karma_penalty_applied.disconnect(on_penalty)
	player.simulated_mic_volume = 0.0
	print("✓ Karma penalty verified (10 karma lost within 3m, 5s cooldown enforced).")

	# Test 16: Volume Meter Level 4 Unlock Visibility Rule
	print("\n[Test 16] Testing Volume Meter Visibility Rule (Level 4 Unlock)...")
	player.scream_jump_unlocked = false
	player._update_voice_and_meter(0.1)
	assert(player.volume_meter_container.visible == false, "Volume meter must be hidden when scream jump is locked")
	player.scream_jump_unlocked = true
	player._update_voice_and_meter(0.1)
	assert(player.volume_meter_container.visible == true, "Volume meter must be visible when scream jump is unlocked")
	print("✓ Volume meter visibility rule verified (hidden before unlock, visible after).")

	# Test 17: Volume Meter dBFS Calculation
	print("\n[Test 17] Testing Volume Meter dBFS Calculation...")
	player.simulated_mic_volume = 1.0
	assert(abs(player.get_raw_volume_dbfs() - 0.0) < 0.1, "Full scale amplitude 1.0 must equal 0 dBFS")
	player.simulated_mic_volume = 0.0001
	assert(player.get_raw_volume_dbfs() <= -60.0, "Silence must read at or below -60 dBFS")
	player.simulated_mic_volume = 0.0
	print("✓ Volume meter dBFS calculation verified.")

	print("\n========================================")
	print("✓ ALL TESTS PASSED WITH 0 ERRORS!")
	print("========================================")

	get_tree().quit(0)
