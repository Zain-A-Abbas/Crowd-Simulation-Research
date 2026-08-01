extends Node2D
class_name RedBlackAgents

## Class that creates the necessary buffers and uniforms to pass on agent simulation data to the GPU.
##
## The data of each individual agent is stored across textures, the reason for this being that Godot stores
## texture data entirely on the GPU, while allowing both compute, fragment, and vertex shaders to easily read and write from a texture.
## This prevents there from being a bottleneck in rendering as no rendering data has to pass by the CPU.
## The way this approach works in practice is that each pixel on the textures maps to a specific particle, and that the R, G, B, and A 
## channels on each texture stores a different piece of data.[br][br]
## e.g. the R and G channels on the 'agent_data_1' texture store the x and y position of each agent.[br][br]
## The [b]red_black_agents.glsl[/b] source code has the computer shader logic, while the [b]red_black_agents_shader.gdshader[/b] file is
## the particle shader used for actually rendering the agents to the screen.

## The node that is used to draw the agents to screen.
@onready var agent_particles: GPUParticles2D = $AgentParticles
@onready var time_passed_label: Label = %TimePassedLabel
@onready var fps_label: Label = %FPSLabel
@onready var pause_button: Button = %PauseButton
@onready var save_button: Button = %SaveButton
@onready var hash_viewer: HashViewer = %HashViewer
@onready var agent_generator: AgentGenerator = %AgentGenerator
@onready var camera_2d: Camera2D = %Camera2D
@onready var box_rendering: BoxRendering = %BoxRendering

## Enum storing all possible scenarios that can be simulated.
enum Scenarios {
	DISTANCE_CONSTRAINT,
	OPPOSING_AGENTS,
	OPPOSING_SMALL_GROUPS,
	OPPOSING_LARGE_GROUPS,
	CIRCLE_POSITION_EXCHANGE,
	RETARGETING_TEST,
	ESCAPE_TEST,
	CROWD_CIRCULATING_OBJECT,
}

const RED_BLACK_AGENTS_CONFIG_FILE: String = "user://red_black_agents_config.json"

# The seed for the random number generator
const SEED: int = 0

#region The following parameters are explicitly chosen based on the selected parameters in the Simulation Interface
## The currently chosen scenario
var scenario: Scenarios = Scenarios.DISTANCE_CONSTRAINT

## The number of agents.
var agent_count: int = 512

## Upper limit of velocity. 
var max_velocity: float = 32.0

## Radius of each agent.
var radius: float = 16.0

## Size of the world-space
var world_size: Vector2 = Vector2.ZERO

## Hash args
var use_spatial_hash: bool = false
var hash_size: int = 32
var horizontal_hash_count: int = 16
var vertical_hash_count: int = 16

#endregion

#region The following parameters are determined based on the above ones, by agent_generator.gd
## Size of the textures that store the agent data.
var image_size: int = 0

## Set on run-time.
var count: int = 0

## Texture 1 stores the position and color of each agent. RD (Rendering Device) texture allows mapping the image data to the Vulkan logical device.
var agent_data_1_texture_rd: Texture2DRD
## Texture 2 is used to select an agent to highlight it on the simulation, and see what other agents are able to collide with it.
var agent_data_2_texture_rd: Texture2DRD

## Starting positions.
var agent_positions: PackedVector2Array = []
## The current velocities of agents.
var agent_velocities: PackedVector2Array = []
## Equal to starting velocities.
var agent_preferred_velocities: PackedVector2Array = []
## Velocity scalar determined at start of application run
var agent_base_velocities: PackedFloat32Array = []
## Corrections applied to agent positions each frame. z index is used as a counter
var delta_corrections: PackedVector4Array = []

## Where the agents move towards 
var locomotion_targets: PackedVector2Array = []
## Points to the indices in the above array that an agent targets
var locomotion_indices: PackedInt32Array = []
## Stores the locomotion target mapped to a retargeting location and the next locomotion target
var retargeting_locomotion_indices: PackedInt32Array = []
## Stores the dimensions of retargeting locations
var retargeting_boxes: PackedVector4Array = []
var use_locomotion_targets: bool = false

