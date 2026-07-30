class_name BoxRendering
extends Node2D

var walls: Array[Vector4] = []
var retargeting_boxes: Array[Vector4] = []

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
	
