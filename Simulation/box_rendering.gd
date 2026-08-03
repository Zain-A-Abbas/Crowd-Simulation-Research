class_name BoxRendering
extends Node2D

## Renders collision walls and locomotion boxes.

var walls: Array[Vector4] = []
var retargeting_boxes: Array[Vector4] = []

func initialize_box_rendering(config_state: ConfigState, simulation_state: SimulationState):
	walls.clear()
	retargeting_boxes.clear()
	for wall in config_state.walls:
		walls.append(Vector4(wall[0], wall[1], wall[2], wall[3]))
	for box in simulation_state.retargeting_boxes:
		retargeting_boxes.append(box)

func _draw() -> void:
	for n in walls.size():
		draw_rect(
			Rect2(walls[n].x, walls[n].y, walls[n].z, walls[n].w),
			Color.BLACK,
		)
	for n in retargeting_boxes.size():
		draw_rect(
			Rect2(retargeting_boxes[n].x, retargeting_boxes[n].y, retargeting_boxes[n].z, retargeting_boxes[n].w),
			Color(0.0, 0.0, 1.0, 0.2),
		)
	
