layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

/* DESCRIPTOR SET 1 */
/* Contains data relating to agents, their movement/physics/collision, and their locomotion */

// Basic universal agent data
layout(set = 0, binding = 0, std430) restrict buffer AgentData {
    vec2 data[];
} agent_pos;

layout(set = 0, binding = 1, std430) restrict buffer AgentBaseData {
    vec2 data[];
} agent_prev_pos;

layout(set = 0, binding = 2, std430) restrict buffer AgentBaseData2 {
    vec2 data[];
} agent_vel;

layout(set = 0, binding = 3, std430) restrict buffer AgentBaseData3 {
    vec2 data[];
} agent_pref_vel;

// Magnitude of each agent's velocity
layout(set = 0, binding = 4, std430) restrict buffer BaseVelocity {
    float data[];
} agent_base_vel;

// The amount the agent has to be moved to correct its position
// x/y correspond to position
// z is the number of corrections applied in the current iteration (used to average the corrections)
layout(set = 0, binding = 5, std430) restrict buffer DeltaCorrections {
    vec4 data[];
} delta_corrections;

// The positions of the targets that the agents are trying to reach
layout (set = 0, binding = 6, std430) restrict buffer LocomotionTarget {
    vec2 data[];
} locomotion_targets;

// Points to what specific locomotion target an agent is trying to reach
// e.g. locomotion_indices.data[5] = 2 means agent 5 is trying to reach locomotion_targets.data[2]
layout (set = 0, binding = 7, std430) restrict buffer LocomotionIndex {
    int data[];
} locomotion_indices;

// the locomotion target that this retargeting_box points to once an agent steps inside
// for this to work, the indices of the locomotion target must match the index of the box
// e.g. if an agent is going for locomotion_targets.data[0], then it will ONLY check if it is inside that locomotion target (in that case retargeting_boxes.data[0])
layout (set = 0, binding = 8, std430) restrict buffer RetargetingLocomotionIndices {
    int data[];
} retargeting_locomotion_indices;

// When stepping inside a box of a certain index, check that box's index in this array to determine where that agent should go next
// e.g. [1, 2, 2] means "When reached box 0, go to box 1; When reached box 1, go to box 2; When reached box 2, go to box 2"
layout (set = 0, binding = 9, std430) restrict buffer RetargetingBox {
    vec4 data[];
} retargeting_boxes;

// If "true" then this agent is close enough to the currently selected agent (and in its spatial hash) for showing a different color
layout(set = 0, binding = 10, std430) restrict buffer Tracked {
    float data[];
} agent_tracked;

// Physical walls that the agents cannot pass through. x and y are the position of the wall, z and w are the size of the wall.
layout(set = 0, binding = 11, std430) restrict buffer Walls {
    vec4 data[];
} walls;


/* DESCRIPTOR SET 1 */
/* Contains data relating to the spatial hash */
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

/* DESCRIPTOR SET 2 */
/* Contains the textures which are written to to render on-screen and save to disk */

// The textures here are each used to pass the image back to the engine, as passing the shader data directly to a texture keeps everything
// on the GPU without having to pass it back over to regular memory

// Stores position and velocity
// r - x position
// g - y position
// b - x velocity
// a - y velocity
layout(rgba32f, set = 2, binding = 0) uniform image2D agent_data;

// Stores data used for rendering debug data such as viewing which agents are colliding with others
// r - "This agent is being tracked" flag
// g - "In range of currently tracked" flag
// b - unused
// a - unused
layout(rgba32f, set = 2, binding = 1) uniform image2D agent_data_2;


/* DESCRIPTOR SET 3 */
/* Contains parameters shared between all agents, and debugging data */

layout (set = 3, binding = 0, std140) uniform IntParams {
    int agent_count; // 0
    int stage; // 4
    int use_spatial_hash; // 8
    int use_locomotion_targets; // 12
    int constraint_type; // 0
    int wall_count; // 4
    int iteration_count; // 8
    int scenario; // 12
} int_params;

layout(set = 3, binding = 1, std140) uniform FloatParams {
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

//  Stores information used in the debugging process.
layout(set = 3, binding = 2, std430) restrict buffer DebuggingData {
    int tracked_idx; // Stores the idx of an agent being "tracked" by clicking on it. As it's a float this will only be accurate up until 16,777,216 which should be fine
    float padding; // unused as of yet
    float padding_2; // unused as of yet
    float padding_3; // unused as of yet
} debugging_data;



// Converts a 1D index to a 2D index based on the grid width
ivec2 one_to_two(int index, int grid_width) {
    int row = int(index / grid_width);
    int col = int(mod(index, grid_width));
    return ivec2(col,row);
}

// Converts a 2D index to a 1D index based on the grid width
int two_to_one(ivec2 index, int grid_width) {
    return index.y * grid_width + index.x;
}