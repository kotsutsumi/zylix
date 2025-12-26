//! Zylix 3D Graphics Module
//!
//! Cross-platform 3D graphics engine with PBR rendering, scene graph,
//! and multiple backend support (Metal, Vulkan, DirectX12, WebGL2, WebGPU).
//!
//! ## Features
//! - **Types**: Vectors, matrices, quaternions, transforms, bounding volumes
//! - **Camera**: Perspective/orthographic cameras with controllers
//! - **Lighting**: PBR lighting with directional, point, spot, area lights
//! - **Mesh**: Procedural geometry and mesh management
//! - **Material**: PBR materials with texture support
//! - **Scene**: Hierarchical scene graph with transform propagation
//! - **Renderer**: Abstract renderer with multiple backend support
//!
//! ## Example
//! ```zig
//! const g3d = @import("graphics3d");
//!
//! // Create a scene
//! var scene = g3d.Scene.init(allocator, "MyScene");
//! defer scene.deinit();
//!
//! // Create a camera
//! var camera = g3d.Camera.init();
//! camera.setPerspective(60.0, 16.0/9.0, 0.1, 1000.0);
//! camera.setPosition(g3d.Vec3.init(0, 5, 10));
//! camera.lookAt(g3d.Vec3.zero(), g3d.Vec3.up());
//!
//! // Create geometry
//! var cube = try g3d.Geometry.createCube(allocator);
//! defer cube.deinit();
//!
//! // Create material
//! var mat = g3d.Material.pbr(g3d.Color.red(), 0.0, 0.5);
//!
//! // Add to scene
//! const node = try scene.createMeshNode("MyCube", &cube, &mat);
//! node.setPosition(g3d.Vec3.init(0, 1, 0));
//! ```

const std = @import("std");

// ============================================================================
// Core Types
// ============================================================================

pub const types = @import("types.zig");

// Re-export commonly used types
pub const Vec2 = types.Vec2;
pub const Vec3 = types.Vec3;
pub const Vec4 = types.Vec4;
pub const Quaternion = types.Quaternion;
pub const Mat4 = types.Mat4;
pub const Color = types.Color;
pub const Transform = types.Transform;
pub const AABB = types.AABB;
pub const BoundingSphere = types.BoundingSphere;
pub const Ray = types.Ray;
pub const Frustum = types.Frustum;

// ============================================================================
// Camera System
// ============================================================================

pub const camera = @import("camera.zig");

pub const Camera = camera.Camera;
pub const CameraManager = camera.CameraManager;
pub const OrbitController = camera.OrbitController;
pub const FirstPersonController = camera.FirstPersonController;
pub const FlyController = camera.FlyController;

// ============================================================================
// Lighting System
// ============================================================================

pub const lighting = @import("lighting.zig");

pub const LightBase = lighting.LightBase;
pub const LightType = lighting.LightType;
pub const DirectionalLight = lighting.DirectionalLight;
pub const PointLight = lighting.PointLight;
pub const SpotLight = lighting.SpotLight;
pub const AreaLight = lighting.AreaLight;
pub const AmbientLight = lighting.AmbientLight;
pub const LightManager = lighting.LightManager;

// ============================================================================
// Mesh & Geometry
// ============================================================================

pub const mesh = @import("mesh.zig");

pub const Vertex = mesh.Vertex;
pub const VertexTangent = mesh.VertexTangent;
pub const VertexSkinned = mesh.VertexSkinned;
pub const VertexColored = mesh.VertexColored;
pub const Mesh = mesh.Mesh;
pub const SubMesh = mesh.SubMesh;
pub const Geometry = mesh.Geometry;

// ============================================================================
// Material System
// ============================================================================

pub const material = @import("material.zig");

pub const Texture2D = material.Texture2D;
pub const TextureCube = material.TextureCube;
pub const TextureFormat = material.TextureFormat;
pub const TextureType = material.TextureType;
pub const WrapMode = material.WrapMode;
pub const FilterMode = material.FilterMode;
pub const Shader = material.Shader;
pub const ShaderStage = material.ShaderStage;
pub const UniformType = material.UniformType;
pub const Material = material.Material;
pub const MaterialLibrary = material.MaterialLibrary;
pub const BlendMode = material.BlendMode;
pub const CullMode = material.CullMode;
pub const CompareFunc = material.CompareFunc;

