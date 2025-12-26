//! Zylix Advanced 3D Skeletal Animation System
//!
//! Provides comprehensive skeletal animation for 3D characters and objects including:
//! - Bone hierarchies with hierarchical transforms
//! - Vertex skinning with bone weights
//! - Animation clips and playback
//! - Animation blending and layering
//! - Inverse Kinematics (IK) solvers
//! - Morph targets / blend shapes
//! - Root motion extraction

const std = @import("std");
const types = @import("types.zig");

const Vec3 = types.Vec3;
const Vec4 = types.Vec4;
const Quaternion = types.Quaternion;
const Mat4 = types.Mat4;
const Transform = types.Transform;

// ============================================================================
// Bone & Skeleton
// ============================================================================

/// A single bone in a skeleton hierarchy
pub const Bone = struct {
    name: []const u8,
    index: u16,
    parent_index: ?u16,

    /// Local bind pose (relative to parent)
    local_bind_pose: Transform,

    /// Inverse bind pose matrix (world space)
    inverse_bind_matrix: Mat4,

    /// Current local transform (animated)
    local_transform: Transform,

    /// Cached world transform
    world_transform: Mat4,

    /// Child bone indices
    children: std.ArrayList(u16),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, index: u16, parent: ?u16) Bone {
        return .{
            .name = name,
            .index = index,
            .parent_index = parent,
            .local_bind_pose = Transform.identity(),
            .inverse_bind_matrix = Mat4.identity(),
            .local_transform = Transform.identity(),
            .world_transform = Mat4.identity(),
            .children = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Bone) void {
        self.children.deinit(self.allocator);
    }

    pub fn addChild(self: *Bone, child_index: u16) !void {
        try self.children.append(self.allocator, child_index);
    }
};

/// Complete skeleton definition
pub const Skeleton = struct {
    name: []const u8,
    bones: std.ArrayList(Bone),
    root_bone_index: u16,

    /// Bone name to index lookup
    bone_map: std.StringHashMap(u16),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) Skeleton {
        return .{
            .name = name,
            .bones = .{},
            .root_bone_index = 0,
            .bone_map = std.StringHashMap(u16).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Skeleton) void {
        for (self.bones.items) |*bone| {
            bone.deinit();
        }
        self.bones.deinit(self.allocator);
        self.bone_map.deinit();
    }

    /// Add a bone to the skeleton
    pub fn addBone(self: *Skeleton, name: []const u8, parent: ?u16) !u16 {
        const index: u16 = @intCast(self.bones.items.len);
        const bone = Bone.init(self.allocator, name, index, parent);

        // Add as child to parent
        if (parent) |p_idx| {
            try self.bones.items[p_idx].addChild(index);
        }

        try self.bones.append(self.allocator, bone);
        try self.bone_map.put(name, index);

        return index;
    }

    /// Get bone by name
    pub fn getBone(self: *Skeleton, name: []const u8) ?*Bone {
        if (self.bone_map.get(name)) |index| {
            return &self.bones.items[index];
        }
        return null;
    }

    /// Get bone by index
    pub fn getBoneByIndex(self: *Skeleton, index: u16) ?*Bone {
        if (index < self.bones.items.len) {
            return &self.bones.items[index];
        }
        return null;
    }

    /// Compute all bone world transforms from local transforms
    pub fn updateWorldTransforms(self: *Skeleton) void {
        // Process bones in order (parent before children)
        for (self.bones.items, 0..) |*bone, idx| {
            const local_mat = bone.local_transform.toMatrix();

            if (bone.parent_index) |parent_idx| {
                const parent_world = self.bones.items[parent_idx].world_transform;
                bone.world_transform = parent_world.multiply(local_mat);
            } else {
                bone.world_transform = local_mat;
            }
            _ = idx;
        }
    }

    /// Compute skinning matrices (world * inverse_bind)
    pub fn computeSkinningMatrices(self: *Skeleton, output: []Mat4) void {
        const count = @min(self.bones.items.len, output.len);
        for (0..count) |idx| {
            const bone = &self.bones.items[idx];
            output[idx] = bone.world_transform.multiply(bone.inverse_bind_matrix);
        }
    }

    /// Reset all bones to bind pose
    pub fn resetToBindPose(self: *Skeleton) void {
        for (self.bones.items) |*bone| {
            bone.local_transform = bone.local_bind_pose;
        }
        self.updateWorldTransforms();
    }

    /// Get bone count
    pub fn boneCount(self: *const Skeleton) usize {
        return self.bones.items.len;
    }
};

// ============================================================================
// Skinning
// ============================================================================

/// Maximum bones influencing a single vertex
pub const MAX_BONE_INFLUENCES = 4;

