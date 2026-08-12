extends Camera2D

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_pressed():
			if event.keycode == KEY_Z:
				zoom_in()
			elif event.keycode == KEY_X && zoom - Vector2(0.1, 0.1) > Vector2(0.01, 0.01):
				zoom_out()
	
	if event is InputEventMouseButton:
		if event.button_index == 4:
			zoom_in(0.05)
		elif event.button_index == 5 && zoom - Vector2(0.1, 0.1) > Vector2(0.01, 0.01):
			zoom_out(0.05)
	if event is InputEventMouseMotion:
		if event.pressure:
			offset -= event.relative / zoom

func zoom_in(amount: float = 0.1):
	zoom += Vector2(amount, amount)
func zoom_out(amount: float = 0.1):
	zoom -= Vector2(amount, amount)
