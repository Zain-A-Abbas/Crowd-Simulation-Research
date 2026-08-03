extends Node
class_name GPUState

## Class that handles all GPU interactions.

@onready var agent_particles: GPUParticles2D = %AgentParticles

## The logical rendering device; allows for interaction with the low-level graphics API.
var rendering_device: RenderingDevice = RenderingServer.get_rendering_device()

var agent_data_descriptor: DescriptorSetResource = DescriptorSetResource.new()
var spatial_hash_descriptor: DescriptorSetResource = DescriptorSetResource.new()
var image_descriptor: DescriptorSetResource = DescriptorSetResource.new()
var shared_parameters_descriptor: DescriptorSetResource = DescriptorSetResource.new()

## The shader instances created from SPIR-V.
var agent_compute_shader: RID
var hash_shader : RID
## The pipelines in which all of the compute commands are passed through.
var agent_pipeline: RID
var hash_pipeline : RID
## The bindings used to create the uniforms from.
var agent_bindings: Array[RDUniform]
var hash_bindings: Array[RDUniform]

## Texture 1 stores the position and color of each agent. RD (Rendering Device) texture allows mapping the image data to the Vulkan logical device.
var agent_data_1_texture_rd: Texture2DRD
## Texture 2 is used to select an agent to highlight it on the simulation, and see what other agents are able to collide with it.
var agent_data_2_texture_rd: Texture2DRD

## References to the actual descriptor sets
var agent_set: RID
var hash_set: RID
var image_set: RID
var shared_parameters_set: RID

func run_setup(simulation_state: SimulationState, config_state: ConfigState):
	create_shaders()
	create_descriptors(simulation_state, config_state)
	create_uniform_sets()

func create_shaders():
	# Compiles the .glsl to spirv, and then creates the shader instance
	var shader: RDShaderFile = load("res://Simulation/red_black_agents.glsl")
	var compiled_shader: RDShaderSPIRV = shader.get_spirv()
	agent_compute_shader = rendering_device.shader_create_from_spirv(compiled_shader)
	agent_pipeline = rendering_device.compute_pipeline_create(agent_compute_shader)
	
	shader = load("res://Simulation/bin_operations.glsl")
	compiled_shader = shader.get_spirv()
	hash_shader = rendering_device.shader_create_from_spirv(compiled_shader)
	hash_pipeline = rendering_device.compute_pipeline_create(hash_shader)

func create_descriptors(simulation_state: SimulationState, config_state: ConfigState):
	var starting_delta_corrections: PackedVector4Array = PackedVector4Array()
	starting_delta_corrections.resize(simulation_state.agent_count)
	
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(simulation_state.agent_positions, 0))
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(simulation_state.agent_positions, 1))  # Previous positions uniform
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(simulation_state.agent_preferred_velocities, 2)) # Normal velocity always starts out as preferred
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(simulation_state.agent_preferred_velocities, 3))  # Preferred velocities
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(simulation_state.agent_base_velocities, 4))
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(starting_delta_corrections, 5))
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(simulation_state.locomotion_targets, 6))
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(simulation_state.locomotion_indices, 7))
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(simulation_state.retargeting_locomotion_indices, 8))
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(simulation_state.retargeting_boxes, 9))
	agent_data_descriptor.add_resource(StorageResource.create_float_array_uniform(simulation_state.agent_count, 10)) # Agents tracked
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(config_state.walls, 11))
	
	var hash_int_params: PackedInt32Array = PackedInt32Array([
		config_state.hash_size,
		config_state.hashes.x,
		config_state.hashes.y,
		config_state.hash_count
		])
	spatial_hash_descriptor.add_resource(StorageResource.create_packed_array_uniform(hash_int_params, 0))
	spatial_hash_descriptor.add_resource(StorageResource.create_int_array_uniform(simulation_state.agent_count, 1))
	spatial_hash_descriptor.add_resource(StorageResource.create_int_array_uniform(config_state.hash_count, 2))
	spatial_hash_descriptor.add_resource(StorageResource.create_int_array_uniform(config_state.hash_count, 3))
	spatial_hash_descriptor.add_resource(StorageResource.create_int_array_uniform(config_state.hash_count, 4))
	spatial_hash_descriptor.add_resource(StorageResource.create_int_array_uniform(simulation_state.agent_count, 5))
	
	agent_data_1_texture_rd = agent_particles.process_material.get_shader_parameter("agent_data")
	agent_data_2_texture_rd = agent_particles.process_material.get_shader_parameter("agent_data_2")
	image_descriptor.add_resource(StorageResource.create_image_uniform(agent_data_1_texture_rd, simulation_state.image_size, 0))
	image_descriptor.add_resource(StorageResource.create_image_uniform(agent_data_2_texture_rd, simulation_state.image_size, 1))

	var debugging_data: PackedFloat32Array = [0.0, 0.0, 0.0, 0.0]
	
	shared_parameters_descriptor.add_resource(StorageResource.create_params_uniform(generate_int_parameter_buffer(0, simulation_state, config_state), 0), "int_params")
	shared_parameters_descriptor.add_resource(StorageResource.create_params_uniform(generate_float_parameter_buffer(0, simulation_state, config_state), 1), "float_params")
	shared_parameters_descriptor.add_resource(StorageResource.create_packed_array_uniform(debugging_data, 2))