## Physical walls that the agents can collide with.
var walls: PackedVector4Array = []

## If "true" then this agent is close enough to the currently selected agent (and in its spatial hash) for tracking
var agent_tracked: PackedFloat32Array = []

## The inverted mass of each agent.
var agent_inv_mass: PackedFloat32Array = []

## Radius of the individual agents. Only used when performing a simulation where agents have variable sizes.
var agent_radii: PackedFloat32Array = []

## Squared radius of the individual agents. Only used when performing a simulation where agents have variable sizes.
var agent_radii_sqr: PackedFloat32Array = []

var hash_count: int = 0

#endregion

var agent_data_descriptor: DescriptorSetResource = DescriptorSetResource.new()
var spatial_hash_descriptor: DescriptorSetResource = DescriptorSetResource.new()
var image_descriptor: DescriptorSetResource = DescriptorSetResource.new()
var shared_parameters_descriptor: DescriptorSetResource = DescriptorSetResource.new()

## The logical rendering device; allows for interaction with the low-level graphics API.
var rendering_device: RenderingDevice = RenderingServer.get_rendering_device()

## The shader instance created from SPIR-V.
var agent_compute_shader: RID
## The pipeline in which all of the compute commands are passed through.
var agent_pipeline: RID
## The bindings used to create the uniforms from.
var agent_bindings: Array[RDUniform]
var hash_bindings: Array[RDUniform]

## References to the actual descriptor sets
var agent_set: RID
var hash_set: RID
var image_set: RID
var shared_parameters_set: RID

var hashes: Vector2 = Vector2.ZERO

var hash_shader : RID
var hash_pipeline : RID

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var parameters: Dictionary = {}

#region Engine Parameters (Parameters and settings controlled during run-time)

var paused: bool = false
var start_time: int = 0
var time_passed: int = 0
var click_location: Vector2 =Vector2.ZERO

#endregion

## Stores the values saved every frame of execution
var simulation_saver: SimulationSaver = SimulationSaver.new()
var sim_file: FileAccess
var frame: int = 0

## Runs when the scene is loaded.
func _ready() -> void:
	
	import_config()
	if SEED == 0:
		rng.randomize()
	else:
		rng.seed = SEED
	
	start_time = Time.get_ticks_msec()
	
	# Connect GUI signals to functions
	pause_button.pressed.connect(pause)
	save_button.pressed.connect(save)
	
	agent_generator.generate_agents(self)
	image_size = ceili(sqrt(count))
	if parameters["disable_rendering"]:
		agent_particles.emitting = false
	else:
		agent_particles.amount = count
	
	agent_particles.process_material.set_shader_parameter("radius", radius)
	
	walls = []
	for wall in box_rendering.walls:
		walls.append(wall)
	
	box_rendering.retargeting_boxes = []
	for retargeting_box in retargeting_boxes:
		box_rendering.retargeting_boxes.append(retargeting_box)
	
	if walls.is_empty():
		walls.insert(0, Vector4.ZERO)
	
	# Retrieves references to the texture resources stored on the particle shader
	agent_data_1_texture_rd = agent_particles.process_material.get_shader_parameter("agent_data")
	agent_data_2_texture_rd = agent_particles.process_material.get_shader_parameter("agent_data_2")
	RenderingServer.call_on_render_thread(setup_compute)


func import_config():
	var config_file: FileAccess = FileAccess.open(RED_BLACK_AGENTS_CONFIG_FILE, FileAccess.READ)
	var config_json: JSON = JSON.new()
	config_json.parse(config_file.get_as_text())
	parameters = config_json.data
	agent_count = parameters["agent_count"]
	max_velocity = parameters["max_velocity"]
	radius = parameters["radius"]
	scenario = Scenarios[parameters["scenario"]]
	get_tree().root.size = (Vector2i(parameters["window_width"], parameters["window_height"]))
	world_size = Vector2(parameters["world_width"], parameters["world_height"])
	
	if parameters.has("use_hashes"):
		use_spatial_hash = parameters["use_hashes"]
	
	if use_spatial_hash:
		hash_size = parameters["hash_size"]
		hashes = Vector2(
			snappedf(world_size.x / hash_size, 1),
			snappedf(world_size.y / hash_size, 1),
		)
		
		hash_count = int(hashes.x * hashes.y)
		
		hash_viewer.h_hashes = int(hashes.x)
		hash_viewer.v_hashes = int(hashes.y)
	hash_viewer.world_size = world_size
	hash_viewer.queue_redraw()
	
	box_rendering.walls = []
	for wall in parameters["walls"]:
		box_rendering.walls.append(Vector4(wall[0], wall[1], wall[2], wall[3]))
	
	if parameters["save"] == true:
		start_save()

