layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Position {
    vec2 data[];
} agent_pos;

layout(set = 0, binding = 1, std430) restrict buffer Velocity {
    vec2 data[];
} agent_vel;

layout(set = 0, binding = 2, std430) restrict buffer PreferredVelocity {
    vec2 data[];
} agent_pref_vel;

layout(set = 0, binding = 3, std430) restrict buffer BaseVelocity {
    float data[];
} agent_base_vel;

// z index functions as a counter
layout(set = 0, binding = 4, std430) restrict buffer DeltaCorrections {
    vec4 data[];
} delta_corrections;

layout (set = 0, binding = 5, std430) restrict buffer LocomotionTarget {
    vec2 data[];
} locomotion_targets;

layout (set = 0, binding = 6, std430) restrict buffer LocomotionIndex {
    int data[];
} locomotion_indices;

// the locomotion target that this box points to once an agent steps inside
// for this to work, the indices of the locomotion target must match the index of the box
// if an agent is going for locomotion_targets.data[0], then it will ONLY check if it is inside retargeting_boxes.data[0]
layout (set = 0, binding = 7, std430) restrict buffer RetargetingLocomotionIndices {
    int data[];
} retargeting_locomotion_indices;

// When stepping inside a box of a certain index, check that box's index in this array to determine where that agent should go next
// e.g. [1, 2, 2] means "When reached box 0, go to box 1; When reached box 1, go to box 2; When reached box 2, go to box 2"
layout (set = 0, binding = 8, std430) restrict buffer RetargetingBox {
    vec4 data[];
} retargeting_boxes;

// If "true" then this agent is close enough to the currently selected agent (and in its spatial hash) for showing a different color
layout(set = 0, binding = 9, std430) restrict buffer Tracked {
    float data[];
} agent_tracked;

layout(set = 0, binding = 10, std430) restrict buffer Walls {
    vec4 data[]; // x and y are positions, z and w are size
} walls;

//  Stores information used in the debugging process.
layout(set = 0, binding = 11, std430) restrict buffer DebuggingData {
    int tracked_idx; // Stores the idx of an agent being "tracked" by clicking on it. As it's a float this will only be accurate up until 16,777,216 which should be fine
    float padding; // unused as of yet
    float padding_2; // unused as of yet
    float padding_3; // unused as of yet
} debugging_data;

layout (set = 0, binding = 12, std430) restrict buffer IntParams {
    int agent_count; // 0
    int stage; // 4
    int use_spatial_hash; // 8
    int use_locomotion_targets; // 12
    int constraint_type; // 0
    int wall_count; // 4
    int iteration_count; // 8
    int scenario; // 12
} int_params;

// Parameters that are exposed/decided on the CPU-side. Stores data typically not expected to be changed once it reaches the GPU.
layout(set = 0, binding = 13, std430) restrict buffer FloatParams {
    float image_size; // 0 (Counting byte alignment)
    float world_width; // 4
    float world_height; // 8
    float radius; // 12
    float radius_squared; // 0 
    float delta; // 4
    float click_x; // 8
    float click_y; // 12
    float neighbour_radius; // 0
    float padding; // 4
    float padding_2; // 8
    float padding_3; // 12
} float_params;

layout(set = 1, binding = 0, std430) restrict buffer HashParams {
    int hash_size;
    int hash_x;
    int hash_y;
    int hash_count;
} hash_params;

// Stores which space each agent is in
layout(set = 1, binding = 1, std430) restrict buffer Hash {
    int data[];
} hash;

// Array number of agents in each hash (i.e. if 2 agents in hash 5, then data[5] == 2)
layout(set = 1, binding = 2, std430) restrict buffer HashCount {
    int data[];
} hash_sum;

// The cumulative agents stored in each hash up until this one
layout(set = 1, binding = 3, std430) restrict buffer ReindexHashCount {
    int data[];
} hash_prefix_sum;

// As above, but with every element shifted one to the right
layout(set = 1, binding = 4, std430) restrict buffer ReindexHash {
    int data[];
} hash_index_tracker;

layout(set = 1, binding = 5, std430) restrict buffer ReindexHashPositions {
    int data[];
} hash_reindex;

// The textures here are each used to pass the image back to the engine, as passing the shader data directly to a texture keeps everything
// on the GPU without having to pass it back over to CPU memory

// Stores position and velocity
layout(rgba32f, set = 2, binding = 0) uniform image2D agent_data;

// Stores data used for rendering debug data such as viewing which agents are colliding with others
// r - "This agent is being tracked" flag
// g - "In range of currently tracked" flag
// b - 
// a - 
layout(rgba32f, set = 3, binding = 0) uniform image2D agent_data_2;



ivec2 one_to_two(int index, int grid_width) {
    int row = int(index / grid_width);
    int col = int(mod(index, grid_width));
    return ivec2(col,row);
}

int two_to_one(vec2 index, int grid_width) {
    int row = int(index.y);
    int col = int(index.x);
    return row * grid_width + col;
}