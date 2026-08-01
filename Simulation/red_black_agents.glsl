#[compute]
#version 450

#include "shared_data.glsl"

const float INV_MASS = 0.01625;
const float EPSILON = 0.0001;
const float C_TAO_MAX = 20.0;
const float C_TAO_0 = 20.0;
const float dv_i = 1.0;
const float C_LONG_RANGE_STIFF = 0.02;
const float MAX_DELTA = 0.9;
const float MAX_SPEED = 128.0;
const float ksi = 0.1;

float random(uvec3 st) {
    return fract(sin(dot(st.xy ,vec2(12.9898,78.233))) * 43758.5453123);
}

void highlightAgent(int i, int j) {
    if (j == debugging_data.tracked_idx) {
        if (distance(agent_pos.data[i], agent_pos.data[j]) < float_params.neighbour_radius) {
            agent_tracked.data[i] = 1.0;
        }   
    }
}

vec2 clamp2D(float vx, float vy, float maxValue) {
  const float lengthV = sqrt(vx * vx + vy * vy);
  if (lengthV > maxValue) {
    const float mult = (maxValue / lengthV);
    vx *= mult;
    
    vy *= mult;
  }
  return vec2(vx, vy);
}

vec4 wallConstraint(int agentIdx, int wallIdx) {
    vec2 ip = agent_pos.data[agentIdx];
    vec4 wall = walls.data[wallIdx];

    float left = wall.x;
    float right = wall.x + wall.z;
    float top = wall.y;
    float bottom = wall.y + wall.w;


    // edges of the agent
    float right_edge = ip.x + float_params.radius;
    float left_edge = ip.x - float_params.radius;
    float top_edge = ip.y - float_params.radius;
    float bottom_edge = ip.y + float_params.radius;

    if ((right_edge > left && left_edge < right) && (bottom_edge > top && top_edge < bottom)) {
        float dxLeft   = right_edge - left;
        float dxRight  = right - left_edge;
        float dyBottom = bottom - top_edge;
        float dyTop    = bottom_edge - top;

        // Find smallest penetration axis
        float minX = min(dxLeft, dxRight);
        float minY = min(dyBottom, dyTop);

        vec2 push_vector;
        if (minX < minY) {
            float push = (dxLeft < dxRight) ? -dxLeft : dxRight;
            push_vector = vec2(push, 0.0);
        } else {
            float push = (dyTop < dyBottom) ? -dyTop : dyBottom;
            push_vector = vec2(0.0, push);
        }

        return vec4(push_vector, 1.0, 1.0);

    }

    return vec4(0.0);
}

void shortRangeConstraint(int i, int j) {
    vec2 ip = agent_pos.data[i];
    vec2 jp = agent_pos.data[j];
    const float dist = distance(ip, jp);
    const float overlap = dist - 2*float_params.radius;
    if (overlap < 0.0){
        vec2 grad_i = ip - jp;
        const vec2 grad_i_v = -grad_i / dist;
    
        delta_corrections.data[i].xy += overlap * grad_i_v;
        delta_corrections.data[i].z += 2.0;
        delta_corrections.data[j].xy += -overlap * grad_i_v;
        delta_corrections.data[j].z += 2.0;
    }
}

