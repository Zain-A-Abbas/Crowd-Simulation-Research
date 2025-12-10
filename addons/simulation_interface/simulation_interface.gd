@tool
extends MarginContainer
class_name SimulationInterface

const WALL_INFORMATION = preload("res://addons/simulation_interface/wall_information.tscn")

@onready var agent_count_spin_box: SpinBox = %AgentCountSpinBox
@onready var scenario_option: OptionButton = %ScenarioOption
@onready var max_velocity_spinbox: SpinBox = %MaxVelocitySpinbox
@onready var radius_spin_box: SpinBox = %RadiusSpinBox
@onready var rendering_check_box: CheckBox = %RenderingCheckBox
@onready var save_check_box: CheckBox = %SaveCheckBox
@onready var start_button: Button = %StartButton
@onready var window_x_spin_box: SpinBox = %WindowXSpinBox
@onready var window_y_spin_box: SpinBox = %WindowYSpinBox
@onready var world_width_spin_box: SpinBox = %WorldWidthSpinBox
@onready var world_height_spin_box: SpinBox = %WorldHeightSpinBox
@onready var hashes_spin_box: SpinBox = %HashesSpinBox
@onready var spatial_hashes_toggle: CheckButton = %SpatialHashesToggle
@onready var hash_settings_hbox: HBoxContainer = %HashSettingsHbox
@onready var circle_simulation_options = %CircleSimulationOptions
@onready var circle_radius_spinbox = %CircleRadiusSpinbox
@onready var opposing_agents_options = %OpposingAgentsOptions
@onready var opposing_distance_spinbox_x = %OpposingDistanceSpinboxX
@onready var opposing_distance_spinbox_y = %OpposingDistanceSpinboxY
@onready var neighbour_radius_spin_box: SpinBox = %NeighbourRadiusSpinBox
@onready var constraint_type: OptionButton = %ConstraintType
@onready var add_wall_button: Button = %AddWallButton
@onready var wall_instance_v_box: VBoxContainer = %WallInstanceVBox
@onready var iteration_count_spinbox: SpinBox = %IterationCountSpinbox

@onready var error_label: Label = %ErrorLabel

var config_file_location: String = RedBlackAgents.RED_BLACK_AGENTS_CONFIG_FILE
const RED_BLACK_AGENTS_PATH: String = "res://Preliminary Simulation/red_black_agents.tscn"

func _ready() -> void:
	circle_simulation_options.visible = false
	
	start_button.pressed.connect(start_simulation)
	spatial_hashes_toggle.toggled.connect(hash_settings_hbox.set_visible.bind())
	scenario_option.item_selected.connect(set_scenario)
	scenario_option.clear()
	for scenario in RedBlackAgents.Scenarios.keys():
		scenario_option.add_item(scenario)
	
	add_wall_button.pressed.connect(add_wall_instance)

func start_simulation():
	if (step_decimals(window_x_spin_box.value / hashes_spin_box.value) > 0.0 || step_decimals(window_y_spin_box.value / hashes_spin_box.value) > 0.0):
		set_error_text("Hash count must be divisible by window width and height")
		return
	
	
	var param_dict: Dictionary[String, Variant] = {
		"agent_count": agent_count_spin_box.value,
		"max_velocity": max_velocity_spinbox.value,
		"radius": radius_spin_box.value,
		"scenario": scenario_option.get_item_text(scenario_option.selected),
		"disable_rendering": rendering_check_box.button_pressed,
		"save": save_check_box.button_pressed,
		"window_width": window_x_spin_box.value,
		"window_height": window_y_spin_box.value,
		"world_width": world_width_spin_box.value,
		"world_height": world_height_spin_box.value,
		"use_hashes": spatial_hashes_toggle.button_pressed,
		"hash_size": hashes_spin_box.value,
		"neighbour_radius": neighbour_radius_spin_box.value,
		"circle_radius": circle_radius_spinbox.value,
		"opposing_groups_x_distance": opposing_distance_spinbox_x.value,
		"opposing_groups_y_offset": opposing_distance_spinbox_y.value,
		"constraint_type": constraint_type.selected,
		"walls": get_wall_data(),
		"iteration_count": iteration_count_spinbox.value
	}
	
	var config_file: FileAccess = FileAccess.open(config_file_location, FileAccess.WRITE)
	config_file.store_line(JSON.stringify(param_dict))
	config_file.close()
	if Engine.is_editor_hint():
		EditorInterface.play_custom_scene(RED_BLACK_AGENTS_PATH)
	else:
		get_tree().change_scene_to_file(RED_BLACK_AGENTS_PATH)

func set_error_text(text: String):
	error_label.text = text
	await get_tree().create_timer(2.0).timeout
	error_label.text = ""

func set_scenario(idx: int):
	circle_simulation_options.visible = is_scenario(RedBlackAgents.Scenarios.CIRCLE_POSITION_EXCHANGE)
	opposing_agents_options.visible = is_scenario(RedBlackAgents.Scenarios.OPPOSING_SMALL_GROUPS) || is_scenario(RedBlackAgents.Scenarios.OPPOSING_LARGE_GROUPS)
	
	if is_scenario(RedBlackAgents.Scenarios.CROWD_CIRCULATING_OBJECT):
		window_x_spin_box.editable = false
		window_y_spin_box.editable = false
		world_width_spin_box.editable = false
		world_height_spin_box.editable = false
		hashes_spin_box.editable = false
		
		window_x_spin_box.value = 1000
		window_y_spin_box.value = 1000
		world_width_spin_box.value = 2000
		world_height_spin_box.value = 2000
		hashes_spin_box.value = 50
	else:
		window_x_spin_box.editable = true
		window_y_spin_box.editable = true
		world_width_spin_box.editable = true
		world_height_spin_box.editable = true
		hashes_spin_box.editable = true

func is_scenario(scenario: RedBlackAgents.Scenarios):
	var scenario_text: String = scenario_option.get_item_text(scenario_option.selected)
	return RedBlackAgents.Scenarios[scenario_text] == scenario

func add_wall_instance():
	var new_wall_instance: WallInformation = WALL_INFORMATION.instantiate()
	wall_instance_v_box.add_child(new_wall_instance)

func get_wall_data() -> Array:
	var walls: Array = []
	
	var wall_data: PackedVector4Array = []
	for child in wall_instance_v_box.get_children():
		if child is WallInformation:
			var new_wall: Array[float] = []
			new_wall.append(child.x_spinbox.value)
			new_wall.append(child.y_spinbox.value)
			new_wall.append(child.width_spinbox.value)
			new_wall.append(child.height_spinbox.value)
			walls.append(new_wall)
	return walls
