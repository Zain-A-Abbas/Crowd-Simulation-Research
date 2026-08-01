extends RefCounted
class_name DescriptorSetResource

## A class that cuts down on boilerplate to bind data to a descriptor set.
## 

var resources: Array[StorageResource] = []
## Used when certain buffers need to be accessed/replaced on run-time, mainly
## the int_params and float_params bindings
var named_resources: Dictionary[String, StorageResource] = {}

func add_resource(new_resource: StorageResource, key: String = ""):
	resources.append(new_resource)
	if key != "":
		named_resources[key] = new_resource

func replace_resource(key: String, new_resource: StorageResource):
	assert(named_resources.has(key))
	var old_resource: StorageResource = named_resources[key]
	resources[resources.find(old_resource)] = new_resource
	named_resources[key] = new_resource
	RenderingServer.get_rendering_device().free_rid(old_resource.buffer)

func get_uniforms() -> Array[RDUniform]:
	var uniforms: Array[RDUniform] = []
	for resource in resources:
		uniforms.append(resource.uniform)
	return uniforms

func freeBindings():
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	for resource in resources:
		rd.free_rid(resource.buffer)