func create_uniform_sets():
	agent_set = make_set(agent_data_descriptor, agent_compute_shader, 0)
	hash_set = make_set(spatial_hash_descriptor, hash_shader, 1)
	image_set = make_set(image_descriptor, agent_compute_shader, 2)
	shared_parameters_set = make_set(shared_parameters_descriptor, agent_compute_shader, 3)

func make_set(descriptor: DescriptorSetResource, shader: RID, shader_set) -> RID:
	return rendering_device.uniform_set_create(descriptor.get_uniforms(), shader, shader_set)

func generate_int_parameter_buffer(stage: int, simulation_state: SimulationState, config_state: ConfigState) -> PackedByteArray:
	var ints: PackedInt32Array = [
		simulation_state.agent_count,
		stage,
		int(config_state.use_spatial_hash),
		int(simulation_state.use_locomotion_targets),
		config_state.constraint_type,
		config_state.walls.size(),
		config_state.iteration_count,
		config_state.scenario
	]
	
	return ints.to_byte_array()

func generate_float_parameter_buffer(delta: float, simulation_state: SimulationState, config_state: ConfigState) -> PackedByteArray:
	var floats: PackedFloat32Array = [
		simulation_state.image_size,
		config_state.world_size.x,
		config_state.world_size.y,
		config_state.radius,
		config_state.radius * config_state.radius * 1.05 * 1.05, #radius_squared
		delta,
		simulation_state.click_location.x,
		simulation_state.click_location.y,
		config_state.neighbour_visualization_radius,
		0.0, # Padding
		0.0, # Padding,
		0.0 # Padding
	]
	
	# append_array must be used when including an additional array in parameter data
	var packed_data: PackedFloat32Array = []
	packed_data.append_array(floats)
	
	#packed_data.append_array(agent_inv_mass)
	
	return packed_data.to_byte_array()

func begin_gpu_process(delta: float, simulation_state: SimulationState, config_state: ConfigState):
	var callable: Callable = Callable(self, "gpu_process").bind(delta, simulation_state, config_state)
	RenderingServer.call_on_render_thread(callable)

## Processing behavior that has to run on the RenderingServer object.
func gpu_process(delta: float, simulation_state: SimulationState, config_state: ConfigState):
	var frame: int = 0
	if delta > 0:
		frame += 1
	
	# Every frame, replace the old StorageResource objects for int_params
	# and float_params with new ones, to advance the int stage and update the float delta
	
	var float_param_buffer_bytes: PackedByteArray = generate_float_parameter_buffer(delta, simulation_state, config_state)
	rendering_device.buffer_update(shared_parameters_descriptor.named_resources["float_params"].buffer, 0, float_param_buffer_bytes.size(), float_param_buffer_bytes)
	# Hash setup
	if config_state.use_spatial_hash:
		# Performs all the stages in bin_operations.glsl
		for n in range(0, 5):
			run_pipeline(hash_pipeline, n, config_state.hash_count, simulation_state, config_state)
	
	# Wall collisions and velocity stage
	run_pipeline(agent_pipeline, 0, simulation_state.agent_count, simulation_state, config_state)
	
	RenderingServer.force_sync() # May not be necessary
	
	for iteration in maxi(1, config_state.iteration_count):
		# Delta corrections calculations stage
		run_pipeline(agent_pipeline, 1, simulation_state.agent_count, simulation_state, config_state)
		RenderingServer.force_sync() # May not be necessary
		# Delta corrections applications stage
		run_pipeline(agent_pipeline, 2, simulation_state.agent_count, simulation_state, config_state)
		# Final move stage
		run_pipeline(agent_pipeline, 3, simulation_state.agent_count, simulation_state, config_state)
	
	# Saving
	if config_state.save:
		pass
		#sim_file.store_var((agent_data_1_texture_rd.get_image().get_data().to_float32_array()))

func run_pipeline(pipeline: RID, pipeline_stage: int, dispatch_count: int, simulation_state: SimulationState, config_state: ConfigState):
	var int_param_buffer_bytes: PackedByteArray = generate_int_parameter_buffer(pipeline_stage, simulation_state, config_state)
	rendering_device.buffer_update(shared_parameters_descriptor.named_resources["int_params"].buffer, 0, int_param_buffer_bytes.size(), int_param_buffer_bytes)
	run_compute(pipeline, maxi(simulation_state.agent_count, dispatch_count))

## The compute processing that is called every frame.
## num refers to the number of objects being operated on. 
func run_compute(pipeline: RID, num: int):
	var compute_list: int = rendering_device.compute_list_begin()
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rendering_device.compute_list_bind_uniform_set(compute_list, agent_set, 0)
	rendering_device.compute_list_bind_uniform_set(compute_list, hash_set, 1)
	rendering_device.compute_list_bind_uniform_set(compute_list, image_set, 2)
	rendering_device.compute_list_bind_uniform_set(compute_list, shared_parameters_set, 3)
	rendering_device.compute_list_dispatch(compute_list, ceil(num / 1024.), 1, 1)
	rendering_device.compute_list_end()

func free_resources():
	rendering_device.free_rid(agent_set)
	rendering_device.free_rid(hash_set)
	rendering_device.free_rid(image_set)
	rendering_device.free_rid(shared_parameters_set)
	
	rendering_device.free_rid(agent_pipeline)
	rendering_device.free_rid(hash_pipeline)
	rendering_device.free_rid(agent_compute_shader)
	rendering_device.free_rid(hash_shader)
	
	agent_data_descriptor.free_bindings()
	spatial_hash_descriptor.free_bindings()
	image_descriptor.free_bindings()
	shared_parameters_descriptor.free_bindings()
