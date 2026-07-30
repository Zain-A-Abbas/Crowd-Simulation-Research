extends RefCounted
class_name SimulationSaver

func save_red_black(file_location: String):
	var output_location: String = file_location.replace(".sav", ".txt")
	var input_file: FileAccess = FileAccess.open(file_location, FileAccess.READ)
	var output_file: FileAccess = FileAccess.open(output_location, FileAccess.WRITE)
	
	var frame: int = 1
	var current_data: PackedFloat32Array = []
	while (input_file.get_position() < input_file.get_length()):
		current_data = input_file.get_var()
		output_file.store_line("f%d:"%frame)
		
		var curr_index: int = 0
		for entry in current_data.size() / 4:
			output_file.store_line("%f, %f" % [current_data[curr_index], current_data[curr_index + 1]])
			curr_index += 4
		frame += 1
	
	input_file.close()
	output_file.close()
	print("Simulation saved to " + output_location)