void longRangeConstraint(int i, int j) {

    
    // ip and jp are position taking into account velocity
    // i/j_start_pos are position at start of the current iteration (current frame of execution if only 1 iteration)
    vec2 ip = agent_pos.data[i];
    vec2 jp = agent_pos.data[j];

    vec2 i_start_pos = agent_prev_pos.data[i];
    vec2 j_start_pos = agent_prev_pos.data[j];

    const float dist = distance(ip, jp);
    
    const float radius_init = float_params.radius * 2.0;
    
    float radius_sq = radius_init > dist ? (radius_init - dist) * (radius_init - dist) : radius_init * radius_init;

    const float v_x = (ip.x - i_start_pos.x) / float_params.delta - (jp.x - j_start_pos.x) / float_params.delta;
    const float v_y = (ip.y - i_start_pos.y) / float_params.delta - (jp.y - j_start_pos.y) / float_params.delta;
    //const float v_d = v_x

    const float x0 = i_start_pos.x - j_start_pos.x; 
    const float y0 = i_start_pos.y - j_start_pos.y; 
    const float v_sq = v_x * v_x + v_y * v_y;
    const float x0_sq = x0 * x0;
    const float y0_sq = y0 * y0;
    const float x_sq = x0_sq + y0_sq; 
    const float b = -v_x * x0 - v_y * y0;   // b = -1 * v_.dot(x0_).  Have to check this. 
    const float c = x_sq - radius_sq;
    const float d_sq = b * b - v_sq * c;
    const float d = sqrt(d_sq);
    const float tao = (b - d) / v_sq;
    if (d_sq > 0.0 && abs(v_sq) > EPSILON && tao > 0 && tao < C_TAO_MAX){
        
        const float clamp_tao = exp(-tao * tao / C_TAO_0);
        const float c_tao = clamp_tao;
        const float tao_sq = c_tao * c_tao;

        const float grad_x_i = 2 * c_tao * ((dv_i / v_sq) * ((-2.0 * v_x * tao) - (x0 + (v_y * x0 * y0 + v_x * (radius_sq - y0_sq)) / d)));
        const float grad_y_i = 2 * c_tao * ((dv_i / v_sq) * ((-2.0 * v_y * tao) - (y0 + (v_x * x0 * y0 + v_y * (radius_sq - x0_sq)) / d)));


        const float stiff = C_LONG_RANGE_STIFF * exp(-tao_sq / C_TAO_0);    //changed
        const float s =  stiff * tao_sq / (INV_MASS * (grad_y_i * grad_y_i + grad_x_i * grad_x_i) * 2);     //changed


        //float lengthV = sqrt(s * INV_MASS * grad_x_i * s * INV_MASS * grad_x_i 
          //                  + s * INV_MASS * grad_y_i * s * INV_MASS * grad_y_i);

        vec2 delta_correction_i = clamp2D(
            s * INV_MASS * grad_x_i,
            s * INV_MASS * grad_y_i,
            MAX_DELTA
            );           

        vec2 delta_correction_j = clamp2D(
            s * INV_MASS * -grad_x_i,
            s * INV_MASS * -grad_y_i,
            MAX_DELTA
            );                  


        delta_corrections.data[i].xy += delta_correction_i.xy * 2.0;
        delta_corrections.data[j].xy += delta_correction_j.xy * 2.0;
        delta_corrections.data[i].z += 2.0;
        delta_corrections.data[j].z += 2.0;

    }
}

vec2 rotate_velocity(int idx) {
    vec2 curr_pos = agent_pos.data[idx];
    vec2 pref_vel = agent_pref_vel.data[idx];
    vec2 loc_targ = locomotion_targets.data[locomotion_indices.data[idx]];

    vec2 direction = normalize(loc_targ - curr_pos);
    float angle = acos(clamp(dot(direction, normalize(pref_vel)), -1.0, 1.0));
    
    mat2 rot_mat = mat2(
        cos(angle), sin(angle),
        -sin(angle), cos(angle)
    ); // The sines are flipped here because GLSL defines matrices in column-major order 

    return pref_vel * rot_mat;
}

void wallCorrections(int idx) {

    vec4 wall_corrections = vec4(0.0); 
    for (int j = 0; j < int_params.wall_count; j++) {
        wall_corrections += wallConstraint(idx, j);
    }

    agent_pos.data[idx] += wall_corrections.xy;

}

void correctionsStage(int idx) {

    agent_tracked.data[idx] = 0.0;

    delta_corrections.data[idx] = vec4(0.0);


    for (int iter_count = 0; iter_count < int_params.iteration_count; iter_count++) {

        if (int_params.use_spatial_hash == 1) {
            int agent_hash = hash.data[idx];
            ivec2 hash_location = one_to_two(agent_hash, hash_params.hash_x);

            ivec2 current_hash = hash_location;
            
            for (int y_offset = -1; y_offset < 2; y_offset++) {
                current_hash.y = hash_location.y + y_offset;
                if (current_hash.y < 0 || current_hash.y > hash_params.hash_y) continue;
                
                for (int x_offset = -1; x_offset < 2; x_offset++) {
                    current_hash.x = hash_location.x + x_offset;
                    if (current_hash.x < 0 || current_hash.x > hash_params.hash_x) continue;

                    // Gets the 1D id of the bin
                    int hash_index = two_to_one(current_hash, hash_params.hash_x);

                        if (hash_index - 1 == -1) {continue;}
                    for (int i = hash_prefix_sum.data[hash_index - 1]; i < hash_prefix_sum.data[hash_index]; i++) {

                        int other_agent = hash_reindex.data[i];
                        if (other_agent == idx) continue;


                        highlightAgent(idx, other_agent);

                        if (idx < other_agent) {
                            if (int_params.constraint_type == 1) {
                                shortRangeConstraint(idx, other_agent);
                            } else if (int_params.constraint_type == 0) {
                                longRangeConstraint(idx, other_agent);
                            }
                        }

                    } 
                }
            }
            

        } else {
            for (int j = idx; j < int_params.agent_count; j++) {
                if (j == idx) {continue;}
                highlightAgent(idx, j);
                if (idx < j) {
                    if (int_params.constraint_type == 1) {
                        shortRangeConstraint(idx, j);
                    }
                    else if (int_params.constraint_type == 0) {
                        longRangeConstraint(idx, j);
                    }
                }
            }
        }


    }

}