func start_save():
	var file_location: String = "user://" + Time.get_datetime_string_from_system().replace(":", "-") + ".sav"
	sim_file = FileAccess.open(file_location, FileAccess.WRITE)
 
func pause():
	paused = !paused

func save():
	sim_file.close()
	
	# Now that the raw file has been saved, open it again and write its contents in a human-readable format
	simulation_saver.save_red_black(sim_file.get_path())
	
	start_save()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				click_location = (event.position / camera_2d.zoom + camera_2d.offset)
	
## Runs every frame.
func _process(delta: float) -> void:
	if paused:
		return
	
	time_passed = Time.get_ticks_msec() - start_time
	@warning_ignore("integer_division")
	var hours: int = time_passed / 360000
	@warning_ignore("integer_division")
	var minutes: int = (time_passed % 360000) / 60000
	@warning_ignore("integer_division")
	var seconds: int = (time_passed % 60000) / 1000
	var ms: int = time_passed % 1000
	time_passed_label.text = "%02d:%02d:%02d.%03d" % [hours, minutes, seconds, ms]
	fps_label.text = "FPS: " + str(Performance.get_monitor(Performance.TIME_FPS))
	
	var finalDelta: float = delta * float(!paused)
	RenderingServer.call_on_render_thread(gpu_process.bind(finalDelta))
	
	click_location = Vector2.ZERO

## Processing behavior that has to run on the RenderingServer object.
func gpu_process(delta: float):
	if delta > 0:
		frame += 1
	
	# Every frame, replace the old StorageResource objects for int_params
	# and float_params with new ones, to advance the int stage and update the float delta
	
	var float_param_buffer_bytes: PackedByteArray = generate_float_parameter_buffer(delta)
	rendering_device.buffer_update(shared_parameters_descriptor.named_resources["float_params"].buffer, 0, float_param_buffer_bytes.size(), float_param_buffer_bytes)
	# Hash setup
	if use_spatial_hash:
		# Performs all the stages in bin_operations.glsl
		for n in range(0, 5):
			run_pipeline(hash_pipeline, n, hash_count)
	
	# Wall collisions and velocity stage
	run_pipeline(agent_pipeline, 0, agent_count)
	
	RenderingServer.force_sync() # May not be necessary
	
	for iteration in maxi(1, parameters["iteration_count"]):
		# Delta corrections calculations stage
		run_pipeline(agent_pipeline, 1, agent_count)
		RenderingServer.force_sync() # May not be necessary
		# Delta corrections applications stage
		run_pipeline(agent_pipeline, 2, agent_count)
		# Final move stage
		run_pipeline(agent_pipeline, 3, agent_count)
	
	# Saving
	if parameters["save"] == true:
		sim_file.store_var((agent_data_1_texture_rd.get_image().get_data().to_float32_array()))

func run_pipeline(pipieline: RID, pipeline_stage: int, dispatch_count: int):
	var int_param_buffer_bytes: PackedByteArray = generate_int_parameter_buffer(pipeline_stage)
	rendering_device.buffer_update(shared_parameters_descriptor.named_resources["int_params"].buffer, 0, int_param_buffer_bytes.size(), int_param_buffer_bytes)
	run_compute(pipieline, maxi(count, dispatch_count))

func generate_int_parameter_buffer(stage: int) -> PackedByteArray:
	var ints: PackedInt32Array = [
		count,
		stage,
		int(use_spatial_hash),
		int(use_locomotion_targets),
		parameters["constraint_type"],
		walls.size(),
		parameters["iteration_count"],
		scenario
	]
	
	return ints.to_byte_array()

