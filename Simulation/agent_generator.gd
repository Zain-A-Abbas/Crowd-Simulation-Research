extends Node
class_name AgentGenerator

## Using the configuration data, fills in SimulationState with data that is
## either set or randomzied based on the simulation, such as randomly
## assigning positions to agents

func generate_agents(simulation_state: SimulationState, config: ConfigState) -> SimulationState:
	simulation_state.agent_count = config.agent_count
	
	match config.scenario:
		ConfigState.Scenarios.BASE_SCENARIO:
			base_scenario(config, simulation_state)
		ConfigState.Scenarios.OPPOSING_AGENTS:
			opposing_agents(config, simulation_state)
		ConfigState.Scenarios.OPPOSING_SMALL_GROUPS:
			opposing_groups(config, simulation_state, true)
		ConfigState.Scenarios.OPPOSING_LARGE_GROUPS:
			opposing_groups(config, simulation_state, false)
		ConfigState.Scenarios.CIRCLE_POSITION_EXCHANGE:
			circle_position_exchange(config, simulation_state)
		ConfigState.Scenarios.ESCAPE_TEST:
			escape_test(config, simulation_state)
		ConfigState.Scenarios.RETARGETING_TEST:
			retargeting_test(config, simulation_state)
		ConfigState.Scenarios.CROWD_CIRCULATING_OBJECT:
			crowd_circulating_object(config, simulation_state)
	
	simulation_state.image_size = ceili(sqrt(simulation_state.agent_count))
	
	return simulation_state


func base_scenario(config: ConfigState, state: SimulationState):
	for agent in state.agent_count:
		state.agent_positions.append(Vector2(randf() * config.world_size.x, randf() * config.world_size.y))
		var base_velocity: float = randf() * config.max_velocity
		var preferred_velocity: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * base_velocity
		state.agent_preferred_velocities.append(preferred_velocity)
		state.agent_base_velocities.append(base_velocity)
		state.agent_inv_mass.append(randf_range(0.2, 0.4)) # Unsure as of yet if this range is correct. 

func opposing_agents(config: ConfigState, state: SimulationState):
	state.agent_count = 2
	state.agent_positions.append_array([Vector2(200, 200), Vector2(350, 200)])
	state.agent_preferred_velocities.append_array([Vector2(20, 0), Vector2(-20, 0)])
	state.agent_base_velocities.append_array([20, 20])
	state.agent_inv_mass.append_array([0.2,0.2])

func opposing_groups(config: ConfigState, state: SimulationState, small: bool):
	if state.agent_count % 2 == 1:
		state.agent_count += 1
	var agents_per_group: int = state.agent_count / 2
	var agents_per_row: int = 0
	var rows: int = 0
	
	if small:
		agents_per_row = sqrt(agents_per_group) * 2
		rows = sqrt(agents_per_group) / 2
	else:
		agents_per_row = sqrt(agents_per_group) / 2
		rows = sqrt(agents_per_group) * 2
	
	var agent_gap: Vector2 = Vector2(config.radius * 2 * 1.25, config.radius * 2 * 1.25)
	var group_positions: Array[Vector2] = [
		Vector2(100, 200),
		Vector2(100 + agents_per_row * agent_gap.x + config.opposing_groups_x_distance, 200 + config.opposing_groups_y_offset)
		]
	var group_velocities: Array[Vector2] = [Vector2(config.max_velocity, 0), Vector2(-config.max_velocity, 0)]
	for z in 2:
		for row in rows:
			for row_position in agents_per_row:
				state.agent_positions.append(group_positions[z] + Vector2(row_position * agent_gap.x, row * agent_gap.y))
				state.agent_preferred_velocities.append(group_velocities[z])
				state.agent_base_velocities.append(group_velocities[z].length())
				state.agent_inv_mass.append(0.5)

