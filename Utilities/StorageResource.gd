extends RefCounted
class_name StorageResource

## A class that is used to cut down on boilerplate for creating abstractions of
## an individual binding in a descriptor set.

static var rendering_device: RenderingDevice = RenderingServer.get_rendering_device()

var buffer: RID
var uniform: RDUniform
var binding: int
## Used for StorageResource's that contain UNIFORM_TYPE_IMAGE
var texture_rd: Texture2DRD

static func create_packed_array_uniform(initial_value, _binding: int, type: RenderingDevice.UniformType = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER) -> StorageResource:
	var new_resource: StorageResource = StorageResource.new()
	new_resource.buffer = generate_packed_array_buffer(initial_value)
	new_resource.uniform = generate_compute_uniform(new_resource.buffer, type, _binding)
	new_resource.binding = _binding
	return new_resource

## Creates bindings that contain nothing but a packed int array of a certain
## size with no expectations of data filled out from the start 
static func create_int_array_uniform(size: int, _binding: int, type: RenderingDevice.UniformType = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER) -> StorageResource:
	var data: PackedInt32Array = PackedInt32Array()
	data.resize(size)
	return create_packed_array_uniform(data, _binding, type)

static func create_image_uniform(_texture_rd: Texture2DRD, texture_size: int, _binding: int) -> StorageResource: # texture_size assumes square image
	# Prepares the image data to bind it to the GPU
	var texture_format: RDTextureFormat = RDTextureFormat.new()
	texture_format.width = texture_size
	texture_format.height = texture_size
	
	# Can be changed to a 64-bit format if the extra precision is ever needed.
	texture_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT 
	texture_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var new_resource: StorageResource = StorageResource.new()
	var texture_view: RDTextureView = RDTextureView.new()
	new_resource.buffer = rendering_device.texture_create(texture_format, texture_view, [])
	new_resource.texture_rd = _texture_rd
	new_resource.texture_rd.texture_rd_rid = new_resource.buffer
	new_resource.uniform = generate_compute_uniform(new_resource.buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, _binding)
	return new_resource

## Creates uniforms for data that is not just a contiguous array, mainly int_params and float_params
static func create_params_uniform(data: PackedByteArray, _binding: int) -> StorageResource:
	var int_param_resource: StorageResource = StorageResource.new()
	int_param_resource.buffer = rendering_device.uniform_buffer_create(data.size(), data)
	int_param_resource.uniform = generate_compute_uniform(int_param_resource.buffer, RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, _binding)
	return int_param_resource

static func generate_packed_array_buffer(data) -> RID:
	var data_bytes: PackedByteArray = data.to_byte_array()
	var data_buffer: RID = rendering_device.storage_buffer_create(data_bytes.size(), data_bytes)
	return data_buffer

static func generate_int_buffer(size: int) -> RID:
	var data: PackedInt32Array = []
	data.resize(size)
	var data_buffer_bytes = data.to_byte_array()
	var data_buffer = rendering_device.storage_buffer_create(data_buffer_bytes.size(), data_buffer_bytes)
	return data_buffer

static func generate_compute_uniform(_buffer: RID, type: RenderingDevice.UniformType, _binding: int) -> RDUniform:
	var new_uniform: RDUniform = RDUniform.new()
	new_uniform.uniform_type = type
	new_uniform.binding = _binding
	new_uniform.add_id(_buffer)
	return new_uniform