func generate_float_parameter_buffer(delta: float) -> PackedByteArray:
	var floats: PackedFloat32Array = [
		image_size,
		world_size.x,
		world_size.y,
		radius,
		radius * radius * 1.05 * 1.05, #radius_squared
		delta,
		click_location.x,
		click_location.y,
		parameters["neighbour_radius"],
		0.0, # Padding
		0.0, # Padding,
		0.0 # Padding
	]
	
	# append_array must be used when including an additional array in parameter data
	var packed_data: PackedFloat32Array = []
	packed_data.append_array(floats)
	
	#packed_data.append_array(agent_inv_mass)
	
	return packed_data.to_byte_array()

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

## Sets up the computer shader once.
func setup_compute():
	create_shaders()
	create_descriptors()
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

func create_descriptors():
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(agent_positions, 0))
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(agent_positions, 1)) # Previous positions uniform
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(agent_preferred_velocities, 2)) # Normal velocity
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(agent_preferred_velocities, 3)) # Preferred velocities
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(agent_base_velocities, 4))
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(delta_corrections, 5))
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(locomotion_targets, 6))
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(locomotion_indices, 7))
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(retargeting_locomotion_indices, 8))
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(retargeting_boxes, 9))
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(agent_tracked, 10))
	agent_data_descriptor.add_resource(StorageResource.create_packed_array_uniform(walls, 11))
	
	var hash_int_params: PackedInt32Array = PackedInt32Array([hash_size, hashes.x, hashes.y, hash_count])
	spatial_hash_descriptor.add_resource(StorageResource.create_packed_array_uniform(hash_int_params, 0))
	spatial_hash_descriptor.add_resource(StorageResource.create_int_array_uniform(agent_count, 1))
	spatial_hash_descriptor.add_resource(StorageResource.create_int_array_uniform(hash_count, 2))
	spatial_hash_descriptor.add_resource(StorageResource.create_int_array_uniform(hash_count, 3))
	spatial_hash_descriptor.add_resource(StorageResource.create_int_array_uniform(hash_count, 4))
	spatial_hash_descriptor.add_resource(StorageResource.create_int_array_uniform(agent_count, 5))
	
	image_descriptor.add_resource(StorageResource.create_image_uniform(agent_data_1_texture_rd, image_size, 0))
	image_descriptor.add_resource(StorageResource.create_image_uniform(agent_data_2_texture_rd, image_size, 1))

	var debugging_data: PackedFloat32Array = [0.0, 0.0, 0.0, 0.0]
	
	shared_parameters_descriptor.add_resource(StorageResource.create_params_uniform(generate_int_parameter_buffer(0), 0), "int_params")
	shared_parameters_descriptor.add_resource(StorageResource.create_params_uniform(generate_float_parameter_buffer(0), 1), "float_params")
	shared_parameters_descriptor.add_resource(StorageResource.create_packed_array_uniform(debugging_data, 2))

func create_uniform_sets():
	agent_set = make_set(agent_data_descriptor, agent_compute_shader, 0)
	hash_set = make_set(spatial_hash_descriptor, hash_shader, 1)
	image_set = make_set(image_descriptor, agent_compute_shader, 2)
	shared_parameters_set = make_set(shared_parameters_descriptor, agent_compute_shader, 3)

func make_set(descriptor: DescriptorSetResource, shader: RID, shader_set) -> RID:
	return rendering_device.uniform_set_create(descriptor.get_uniforms(), shader, shader_set)

## Called on scene exit.
func _exit_tree() -> void:
	RenderingServer.call_on_render_thread(free_resources)

## Frees up the GPU memory.
func free_resources():
	rendering_device.free_rid(agent_set)
	rendering_device.free_rid(hash_set)
	rendering_device.free_rid(image_set)
	rendering_device.free_rid(shared_parameters_set)
	
	rendering_device.free_rid(agent_pipeline)
	rendering_device.free_rid(hash_pipeline)
	rendering_device.free_rid(agent_compute_shader)
	rendering_device.free_rid(hash_shader)
	
	agent_data_descriptor.freeBindings()
	spatial_hash_descriptor.freeBindings()
	image_descriptor.freeBindings()
	shared_parameters_descriptor.freeBindings()
