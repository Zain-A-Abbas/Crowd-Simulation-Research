extends Node2D
class_name HashViewer

var world_size: Vector2 = Vector2.ZERO
var h_hashes: int = 0
var v_hashes: int = 0

func _draw() -> void:
	if h_hashes > 0 || v_hashes > 0:
		var rect_size: Vector2 = world_size / Vector2(h_hashes, v_hashes)
		for h in h_hashes:
			for v in v_hashes:
				var hash_rect: Rect2 = Rect2(
					rect_size * Vector2(h, v),
					rect_size
				)
				draw_rect(hash_rect, Color(0.4, 0.8, 0.9), false, 1.0)
	
	
	var world_rect: Rect2 = Rect2(
		Vector2.ZERO,
		world_size
	)
	draw_rect(world_rect, Color.WEB_GRAY, false, 4.0)
	
