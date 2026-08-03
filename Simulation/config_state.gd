extends Node
class_name ConfigState

## Contains data explicitly chosen on the interface in Simulation Interface.

enum Scenarios {
	BASE_SCENARIO,
	OPPOSING_AGENTS,
	OPPOSING_SMALL_GROUPS,
	OPPOSING_LARGE_GROUPS,
	CIRCLE_POSITION_EXCHANGE,
	RETARGETING_TEST,
	ESCAPE_TEST,
	CROWD_CIRCULATING_OBJECT,
}

enum ConstraintTypes {
	LONG_RANGE,
	SHORT_RANGE
}

const RED_BLACK_AGENTS_CONFIG_FILE: String = "res://Simulation/red_black_agents_config.json"

func initialize(config_location: String = "") -> void:
	if config_location == "":
		config_location = RED_BLACK_AGENTS_CONFIG_FILE
	var config_file: FileAccess = FileAccess.open(config_location, FileAccess.READ)
	var config_json: JSON = JSON.new()
	config_json.parse(config_file.get_as_text())
	
	var parameters: Dictionary = config_json.data
	agent_count = parameters["agent_count"]
	max_velocity = parameters["max_velocity"]
	radius = parameters["radius"]
	scenario = Scenarios[parameters["scenario"]]
	constraint_type = ConstraintTypes[parameters["constraint_type"]]
	get_tree().root.size = (Vector2i(parameters["window_width"], parameters["window_height"]))
	world_size = Vector2(parameters["world_width"], parameters["world_height"])
	neighbour_visualization_radius = parameters["neighbour_visualization_radius"]
	
	# Retrieve scenario-specific config data
	match scenario:
		Scenarios.OPPOSING_SMALL_GROUPS, Scenarios.OPPOSING_LARGE_GROUPS:
			opposing_groups_x_distance = parameters["opposing_groups_x_distance"]
			opposing_groups_y_offset = parameters["opposing_groups_y_offset"]
		Scenarios.CIRCLE_POSITION_EXCHANGE:
			circle_radius = parameters["circle_radius"]
	
	rendering = !parameters["disable_rendering"]
	
	if parameters.has("use_hashes"):
		use_spatial_hash = parameters["use_hashes"]
	
	if use_spatial_hash:
		hash_size = parameters["hash_size"]
		hashes = Vector2(
			snappedf(world_size.x / hash_size, 1),
			snappedf(world_size.y / hash_size, 1),
		)
		
		hash_count = int(hashes.x * hashes.y)
	
	walls = parameters["walls"]
	if walls.is_empty():
		walls.insert(0, Vector4.ZERO)
	
	save = parameters["save"]


var scenario: Scenarios = Scenarios.BASE_SCENARIO
var constraint_type: ConstraintTypes
var rendering: bool = true

## The number of agents.
var agent_count: int = 512

## Upper limit of velocity. 
var max_velocity: float = 32.0

## Radius of each agent.
var radius: float = 16.0

## Size of the world-space
var world_size: Vector2 = Vector2.ZERO

## Spatial Hash args
var use_spatial_hash: bool = false
var hash_size: int = 32
var hashes: Vector2 = Vector2.ZERO
var hash_count: int = 0

var iteration_count: int = 1
var neighbour_visualization_radius: float = 128.0

var walls: PackedVector4Array = []

var save: bool = false

#region Scenario-specific data

var opposing_groups_x_distance: float = 0.0
var opposing_groups_y_offset: float = 0.0

var circle_radius: float

#endregion