// ============================================================================
// Scene Graph
// ============================================================================

pub const scene = @import("scene.zig");

pub const SceneNode = scene.SceneNode;
pub const NodeType = scene.NodeType;
pub const Scene = scene.Scene;
pub const SceneStats = scene.SceneStats;

// ============================================================================
// Renderer
// ============================================================================

pub const renderer = @import("renderer.zig");

pub const BackendType = renderer.BackendType;
pub const RenderCapabilities = renderer.RenderCapabilities;
pub const RenderState = renderer.RenderState;
pub const RenderQueue = renderer.RenderQueue;
pub const RenderStats = renderer.RenderStats;
pub const RenderPass = renderer.RenderPass;
pub const Renderer = renderer.Renderer;
pub const DebugDraw = renderer.DebugDraw;

// ============================================================================
// Model Loaders
// ============================================================================

pub const gltf = @import("gltf.zig");
pub const obj = @import("obj.zig");
pub const fbx = @import("fbx.zig");

pub const GltfLoader = gltf.GltfLoader;
pub const GltfAsset = gltf.GltfAsset;
pub const ObjLoader = obj.ObjLoader;
pub const ObjAsset = obj.ObjAsset;
pub const FbxLoader = fbx.FbxLoader;
pub const FbxAsset = fbx.FbxAsset;

// ============================================================================
// Shadow Mapping
// ============================================================================

pub const shadow = @import("shadow.zig");

pub const ShadowMap = shadow.ShadowMap;
pub const ShadowManager = shadow.ShadowManager;
pub const CascadedShadowMap = shadow.CascadedShadowMap;
pub const PointShadowMap = shadow.PointShadowMap;
pub const SpotShadowMap = shadow.SpotShadowMap;
pub const ShadowQuality = shadow.ShadowQuality;
pub const ShadowFilter = shadow.ShadowFilter;
pub const ShadowUniforms = shadow.ShadowUniforms;

// ============================================================================
// Post-Processing
// ============================================================================

pub const postprocess = @import("postprocess.zig");

pub const PostProcessPipeline = postprocess.PostProcessPipeline;
pub const PostProcessPass = postprocess.PostProcessPass;
pub const PostProcessPreset = postprocess.PostProcessPreset;
pub const EffectType = postprocess.EffectType;
pub const ToneMapper = postprocess.ToneMapper;
pub const RenderTarget = postprocess.RenderTarget;
pub const RenderTargetFormat = postprocess.RenderTargetFormat;

// Effect Settings
pub const ToneMappingSettings = postprocess.ToneMappingSettings;
pub const BloomSettings = postprocess.BloomSettings;
pub const SSAOSettings = postprocess.SSAOSettings;
pub const MotionBlurSettings = postprocess.MotionBlurSettings;
pub const DepthOfFieldSettings = postprocess.DepthOfFieldSettings;
pub const ColorGradingSettings = postprocess.ColorGradingSettings;
pub const FXAASettings = postprocess.FXAASettings;
pub const TAASettings = postprocess.TAASettings;
pub const VignetteSettings = postprocess.VignetteSettings;
pub const FilmGrainSettings = postprocess.FilmGrainSettings;
pub const ChromaticAberrationSettings = postprocess.ChromaticAberrationSettings;
pub const SharpeningSettings = postprocess.SharpeningSettings;
pub const FogSettings = postprocess.FogSettings;
pub const OutlineSettings = postprocess.OutlineSettings;

// ============================================================================
// Navigation Mesh & Pathfinding
// ============================================================================

pub const navmesh = @import("navmesh.zig");

pub const NavMesh = navmesh.NavMesh;
pub const NavPolygon = navmesh.NavPolygon;
pub const NavEdge = navmesh.NavEdge;
pub const NavNode = navmesh.NavNode;
pub const NavAgent = navmesh.NavAgent;
pub const NavQueryFilter = navmesh.NavQueryFilter;
pub const PathWaypoint = navmesh.PathWaypoint;
pub const NavMeshBuilder = navmesh.NavMeshBuilder;
pub const DynamicObstacle = navmesh.DynamicObstacle;
pub const ObstacleManager = navmesh.ObstacleManager;

// ============================================================================
// Behavior Tree System
// ============================================================================

