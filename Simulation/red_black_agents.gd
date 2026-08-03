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
## The [b]red_black_agents.glsl[/b] source code has the computer shader logic.

## The node that is used to draw the agents to screen.
@onready var agent_particles: GPUParticles2D = %AgentParticles
@onready var time_passed_label: Label = %TimePassedLabel
@onready var fps_label: Label = %FPSLabel
@onready var pause_button: Button = %PauseButton
@onready var save_button: Button = %SaveButton
@onready var hash_viewer: HashViewer = %HashViewer
@onready var agent_generator: AgentGenerator = %AgentGenerator
@onready var camera_2d: Camera2D = %Camera2D
@onready var box_rendering: BoxRendering = %BoxRendering
@onready var gpu_state: GPUState = %GPUState
@onready var config_state: ConfigState = %ConfigState
@onready var simulation_state: SimulationState = %SimulationState

#region Engine Parameters (Parameters and settings controlled during run-time)

var paused: bool = false
var start_time: int = 0
var time_passed: int = 0
var click_location: Vector2 = Vector2.ZERO

#endregion

## Stores the values saved every frame of execution
var simulation_saver: SimulationSaver = SimulationSaver.new()
var sim_file: FileAccess
var frame: int = 0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				click_location = (event.position / camera_2d.zoom + camera_2d.offset)

## Runs when the scene is loaded.
func _ready() -> void:
	#import_config()
	
	start_time = Time.get_ticks_msec()
	
	config_state.initialize()
	agent_generator.generate_agents(simulation_state, config_state)
	
	if config_state.rendering:
		agent_particles.amount = simulation_state.agent_count
	else:
		agent_particles.emitting = false
	
	agent_particles.process_material.set_shader_parameter("radius", config_state.radius)
	
	hash_viewer.h_hashes = int(config_state.hashes.x)
	hash_viewer.v_hashes = int(config_state.hashes.y)
	hash_viewer.world_size = config_state.world_size
	hash_viewer.queue_redraw()
	
	box_rendering.initialize_box_rendering(config_state, simulation_state)
	
	camera_2d.offset = get_tree().root.size / 2
	
	# Connect GUI signals to functions
	pause_button.pressed.connect(pause)
	save_button.pressed.connect(save)
	
	var compute_setup: Callable = Callable(gpu_state, "run_setup").bind(simulation_state, config_state)
	RenderingServer.call_on_render_thread(compute_setup)

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
	
	var final_delta: float = delta * float(!paused)
	var process_callable: Callable = Callable(gpu_state, "gpu_process").bind(final_delta, simulation_state, config_state)
	RenderingServer.call_on_render_thread(process_callable)
	click_location = Vector2.ZERO

## Called on scene exit.
func _exit_tree() -> void:
	RenderingServer.call_on_render_thread(free_resources)

## Frees up the GPU memory.
func free_resources():
	gpu_state.free_resources()
