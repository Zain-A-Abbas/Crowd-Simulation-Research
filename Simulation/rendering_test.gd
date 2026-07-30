extends Node2D

var positions: PackedVector2Array = []

func init(agent_count: int):
	positions.resize(agent_count)

func set_agents(pos: PackedFloat32Array):
	var i: int = 0
	while i < positions.size():
		positions[i] = Vector2(pos[i], pos[i+1])
		i += 2

func _process(delta: float) -> void:
	pass
	#queue_redraw()