/// Bone weight data for a single vertex
pub const BoneWeights = struct {
    bone_indices: [MAX_BONE_INFLUENCES]u16 = .{ 0, 0, 0, 0 },
    weights: [MAX_BONE_INFLUENCES]f32 = .{ 0, 0, 0, 0 },

    /// Normalize weights to sum to 1.0
    pub fn normalize(self: *BoneWeights) void {
        var sum: f32 = 0;
        for (self.weights) |w| {
            sum += w;
        }
        if (sum > 0.0001) {
            for (&self.weights) |*w| {
                w.* /= sum;
            }
        }
    }

    /// Add a bone influence
    pub fn addInfluence(self: *BoneWeights, bone_index: u16, weight: f32) void {
        // Find slot with smallest weight
        var min_idx: usize = 0;
        var min_weight = self.weights[0];

        for (1..MAX_BONE_INFLUENCES) |idx| {
            if (self.weights[idx] < min_weight) {
                min_weight = self.weights[idx];
                min_idx = idx;
            }
        }

        // Replace if new weight is larger
        if (weight > min_weight) {
            self.bone_indices[min_idx] = bone_index;
            self.weights[min_idx] = weight;
        }
    }
};

/// Skinned mesh data
pub const SkinnedMesh = struct {
    /// Original vertex positions (bind pose)
    bind_positions: std.ArrayList(Vec3),

    /// Original vertex normals (bind pose)
    bind_normals: std.ArrayList(Vec3),

    /// Bone weights per vertex
    bone_weights: std.ArrayList(BoneWeights),

    /// Output skinned positions
    skinned_positions: std.ArrayList(Vec3),

    /// Output skinned normals
    skinned_normals: std.ArrayList(Vec3),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SkinnedMesh {
        return .{
            .bind_positions = .{},
            .bind_normals = .{},
            .bone_weights = .{},
            .skinned_positions = .{},
            .skinned_normals = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SkinnedMesh) void {
        self.bind_positions.deinit(self.allocator);
        self.bind_normals.deinit(self.allocator);
        self.bone_weights.deinit(self.allocator);
        self.skinned_positions.deinit(self.allocator);
        self.skinned_normals.deinit(self.allocator);
    }

    /// Add a vertex with bone weights
    pub fn addVertex(
        self: *SkinnedMesh,
        position: Vec3,
        normal: Vec3,
        weights: BoneWeights,
    ) !void {
        try self.bind_positions.append(self.allocator, position);
        try self.bind_normals.append(self.allocator, normal);
        try self.bone_weights.append(self.allocator, weights);
        try self.skinned_positions.append(self.allocator, position);
        try self.skinned_normals.append(self.allocator, normal);
    }

    /// Apply skinning using bone matrices
    pub fn applySkinning(self: *SkinnedMesh, bone_matrices: []const Mat4) void {
        for (0..self.bind_positions.items.len) |idx| {
            const bind_pos = self.bind_positions.items[idx];
            const bind_normal = self.bind_normals.items[idx];
            const weights = self.bone_weights.items[idx];

            var skinned_pos = Vec3.zero();
            var skinned_normal = Vec3.zero();

            for (0..MAX_BONE_INFLUENCES) |w_idx| {
                const weight = weights.weights[w_idx];
                if (weight < 0.0001) continue;

                const bone_idx = weights.bone_indices[w_idx];
                if (bone_idx >= bone_matrices.len) continue;

                const mat = bone_matrices[bone_idx];

                // Transform position
                const transformed_pos = mat.transformPoint(bind_pos);
                skinned_pos = skinned_pos.add(transformed_pos.scale(weight));

                // Transform normal (using upper 3x3)
                const transformed_normal = mat.transformDirection(bind_normal);
                skinned_normal = skinned_normal.add(transformed_normal.scale(weight));
            }

            self.skinned_positions.items[idx] = skinned_pos;
            self.skinned_normals.items[idx] = skinned_normal.normalize();
        }
    }

    /// Vertex count
    pub fn vertexCount(self: *const SkinnedMesh) usize {
        return self.bind_positions.items.len;
    }
};

// ============================================================================
// Animation Clips
// ============================================================================

/// Interpolation mode for keyframes
pub const InterpolationMode = enum {
    step,
    linear,
    cubic_spline,
};

/// A keyframe for a bone property
pub const Keyframe = struct {
    time: f32,
    value: KeyframeValue,
    interpolation: InterpolationMode = .linear,

    /// Tangents for cubic spline interpolation
    in_tangent: ?KeyframeValue = null,
    out_tangent: ?KeyframeValue = null,
};

/// Value types for keyframes
pub const KeyframeValue = union(enum) {
    translation: Vec3,
    rotation: Quaternion,
    scale: Vec3,
    weight: f32,
};

/// Animation channel targeting a specific bone property
pub const AnimationChannel = struct {
    bone_index: u16,
    keyframes: std.ArrayList(Keyframe),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, bone_index: u16) AnimationChannel {
        return .{
            .bone_index = bone_index,
            .keyframes = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AnimationChannel) void {
        self.keyframes.deinit(self.allocator);
    }

    /// Add a keyframe
    pub fn addKeyframe(self: *AnimationChannel, keyframe: Keyframe) !void {
        // Insert in time order
        var insert_idx: usize = self.keyframes.items.len;
        for (self.keyframes.items, 0..) |kf, idx| {
            if (kf.time > keyframe.time) {
                insert_idx = idx;
                break;
            }
        }
        try self.keyframes.insert(self.allocator, insert_idx, keyframe);
    }

    /// Sample the channel at a given time
    pub fn sample(self: *const AnimationChannel, time: f32) ?KeyframeValue {
        if (self.keyframes.items.len == 0) return null;

        // Find surrounding keyframes
        var prev_idx: usize = 0;
        var next_idx: usize = 0;

        for (self.keyframes.items, 0..) |kf, idx| {
            if (kf.time <= time) {
                prev_idx = idx;
            }
            if (kf.time >= time) {
                next_idx = idx;
                break;
            }
            next_idx = idx;
        }

        const prev_kf = self.keyframes.items[prev_idx];
        const next_kf = self.keyframes.items[next_idx];

        // Same keyframe or step interpolation
        if (prev_idx == next_idx or prev_kf.interpolation == .step) {
            return prev_kf.value;
        }

        // Calculate interpolation factor
        const duration = next_kf.time - prev_kf.time;
        const t = if (duration > 0.0001) (time - prev_kf.time) / duration else 0;

        // Interpolate based on value type
        return switch (prev_kf.value) {
            .translation => |prev_trans| {
                const next_trans = next_kf.value.translation;
                return .{ .translation = prev_trans.lerp(next_trans, t) };
            },
            .rotation => |prev_rot| {
                const next_rot = next_kf.value.rotation;
                return .{ .rotation = prev_rot.slerp(next_rot, t) };
            },
            .scale => |prev_scale| {
                const next_scale = next_kf.value.scale;
                return .{ .scale = prev_scale.lerp(next_scale, t) };
            },
            .weight => |prev_weight| {
                const next_weight = next_kf.value.weight;
                return .{ .weight = prev_weight + (next_weight - prev_weight) * t };
            },
        };
    }
};

/// A complete animation clip
pub const AnimationClip = struct {
    name: []const u8,
    duration: f32,
    channels: std.ArrayList(AnimationChannel),

    /// Enable root motion extraction
    extract_root_motion: bool = false,
    root_bone_index: u16 = 0,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) AnimationClip {
        return .{
            .name = name,
            .duration = 0,
            .channels = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AnimationClip) void {
        for (self.channels.items) |*channel| {
            channel.deinit();
        }
        self.channels.deinit(self.allocator);
    }

    /// Add an animation channel
    pub fn addChannel(self: *AnimationClip, channel: AnimationChannel) !void {
        try self.channels.append(self.allocator, channel);
    }

    /// Sample all channels at time and apply to skeleton
    pub fn sample(self: *const AnimationClip, time: f32, skeleton: *Skeleton) void {
        const looped_time = @mod(time, self.duration);

        for (self.channels.items) |*channel| {
            if (channel.sample(looped_time)) |value| {
                if (channel.bone_index < skeleton.bones.items.len) {
                    const bone = &skeleton.bones.items[channel.bone_index];
                    switch (value) {
                        .translation => |t| bone.local_transform.position = t,
                        .rotation => |r| bone.local_transform.rotation = r,
                        .scale => |s| bone.local_transform.scale = s,
                        .weight => {},
                    }
                }
            }
        }
    }

    /// Extract root motion delta between two times
    pub fn extractRootMotion(self: *const AnimationClip, from_time: f32, to_time: f32) ?Vec3 {
        if (!self.extract_root_motion) return null;

        // Find root translation channel
        for (self.channels.items) |*channel| {
            if (channel.bone_index == self.root_bone_index) {
                const from_val = channel.sample(from_time);
                const to_val = channel.sample(to_time);

                if (from_val != null and to_val != null) {
                    if (from_val.?.translation != undefined and to_val.?.translation != undefined) {
                        return to_val.?.translation.sub(from_val.?.translation);
                    }
                }
            }
        }
        return null;
    }
};

// ============================================================================
// Animation Blending
// ============================================================================

/// Blend mode for combining animations
pub const BlendMode = enum {
    override,
    additive,
    multiply,
};

/// A single animation layer for blending
pub const AnimationLayer = struct {
    clip: *AnimationClip,
    weight: f32 = 1.0,
    time: f32 = 0,
    speed: f32 = 1.0,
    blend_mode: BlendMode = .override,
    looping: bool = true,

    /// Bone mask (null = affect all bones)
    bone_mask: ?[]const u16 = null,

    /// Update layer time
    pub fn update(self: *AnimationLayer, delta_time: f32) void {
        self.time += delta_time * self.speed;

        if (self.looping) {
            self.time = @mod(self.time, self.clip.duration);
        } else {
            self.time = @min(self.time, self.clip.duration);
        }
    }

    /// Check if bone is affected by this layer
    pub fn affectsBone(self: *const AnimationLayer, bone_index: u16) bool {
        if (self.bone_mask) |mask| {
            for (mask) |idx| {
                if (idx == bone_index) return true;
            }
            return false;
        }
        return true; // No mask = affects all
    }
};

/// Animation blender for combining multiple animation layers
pub const AnimationBlender = struct {
    layers: std.ArrayList(AnimationLayer),

    /// Cached pose for blending
    cached_transforms: std.ArrayList(Transform),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AnimationBlender {
        return .{
            .layers = .{},
            .cached_transforms = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AnimationBlender) void {
        self.layers.deinit(self.allocator);
        self.cached_transforms.deinit(self.allocator);
    }

    /// Add an animation layer
    pub fn addLayer(self: *AnimationBlender, layer: AnimationLayer) !void {
        try self.layers.append(self.allocator, layer);
    }

    /// Remove layer by index
    pub fn removeLayer(self: *AnimationBlender, index: usize) void {
        if (index < self.layers.items.len) {
            _ = self.layers.orderedRemove(index);
        }
    }

    /// Update all layers
    pub fn update(self: *AnimationBlender, delta_time: f32) void {
        for (self.layers.items) |*layer| {
            layer.update(delta_time);
        }
    }

    /// Blend all layers and apply to skeleton
    pub fn applyToSkeleton(self: *AnimationBlender, skeleton: *Skeleton) !void {
        const bone_count = skeleton.bones.items.len;

        // Ensure cached transforms are sized correctly
        while (self.cached_transforms.items.len < bone_count) {
            try self.cached_transforms.append(self.allocator, Transform.identity());
        }

        // Reset to bind pose
        for (0..bone_count) |idx| {
            self.cached_transforms.items[idx] = skeleton.bones.items[idx].local_bind_pose;
        }

        // Blend each layer
        for (self.layers.items) |*layer| {
            if (layer.weight < 0.0001) continue;

            // Sample the clip
            layer.clip.sample(layer.time, skeleton);

            // Blend each affected bone
            for (0..bone_count) |idx| {
                const bone_idx: u16 = @intCast(idx);
                if (!layer.affectsBone(bone_idx)) continue;

                const bone = &skeleton.bones.items[idx];
                const target = bone.local_transform;
                var result = &self.cached_transforms.items[idx];

                switch (layer.blend_mode) {
                    .override => {
                        result.* = result.lerp(target, layer.weight);
                    },
                    .additive => {
                        // Add delta from bind pose
                        const bind = bone.local_bind_pose;
                        const delta_pos = target.position.sub(bind.position);
                        const delta_rot = bind.rotation.inverse().multiply(target.rotation);

                        result.position = result.position.add(delta_pos.scale(layer.weight));
                        result.rotation = result.rotation.slerp(
                            result.rotation.multiply(delta_rot),
                            layer.weight,
                        );
                    },
                    .multiply => {
                        result.scale = Vec3.init(
                            result.scale.x * (1.0 + (target.scale.x - 1.0) * layer.weight),
                            result.scale.y * (1.0 + (target.scale.y - 1.0) * layer.weight),
                            result.scale.z * (1.0 + (target.scale.z - 1.0) * layer.weight),
                        );
                    },
                }
            }
        }

        // Apply blended transforms to skeleton
        for (0..bone_count) |idx| {
            skeleton.bones.items[idx].local_transform = self.cached_transforms.items[idx];
        }

        skeleton.updateWorldTransforms();
    }

    /// Cross-fade between two clips
    pub fn crossFade(
        self: *AnimationBlender,
        from_clip: *AnimationClip,
        to_clip: *AnimationClip,
        fade_duration: f32,
        current_time: f32,
    ) !void {
        // Add outgoing layer with decreasing weight
        try self.addLayer(.{
            .clip = from_clip,
            .weight = 1.0,
            .time = current_time,
        });

        // Add incoming layer with increasing weight
        try self.addLayer(.{
            .clip = to_clip,
            .weight = 0.0,
            .time = 0,
        });

        _ = fade_duration; // TODO: Implement weight interpolation over time
    }
};

// ============================================================================
// Inverse Kinematics
// ============================================================================

/// IK solver type
pub const IKSolverType = enum {
    two_bone,
    ccd,
    fabrik,
};

/// IK target definition
pub const IKTarget = struct {
    position: Vec3,
    rotation: ?Quaternion = null,
    weight: f32 = 1.0,
};

/// Two-bone IK solver (arm/leg)
pub const TwoBoneIKSolver = struct {
    root_bone: u16,
    mid_bone: u16,
    end_bone: u16,

    /// Pole vector for controlling bend direction
    pole_target: ?Vec3 = null,

    /// Solve IK and apply to skeleton
    pub fn solve(self: *const TwoBoneIKSolver, skeleton: *Skeleton, target: IKTarget) void {
        const root = skeleton.getBoneByIndex(self.root_bone) orelse return;
        const mid = skeleton.getBoneByIndex(self.mid_bone) orelse return;
        const end = skeleton.getBoneByIndex(self.end_bone) orelse return;

        // Get current world positions
        const root_pos = root.world_transform.getTranslation();
        const mid_pos = mid.world_transform.getTranslation();
        const end_pos = end.world_transform.getTranslation();

        // Calculate bone lengths
        const upper_length = mid_pos.sub(root_pos).length();
        const lower_length = end_pos.sub(mid_pos).length();
        const total_length = upper_length + lower_length;

        // Direction and distance to target
        const to_target = target.position.sub(root_pos);
        var target_distance = to_target.length();

        // Clamp to reachable range
        target_distance = @max(0.01, @min(target_distance, total_length * 0.9999));

        // Calculate bend angle using law of cosines
        const a = upper_length;
        const b = lower_length;
        const c = target_distance;

        const cos_mid_angle = (a * a + b * b - c * c) / (2.0 * a * b);
        const mid_angle = std.math.acos(@min(1.0, @max(-1.0, cos_mid_angle)));

        // Calculate root angle
        const cos_root_angle = (a * a + c * c - b * b) / (2.0 * a * c);
        const root_angle = std.math.acos(@min(1.0, @max(-1.0, cos_root_angle)));

        // Build rotation axes
        const target_dir = to_target.normalize();

        var bend_axis: Vec3 = undefined;
        if (self.pole_target) |pole| {
            // Use pole vector to determine bend direction
            const to_pole = pole.sub(root_pos).normalize();
            bend_axis = target_dir.cross(to_pole).normalize();
        } else {
            // Default bend axis
            bend_axis = target_dir.cross(Vec3.up()).normalize();
            if (bend_axis.length() < 0.01) {
                bend_axis = Vec3.right();
            }
        }

        // Apply rotations
        const root_rot = Quaternion.fromAxisAngle(bend_axis, root_angle);
        const mid_rot = Quaternion.fromAxisAngle(bend_axis, std.math.pi - mid_angle);

        // Blend with current pose based on weight
        root.local_transform.rotation = root.local_transform.rotation.slerp(
            root_rot,
            target.weight,
        );
        mid.local_transform.rotation = mid.local_transform.rotation.slerp(
            mid_rot,
            target.weight,
        );

        // Apply end effector rotation if specified
        if (target.rotation) |rot| {
            end.local_transform.rotation = end.local_transform.rotation.slerp(
                rot,
                target.weight,
            );
        }
    }
};

/// FABRIK (Forward And Backward Reaching Inverse Kinematics) solver
pub const FABRIKSolver = struct {
    bone_chain: []const u16,
    max_iterations: u32 = 10,
    tolerance: f32 = 0.001,

    allocator: std.mem.Allocator,

    /// Temporary joint positions
    positions: std.ArrayList(Vec3),

    pub fn init(allocator: std.mem.Allocator, bone_chain: []const u16) FABRIKSolver {
        return .{
            .bone_chain = bone_chain,
            .allocator = allocator,
            .positions = .{},
        };
    }

    pub fn deinit(self: *FABRIKSolver) void {
        self.positions.deinit(self.allocator);
    }

    /// Solve IK and apply to skeleton
    pub fn solve(self: *FABRIKSolver, skeleton: *Skeleton, target: IKTarget) !void {
        if (self.bone_chain.len < 2) return;

        // Get current joint positions
        self.positions.clearRetainingCapacity();
        for (self.bone_chain) |bone_idx| {
            if (skeleton.getBoneByIndex(bone_idx)) |bone| {
                try self.positions.append(self.allocator, bone.world_transform.getTranslation());
            }
        }

        if (self.positions.items.len < 2) return;

        // Calculate bone lengths
        var lengths: [32]f32 = undefined;
        for (0..self.positions.items.len - 1) |idx| {
            lengths[idx] = self.positions.items[idx + 1].sub(self.positions.items[idx]).length();
        }

        const root_pos = self.positions.items[0];

        // FABRIK iteration
        for (0..self.max_iterations) |_| {
            // Check if close enough
            const end_pos = self.positions.items[self.positions.items.len - 1];
            if (end_pos.sub(target.position).length() < self.tolerance) break;

            // Backward pass (from end to root)
            self.positions.items[self.positions.items.len - 1] = target.position;
            var idx = self.positions.items.len - 2;
            while (idx > 0) : (idx -= 1) {
                const dir = self.positions.items[idx].sub(self.positions.items[idx + 1]).normalize();
                self.positions.items[idx] = self.positions.items[idx + 1].add(dir.scale(lengths[idx]));
            }
            // Handle idx == 0
            {
                const dir = self.positions.items[0].sub(self.positions.items[1]).normalize();
                self.positions.items[0] = self.positions.items[1].add(dir.scale(lengths[0]));
            }

            // Forward pass (from root to end)
            self.positions.items[0] = root_pos;
            for (1..self.positions.items.len) |forward_idx| {
                const dir = self.positions.items[forward_idx].sub(self.positions.items[forward_idx - 1]).normalize();
                self.positions.items[forward_idx] = self.positions.items[forward_idx - 1].add(dir.scale(lengths[forward_idx - 1]));
            }
        }

        // Apply positions back to skeleton (convert to local rotations)
        for (0..self.bone_chain.len - 1) |idx| {
            const bone_idx = self.bone_chain[idx];
            if (skeleton.getBoneByIndex(bone_idx)) |bone| {
                const current_pos = self.positions.items[idx];
                const next_pos = self.positions.items[idx + 1];
                const direction = next_pos.sub(current_pos).normalize();

                // Calculate rotation to align bone with direction
                const bone_dir = Vec3.init(0, 1, 0); // Assuming Y-up bones
                const rotation = Quaternion.fromToRotation(bone_dir, direction);

                bone.local_transform.rotation = bone.local_transform.rotation.slerp(
                    rotation,
                    target.weight,
                );
            }
        }
    }
};

// ============================================================================
// Morph Targets (Blend Shapes)
// ============================================================================

/// A single morph target defining vertex deltas
pub const MorphTarget = struct {
    name: []const u8,

    /// Vertex index to position delta
    position_deltas: std.ArrayList(struct { index: u32, delta: Vec3 }),

    /// Vertex index to normal delta
    normal_deltas: std.ArrayList(struct { index: u32, delta: Vec3 }),

    /// Current blend weight (0.0 - 1.0)
    weight: f32 = 0,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) MorphTarget {
        return .{
            .name = name,
            .position_deltas = .{},
            .normal_deltas = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MorphTarget) void {
        self.position_deltas.deinit(self.allocator);
        self.normal_deltas.deinit(self.allocator);
    }

    /// Add a position delta
    pub fn addPositionDelta(self: *MorphTarget, vertex_index: u32, delta: Vec3) !void {
        try self.position_deltas.append(self.allocator, .{ .index = vertex_index, .delta = delta });
    }

    /// Add a normal delta
    pub fn addNormalDelta(self: *MorphTarget, vertex_index: u32, delta: Vec3) !void {
        try self.normal_deltas.append(self.allocator, .{ .index = vertex_index, .delta = delta });
    }
};

/// Morph target manager for a mesh
pub const MorphTargetManager = struct {
    targets: std.ArrayList(MorphTarget),

    /// Base mesh positions
    base_positions: []Vec3,

    /// Base mesh normals
    base_normals: []Vec3,

    /// Output morphed positions
    morphed_positions: std.ArrayList(Vec3),

    /// Output morphed normals
    morphed_normals: std.ArrayList(Vec3),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MorphTargetManager {
        return .{
            .targets = .{},
            .base_positions = &[_]Vec3{},
            .base_normals = &[_]Vec3{},
            .morphed_positions = .{},
            .morphed_normals = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MorphTargetManager) void {
        for (self.targets.items) |*target| {
            target.deinit();
        }
        self.targets.deinit(self.allocator);
        self.morphed_positions.deinit(self.allocator);
        self.morphed_normals.deinit(self.allocator);
    }

    /// Set base mesh data
    pub fn setBaseMesh(self: *MorphTargetManager, positions: []Vec3, normals: []Vec3) !void {
        self.base_positions = positions;
        self.base_normals = normals;

        // Initialize output arrays
        self.morphed_positions.clearRetainingCapacity();
        self.morphed_normals.clearRetainingCapacity();

        for (positions) |pos| {
            try self.morphed_positions.append(self.allocator, pos);
        }
        for (normals) |normal| {
            try self.morphed_normals.append(self.allocator, normal);
        }
    }

    /// Add a morph target
    pub fn addTarget(self: *MorphTargetManager, target: MorphTarget) !void {
        try self.targets.append(self.allocator, target);
    }

    /// Get morph target by name
    pub fn getTarget(self: *MorphTargetManager, name: []const u8) ?*MorphTarget {
        for (self.targets.items) |*target| {
            if (std.mem.eql(u8, target.name, name)) {
                return target;
            }
        }
        return null;
    }

    /// Set target weight by name
    pub fn setTargetWeight(self: *MorphTargetManager, name: []const u8, weight: f32) void {
        if (self.getTarget(name)) |target| {
            target.weight = @max(0.0, @min(1.0, weight));
        }
    }

    /// Apply all morph targets
    pub fn applyMorphs(self: *MorphTargetManager) void {
        // Reset to base mesh
        for (0..self.base_positions.len) |idx| {
            self.morphed_positions.items[idx] = self.base_positions[idx];
            self.morphed_normals.items[idx] = self.base_normals[idx];
        }

        // Apply each morph target
        for (self.targets.items) |*target| {
            if (target.weight < 0.0001) continue;

            // Apply position deltas
            for (target.position_deltas.items) |delta| {
                if (delta.index < self.morphed_positions.items.len) {
                    const scaled = delta.delta.scale(target.weight);
                    self.morphed_positions.items[delta.index] = self.morphed_positions.items[delta.index].add(scaled);
                }
            }

            // Apply normal deltas
            for (target.normal_deltas.items) |delta| {
                if (delta.index < self.morphed_normals.items.len) {
                    const scaled = delta.delta.scale(target.weight);
                    self.morphed_normals.items[delta.index] = self.morphed_normals.items[delta.index].add(scaled).normalize();
                }
            }
        }
    }
};

// ============================================================================
// Animation Controller
// ============================================================================

/// State for animation controller
pub const AnimationState = struct {
    clip: *AnimationClip,
    speed: f32 = 1.0,
    loop: bool = true,

    /// Transitions to other states
    transitions: std.ArrayList(AnimationTransition),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, clip: *AnimationClip) AnimationState {
        return .{
            .clip = clip,
            .allocator = allocator,
            .transitions = .{},
        };
    }

    pub fn deinit(self: *AnimationState) void {
        self.transitions.deinit(self.allocator);
    }

    pub fn addTransition(self: *AnimationState, transition: AnimationTransition) !void {
        try self.transitions.append(self.allocator, transition);
    }
};

/// Transition between animation states
pub const AnimationTransition = struct {
    target_state: []const u8,
    condition: TransitionCondition,
    blend_duration: f32 = 0.25,

    /// Check if transition should trigger
    pub fn shouldTransition(self: *const AnimationTransition, params: *const AnimationParameters) bool {
        return self.condition.evaluate(params);
    }
};

/// Condition for triggering transitions
pub const TransitionCondition = struct {
    parameter: []const u8,
    comparison: Comparison,
    value: ParameterValue,

    pub const Comparison = enum {
        equals,
        not_equals,
        greater,
        less,
        greater_or_equal,
        less_or_equal,
    };

    pub fn evaluate(self: *const TransitionCondition, params: *const AnimationParameters) bool {
        const param_value = params.get(self.parameter) orelse return false;

        return switch (param_value) {
            .boolean => |b| switch (self.value) {
                .boolean => |v| switch (self.comparison) {
                    .equals => b == v,
                    .not_equals => b != v,
                    else => false,
                },
                else => false,
            },
            .integer => |i| switch (self.value) {
                .integer => |v| switch (self.comparison) {
                    .equals => i == v,
                    .not_equals => i != v,
                    .greater => i > v,
                    .less => i < v,
                    .greater_or_equal => i >= v,
                    .less_or_equal => i <= v,
                },
                else => false,
            },
            .float => |f| switch (self.value) {
                .float => |v| switch (self.comparison) {
                    .equals => @abs(f - v) < 0.0001,
                    .not_equals => @abs(f - v) >= 0.0001,
                    .greater => f > v,
                    .less => f < v,
                    .greater_or_equal => f >= v,
                    .less_or_equal => f <= v,
                },
                else => false,
            },
            .trigger => true,
        };
    }
};

/// Parameter value types
pub const ParameterValue = union(enum) {
    boolean: bool,
    integer: i32,
    float: f32,
    trigger: void,
};

/// Animation parameters for controlling transitions
pub const AnimationParameters = struct {
    params: std.StringHashMap(ParameterValue),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AnimationParameters {
        return .{
            .params = std.StringHashMap(ParameterValue).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AnimationParameters) void {
        self.params.deinit();
    }

    pub fn set(self: *AnimationParameters, name: []const u8, value: ParameterValue) !void {
        try self.params.put(name, value);
    }

    pub fn get(self: *const AnimationParameters, name: []const u8) ?ParameterValue {
        return self.params.get(name);
    }

    pub fn setBool(self: *AnimationParameters, name: []const u8, value: bool) !void {
        try self.set(name, .{ .boolean = value });
    }

    pub fn setInt(self: *AnimationParameters, name: []const u8, value: i32) !void {
        try self.set(name, .{ .integer = value });
    }

    pub fn setFloat(self: *AnimationParameters, name: []const u8, value: f32) !void {
        try self.set(name, .{ .float = value });
    }

    pub fn trigger(self: *AnimationParameters, name: []const u8) !void {
        try self.set(name, .{ .trigger = {} });
    }
};

/// High-level animation controller with state machine
pub const AnimationController = struct {
    states: std.StringHashMap(AnimationState),
    current_state: ?[]const u8 = null,
    parameters: AnimationParameters,
    blender: AnimationBlender,

    current_time: f32 = 0,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AnimationController {
        return .{
            .states = std.StringHashMap(AnimationState).init(allocator),
            .parameters = AnimationParameters.init(allocator),
            .blender = AnimationBlender.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AnimationController) void {
        var iter = self.states.valueIterator();
        while (iter.next()) |state| {
            state.deinit();
        }
        self.states.deinit();
        self.parameters.deinit();
        self.blender.deinit();
    }

    /// Add an animation state
    pub fn addState(self: *AnimationController, name: []const u8, state: AnimationState) !void {
        try self.states.put(name, state);

        // Set as current if first state
        if (self.current_state == null) {
            self.current_state = name;
        }
    }

    /// Transition to a state
    pub fn transitionTo(self: *AnimationController, state_name: []const u8, blend_time: f32) !void {
        if (self.states.get(state_name)) |state| {
            _ = state;
            self.current_state = state_name;
            self.current_time = 0;
            _ = blend_time; // TODO: Implement blending
        }
    }

    /// Update the controller
    pub fn update(self: *AnimationController, delta_time: f32, skeleton: *Skeleton) !void {
        const state_name = self.current_state orelse return;
        const state = self.states.getPtr(state_name) orelse return;

        // Check transitions
        for (state.transitions.items) |*transition| {
            if (transition.shouldTransition(&self.parameters)) {
                try self.transitionTo(transition.target_state, transition.blend_duration);
                return;
            }
        }

        // Update time
        self.current_time += delta_time * state.speed;
        if (state.loop) {
            self.current_time = @mod(self.current_time, state.clip.duration);
        }

        // Apply animation
        state.clip.sample(self.current_time, skeleton);
        skeleton.updateWorldTransforms();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Skeleton creation and bone hierarchy" {
    const allocator = std.testing.allocator;

    var skeleton = Skeleton.init(allocator, "TestSkeleton");
    defer skeleton.deinit();

    // Create bone hierarchy: root -> spine -> head
    const root = try skeleton.addBone("root", null);
    const spine = try skeleton.addBone("spine", root);
    const head = try skeleton.addBone("head", spine);

    try std.testing.expectEqual(@as(usize, 3), skeleton.boneCount());
    try std.testing.expectEqual(root, 0);
    try std.testing.expectEqual(spine, 1);
    try std.testing.expectEqual(head, 2);

    // Verify hierarchy
    const spine_bone = skeleton.getBone("spine").?;
    try std.testing.expectEqual(@as(?u16, 0), spine_bone.parent_index);
}

test "BoneWeights normalization" {
    var weights = BoneWeights{};
    weights.weights = .{ 0.5, 0.3, 0.1, 0.1 };
    weights.normalize();

    var sum: f32 = 0;
    for (weights.weights) |w| {
        sum += w;
    }
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), sum, 0.0001);
}

test "AnimationChannel keyframe sampling" {
    const allocator = std.testing.allocator;

    var channel = AnimationChannel.init(allocator, 0);
    defer channel.deinit();

    try channel.addKeyframe(.{
        .time = 0.0,
        .value = .{ .translation = Vec3.zero() },
    });
    try channel.addKeyframe(.{
        .time = 1.0,
        .value = .{ .translation = Vec3.init(10, 0, 0) },
    });

    // Sample at midpoint
    const value = channel.sample(0.5);
    try std.testing.expect(value != null);

    switch (value.?) {
        .translation => |t| {
            try std.testing.expectApproxEqAbs(@as(f32, 5.0), t.x, 0.01);
        },
        else => try std.testing.expect(false),
    }
}

test "MorphTarget weight application" {
    const allocator = std.testing.allocator;

    var manager = MorphTargetManager.init(allocator);
    defer manager.deinit();

    // Create base mesh
    var positions = [_]Vec3{
        Vec3.init(0, 0, 0),
        Vec3.init(1, 0, 0),
    };
    var normals = [_]Vec3{
        Vec3.up(),
        Vec3.up(),
    };

    try manager.setBaseMesh(&positions, &normals);

    // Create morph target (manager takes ownership, so no defer deinit here)
    var target = MorphTarget.init(allocator, "smile");

    try target.addPositionDelta(0, Vec3.init(0, 1, 0));
    target.weight = 0.5;

    try manager.addTarget(target);
    manager.applyMorphs();

    // Check morphed position
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), manager.morphed_positions.items[0].y, 0.01);
}
