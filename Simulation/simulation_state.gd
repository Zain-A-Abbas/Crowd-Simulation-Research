extends Node
class_name SimulationState

## This class contains information about the simulation that is created on runtime.
## The information is filled out in agent_creator.gd, based on the seed and the information
## provided by the ConfigState class.

## The current scenario being simulated
var scenario: ConfigState.Scenarios = ConfigState.Scenarios.BASE_SCENARIO

## Number of agents generated for this simulation.
var agent_count: int = 0

## Size of the textures storing agent data.
var image_size: int = 0

#region Agent data

var agent_positions: PackedVector2Array = []

## The velocity agents try to revert to
var agent_preferred_velocities: PackedVector2Array = []

## Scalar movement speed assigned at simulation start
var agent_base_velocities: PackedFloat32Array = []

#endregion

#region Navigation

## Navigation targets.
var locomotion_targets: PackedVector2Array = []

## Current target index for each agent.
var locomotion_indices: PackedInt32Array = []

## Retargeting lookup table.
var retargeting_locomotion_indices: PackedInt32Array = []

## Retargeting regions.
var retargeting_boxes: PackedVector4Array = []

## Whether locomotion targets are enabled.
var use_locomotion_targets: bool = false

#endregion

#region Agent properties

## Inverse mass per agent.
var agent_inv_mass: PackedFloat32Array = []

## Individual radii.
var agent_radii: PackedFloat32Array = []

#endregion


var click_location: Vector2 = Vector2.ZERO