func circle_position_exchange(config: ConfigState, state: SimulationState):
	state.use_locomotion_targets = true
	
	var circle_radius: float = config.circle_radius
	var circle_center: Vector2 = Vector2(circle_radius, circle_radius) + Vector2(256, 256)
	var angle_offset: float = 0.0
	
	for agent in state.agent_count:
		var starting_position: Vector2 = Vector2(
			sin(angle_offset),
			cos(angle_offset)
		) * circle_radius + circle_center
		
		state.agent_positions.append(starting_position)
		
		state.locomotion_targets.append(Vector2(
			sin(angle_offset + PI),
			cos(angle_offset + PI)
		) * circle_radius + circle_center)
		
		state.locomotion_indices.append(agent)
		state.retargeting_locomotion_indices.append(agent)
		state.retargeting_boxes.append(Vector4.ZERO)
		
		state.agent_preferred_velocities.append(Vector2(config.max_velocity, 0))
		state.agent_base_velocities.append(config.max_velocity)
		state.agent_tracked.append(0.0)
		state.agent_inv_mass.append(randf_range(0.2, 0.4)) # Unsure as of yet if this range is correct. 
		
		angle_offset += deg_to_rad(360.0 / state.agent_count)

func escape_test(config: ConfigState, state: SimulationState):
	state.use_locomotion_targets = true
	
	state.locomotion_targets.append_array([Vector2(425, 350), Vector2(475, 350), Vector2(925, 350)])
	state.retargeting_boxes.append_array([Vector4(400, 325, 50, 50), Vector4(450, 325, 50, 50), Vector4(900, 325, 50, 50)])
	state.retargeting_locomotion_indices.append_array([1, 2, 2])
	
	# override config walls with the specific walls made for this test
	config.walls.clear()
	config.walls.append_array([
		Vector4(0, 0, 500, 100),
		Vector4(0, 600, 500, 100),
		Vector4(450, 100, 50, 225),
		Vector4(450, 100+225+50, 50, 225),
	])
	
	var spawn_box: Vector4 = Vector4(50, 150, 400, 450)
	
	for agent in state.agent_count:
		state.agent_positions.append(Vector2(spawn_box.x, spawn_box.y) + Vector2(spawn_box.z * randf(), spawn_box.w * randf()))
		state.agent_preferred_velocities.append(Vector2(config.max_velocity, 0))
		state.agent_base_velocities.append(config.max_velocity)
		
		state.locomotion_indices.append(0)
		state.retargeting_locomotion_indices.append(0)
		state.retargeting_boxes.append(Vector4.ZERO)
		
		state.agent_inv_mass.append(randf_range(0.2, 0.4))

func retargeting_test(config: ConfigState, state: SimulationState):
	state.use_locomotion_targets = true
	state.locomotion_targets.append_array([Vector2(700, 300), Vector2(600, 700), Vector2(300, 600)])
	state.retargeting_boxes.append_array([Vector4(600, 200, 200, 200), Vector4(500, 600, 200, 200), Vector4(200, 550, 200, 100)])
	state.retargeting_locomotion_indices.append_array([1, 2, 2])
	
	var spawn_box: Vector4 = Vector4(100, 100, 250, 250)
	
	for agent in state.agent_count:
		state.agent_positions.append(Vector2(spawn_box.x, spawn_box.y) + Vector2(spawn_box.z * randf(), spawn_box.w * randf()))
		state.agent_preferred_velocities.append(Vector2(config.max_velocity, 0))
		state.agent_base_velocities.append(config.max_velocity)
		state.locomotion_indices.append(0)
		state.retargeting_locomotion_indices.append(0)
		state.retargeting_boxes.append(Vector4.ZERO)
		state.agent_inv_mass.append(randf_range(0.2, 0.4))

func crowd_circulating_object(config: ConfigState, state: SimulationState):
	config.walls.clear()
	config.walls.append_array([
		Vector4(0, 0, 2000, 10),
		Vector4(0, 10, 10, 2000),
		Vector4(10, 1990, 2000, 10),
		Vector4(1990, 10, 100, 2000),
		
		Vector4(940, 950, 120, 100) # Box
	])
	
	for agent in state.agent_count:
		var starting_position: Vector2 = Vector2(10 + 1980 * randf(), 10 + 1980 * randf())
		state.agent_positions.append(starting_position)
		var base_velocity: float = randf() * config.max_velocity
		var preferred_velocity: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * base_velocity
		state.agent_preferred_velocities.append(preferred_velocity)
		state.agent_base_velocities.append(base_velocity)
		state.agent_inv_mass.append(randf_range(0.2, 0.4)) # Unsure as of yet if this range is correct. 
		#agent_radii.append(radius)