void applyDeltaStage(int idx) {
    if (delta_corrections.data[idx].z > 0.0) {
        agent_pos.data[idx] += (delta_corrections.data[idx].xy / delta_corrections.data[idx].z);
        delta_corrections.data[idx] = vec4(0.0);
    }
}

void moveStage(int idx) {


    //agent_vel.data[idx] = clamp2D(agent_vel.data[idx].x, agent_vel.data[idx].y, MAX_SPEED);
    
    //agent_pos.data[idx] += agent_vel.data[idx] * float_params.delta;

    
    // idx + params.agent_count is the old position
    agent_vel.data[idx] = (agent_pos.data[idx] - agent_prev_pos.data[idx]) / float_params.delta; // set the velocity to the actual position moved

    agent_vel.data[idx] = clamp2D(agent_vel.data[idx].x, agent_vel.data[idx].y, MAX_SPEED);
    agent_vel.data[idx] = ksi * agent_pref_vel.data[idx]  + (1.0-ksi) * agent_vel.data[idx]; // Blending current velocity with preferred velocity

    if (agent_pos.data[idx].x > float_params.world_width) {agent_pos.data[idx].x -= float_params.world_width;}
    if (agent_pos.data[idx].y > float_params.world_height) {agent_pos.data[idx].y -= float_params.world_height;}
    if (agent_pos.data[idx].x < 0) {agent_pos.data[idx].x += float_params.world_width;}
    if (agent_pos.data[idx].y < 0) {agent_pos.data[idx].y += float_params.world_height;}

    agent_prev_pos.data[idx] = agent_pos.data[idx]; // Updates the "start of frame" positions for the next frame


    if (int_params.use_spatial_hash > 0.0) {
        hash.data[idx] = int(agent_pos.data[idx].x / hash_params.hash_size) + int(agent_pos.data[idx].y / hash_params.hash_size) * hash_params.hash_x;
    }

    if (int_params.use_locomotion_targets > 0.0) {
        if ((locomotion_indices.data[idx] == retargeting_locomotion_indices.data[locomotion_indices.data[idx]])
        && dot(agent_pos.data[idx] - locomotion_targets.data[idx], agent_pos.data[idx] - locomotion_targets.data[idx]) < 4.0) 
        {
            agent_pref_vel.data[idx] = vec2(0.0);
            agent_vel.data[idx] = vec2(0.0);
        } else {    
            agent_pref_vel.data[idx] = rotate_velocity(idx);
        }

        if (agent_pos.data[idx].x > retargeting_boxes.data[locomotion_indices.data[idx]].x
        && agent_pos.data[idx].x < retargeting_boxes.data[locomotion_indices.data[idx]].x + retargeting_boxes.data[locomotion_indices.data[idx]].z
        && agent_pos.data[idx].y > retargeting_boxes.data[locomotion_indices.data[idx]].y
        && agent_pos.data[idx].y < retargeting_boxes.data[locomotion_indices.data[idx]].y + retargeting_boxes.data[locomotion_indices.data[idx]].w)
        {
            locomotion_indices.data[idx] = retargeting_locomotion_indices.data[locomotion_indices.data[idx]];
        }
    }

    if (int_params.scenario == 7) {
        const float tilt = 1.3;
        vec2 direction = normalize(agent_pos.data[idx] - vec2(1000.0));
        direction = normalize(mix(direction, vec2(-direction.y, direction.x), tilt));
        agent_pref_vel.data[idx] = direction * agent_base_vel.data[idx];
    }


    if (length(vec2(float_params.click_x, float_params.click_y)) > 0.01) {
        if (distance(vec2(float_params.click_x, float_params.click_y), agent_pos.data[idx]) < float_params.radius) {
            debugging_data.tracked_idx = idx;
        }
    }

    // Turns this agent's index into x/y to find the corresponding pixel on the texture
    ivec2 pixel_coord = ivec2(
        int(mod(idx, float_params.image_size)),
        int(idx / float_params.image_size)
    );

    imageStore(agent_data, pixel_coord, vec4(agent_pos.data[idx].x, agent_pos.data[idx].y, agent_vel.data[idx].x, agent_vel.data[idx].y));
    imageStore(agent_data_2, pixel_coord, vec4(float(debugging_data.tracked_idx == idx), agent_tracked.data[idx], 0.0, 0.0));
    
}

void main() {
    int idx = int(gl_GlobalInvocationID.x);
    if (idx >= int_params.agent_count) {return;}

    if (int_params.stage == 0) {
        wallCorrections(idx);
        agent_pos.data[idx] += agent_vel.data[idx] * float_params.delta;
    } else if (int_params.stage == 1) {
        correctionsStage(idx);
    } else if (int_params.stage == 2) {
        applyDeltaStage(idx);
    }
    else if (int_params.stage == 3) {
        moveStage(idx);
    }

}