pub const behavior_tree = @import("behavior_tree.zig");

pub const BehaviorTree = behavior_tree.BehaviorTree;
pub const BehaviorNode = behavior_tree.BehaviorNode;
pub const BTStatus = behavior_tree.Status;
pub const BTNodeType = behavior_tree.NodeType;
pub const Blackboard = behavior_tree.Blackboard;
pub const NodeContext = behavior_tree.NodeContext;
pub const TreeBuilder = behavior_tree.TreeBuilder;
pub const BTActions = behavior_tree.Actions;
pub const BTConditions = behavior_tree.Conditions;

// ============================================================================
// Platform Backends
// ============================================================================

pub const backend_metal = @import("backend_metal.zig");

// Metal Backend (iOS/macOS)
pub const MetalBackend = backend_metal.MetalBackend;
pub const MetalPixelFormat = backend_metal.PixelFormat;
pub const MetalPrimitiveType = backend_metal.PrimitiveType;
pub const MetalTextureDescriptor = backend_metal.TextureDescriptor;
pub const MetalSamplerDescriptor = backend_metal.SamplerDescriptor;
pub const MetalRenderPassDescriptor = backend_metal.RenderPassDescriptor;
pub const MetalVertexDescriptor = backend_metal.VertexDescriptor;
pub const MetalRenderPipelineDescriptor = backend_metal.RenderPipelineDescriptor;
pub const MetalDepthStencilDescriptor = backend_metal.DepthStencilDescriptor;

pub const backend_web = @import("backend_web.zig");

// Web Backend (WebGL2/WebGPU)
pub const WebBackend = backend_web.WebBackend;
pub const WebBackendAPI = backend_web.BackendAPI;
pub const WebDrawMode = backend_web.DrawMode;
pub const WebBufferTarget = backend_web.BufferTarget;
pub const WebTextureFormat = backend_web.TextureFormat;
pub const WebTextureDescriptor = backend_web.TextureDescriptor;
pub const WebSamplerDescriptor = backend_web.SamplerDescriptor;
pub const WebFramebufferDescriptor = backend_web.FramebufferDescriptor;
pub const WebBlendState = backend_web.BlendState;
pub const WebDepthState = backend_web.DepthState;

// ============================================================================
// Version & Info
// ============================================================================

/// Graphics3D module version
pub const version = struct {
    pub const major = 0;
    pub const minor = 14;
    pub const patch = 0;
    pub const string = "0.14.0";
};

/// Get module information
pub fn getInfo() struct {
    version: []const u8,
    features: []const []const u8,
} {
    return .{
        .version = version.string,
        .features = &[_][]const u8{
            "PBR Rendering",
            "Scene Graph",
            "Procedural Geometry",
            "Multiple Camera Controllers",
            "Dynamic Lighting",
            "Material System",
            "Frustum Culling",
            "Multiple Backends",
            "glTF 2.0 Loader",
            "OBJ/MTL Loader",
            "FBX Loader",
            "Shadow Mapping (CSM, Point, Spot)",
            "Post-Processing (HDR, Bloom, SSAO, DoF)",
            "Metal Backend (iOS/macOS)",
            "WebGL2/WebGPU Backend (Web)",
            "Navigation Mesh & Pathfinding",
            "Behavior Tree System",
        },
    };
}

// ============================================================================
// Tests
// ============================================================================

test "graphics3d module exports" {
    // Verify all modules are accessible
    _ = types;
    _ = camera;
    _ = lighting;
    _ = mesh;
    _ = material;
    _ = scene;
    _ = renderer;
    _ = gltf;
    _ = obj;
    _ = fbx;
    _ = shadow;
    _ = postprocess;
    _ = backend_metal;
    _ = backend_web;
    _ = navmesh;
    _ = behavior_tree;
}

test "graphics3d types accessible" {
    // Verify commonly used types
    const v = Vec3.init(1, 2, 3);
    try std.testing.expect(v.x == 1);

    const c = Color.red();
    try std.testing.expect(c.r == 1);

    const t = Transform.identity();
    try std.testing.expect(t.scale.x == 1);
}

test "graphics3d version" {
    try std.testing.expectEqualStrings("0.14.0", version.string);

    const info = getInfo();
    try std.testing.expect(info.features.len > 0);
}
