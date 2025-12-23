//! Zylix Game Development Platform v0.13.0
//!
//! A comprehensive game development platform inspired by PIXI.js and Matter.js,
//! providing 2D game engine, physics simulation, audio system, and game utilities.
//!
//! ## Features
//!
//! - **2D Game Engine**: Sprite system, texture atlases, tile maps, game loop
//! - **Physics Engine**: Rigid body dynamics, collision detection, constraints
//! - **Audio System**: Sound effects, background music, positional audio
//! - **Game Utilities**: ECS architecture, object pooling, camera system, save/load

const std = @import("std");

// 2D Game Engine
pub const sprite = @import("sprite.zig");
pub const tilemap = @import("tilemap.zig");
pub const game_loop = @import("game_loop.zig");

// Physics Engine
pub const physics = @import("physics.zig");
pub const constraints = @import("constraints.zig");

// Audio System
pub const audio = @import("audio.zig");

// Game Utilities
pub const ecs = @import("ecs.zig");
pub const pool = @import("pool.zig");
pub const camera = @import("camera.zig");
pub const save = @import("save.zig");

// Re-export commonly used types
pub const Sprite = sprite.Sprite;
pub const SpriteBatch = sprite.SpriteBatch;
pub const TextureAtlas = sprite.TextureAtlas;
pub const AnimatedSprite = sprite.AnimatedSprite;

pub const TileMap = tilemap.TileMap;
pub const TileLayer = tilemap.TileLayer;
pub const TileSet = tilemap.TileSet;

pub const GameLoop = game_loop.GameLoop;
pub const FixedTimestep = game_loop.FixedTimestep;

pub const RigidBody = physics.RigidBody;
pub const Collider = physics.Collider;
pub const PhysicsWorld = physics.PhysicsWorld;

pub const Constraint = constraints.Constraint;
pub const DistanceConstraint = constraints.DistanceConstraint;
pub const RevoluteConstraint = constraints.RevoluteConstraint;

pub const AudioPlayer = audio.AudioPlayer;
pub const SoundEffect = audio.SoundEffect;
pub const MusicTrack = audio.MusicTrack;

pub const World = ecs.World;
pub const Entity = ecs.Entity;
pub const Component = ecs.Component;
pub const System = ecs.System;

pub const ObjectPool = pool.ObjectPool;
pub const Camera2D = camera.Camera2D;
pub const SaveManager = save.SaveManager;

test {
    std.testing.refAllDecls(@This());
}
