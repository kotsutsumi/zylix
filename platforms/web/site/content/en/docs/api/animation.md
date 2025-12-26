---
title: "Animation"
weight: 5
---

# Animation System

The animation module provides a comprehensive animation system with timeline-based keyframe animation, state machines, and support for Lottie and Live2D formats.

## Overview

```
┌─────────────────────────────────────────────┐
│              Animation Module                │
│  ┌───────────────┐  ┌───────────────┐       │
│  │   Timeline    │  │ State Machine │       │
│  │  (Keyframes)  │  │  (Transitions)│       │
│  └───────────────┘  └───────────────┘       │
│  ┌───────────────┐  ┌───────────────┐       │
│  │    Lottie     │  │    Live2D     │       │
│  │   (Vector)    │  │   (2D Model)  │       │
│  └───────────────┘  └───────────────┘       │
└─────────────────────────────────────────────┘
```

## Modules

### Timeline (`timeline.zig`)

Keyframe-based animation with easing functions.

```zig
const animation = @import("animation/animation.zig");

// Create a timeline
var timeline = animation.Timeline.init(allocator);
defer timeline.deinit();

// Add keyframes
try timeline.addKeyframe(0.0, .{ .x = 0, .y = 0 });      // Start
try timeline.addKeyframe(0.5, .{ .x = 100, .y = 50 });   // Midpoint
try timeline.addKeyframe(1.0, .{ .x = 200, .y = 0 });    // End

// Set easing
timeline.setEasing(.ease_in_out);

// Update animation
timeline.update(delta_time);
const current_value = timeline.getValue();
```

**Easing Functions:**

| Function | Description |
|----------|-------------|
| `linear` | Constant speed |
| `ease_in` | Slow start, fast end |
| `ease_out` | Fast start, slow end |
| `ease_in_out` | Slow start and end |
| `ease_in_quad` | Quadratic ease in |
| `ease_out_quad` | Quadratic ease out |
| `ease_in_cubic` | Cubic ease in |
| `ease_out_cubic` | Cubic ease out |
| `ease_in_elastic` | Elastic ease in |
| `ease_out_elastic` | Elastic ease out |
| `ease_in_bounce` | Bounce ease in |
| `ease_out_bounce` | Bounce ease out |

### State Machine (`state_machine.zig`)

Animation state machine for complex animation logic.

```zig
const animation = @import("animation/animation.zig");

// Create state machine
var sm = animation.StateMachine.init(allocator);
defer sm.deinit();

// Define states
try sm.addState("idle", idle_animation);
try sm.addState("walking", walk_animation);
try sm.addState("running", run_animation);
try sm.addState("jumping", jump_animation);

// Define transitions
try sm.addTransition("idle", "walking", .{ .trigger = "move" });
try sm.addTransition("walking", "running", .{ .trigger = "run" });
try sm.addTransition("walking", "idle", .{ .trigger = "stop" });
try sm.addTransition("*", "jumping", .{ .trigger = "jump" });

// Set initial state
sm.setState("idle");

// Trigger transitions
sm.trigger("move");   // idle -> walking
sm.trigger("run");    // walking -> running
sm.trigger("jump");   // running -> jumping (from any state)

// Update
sm.update(delta_time);
```

**Transition Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `trigger` | `[]const u8` | Event name that triggers transition |
| `duration` | `f32` | Blend duration (seconds) |
| `condition` | `?fn() bool` | Optional condition function |
| `priority` | `u8` | Transition priority (higher = preferred) |

### Lottie (`lottie.zig`)

Support for Lottie vector animations (After Effects exports).

```zig
const animation = @import("animation/animation.zig");

// Load Lottie animation
var lottie = try animation.Lottie.load(allocator, "animation.json");
defer lottie.deinit();

// Get animation info
const duration = lottie.getDuration();
const frame_rate = lottie.getFrameRate();
const total_frames = lottie.getTotalFrames();

// Play animation
lottie.play();

// Update and render
lottie.update(delta_time);
const frame = lottie.getCurrentFrame();

// Control playback
lottie.pause();
lottie.stop();
lottie.setSpeed(2.0);  // 2x speed
lottie.setLoop(true);
lottie.seekTo(0.5);    // Seek to 50%
```

### Live2D (`live2d.zig`)

Support for Live2D 2D character animations.

```zig
const animation = @import("animation/animation.zig");

// Load Live2D model
var model = try animation.Live2D.load(allocator, "model.moc3");
defer model.deinit();

// Set parameters
model.setParameter("ParamAngleX", 15.0);   // Head angle X
model.setParameter("ParamAngleY", -10.0);  // Head angle Y
model.setParameter("ParamEyeLOpen", 1.0);  // Left eye open
model.setParameter("ParamMouthOpenY", 0.5); // Mouth open

// Play motion
try model.playMotion("idle", .{ .loop = true });
try model.playMotion("talk", .{ .layer = 1, .priority = .high });

// Set expression
model.setExpression("happy");

// Update
model.update(delta_time);

// Get render data
const mesh_data = model.getMeshData();
```

## Types

### AnimationValue

Generic animation value type.

```zig
pub const AnimationValue = union(enum) {
    float: f32,
    vec2: [2]f32,
    vec3: [3]f32,
    vec4: [4]f32,
    color: [4]u8,
    transform: Transform,
};

pub const Transform = struct {
    position: [3]f32,
    rotation: [4]f32,  // Quaternion
    scale: [3]f32,
};
```

### Keyframe

```zig
pub const Keyframe = struct {
    time: f32,           // Time in seconds
    value: AnimationValue,
    easing: Easing,      // Easing function for this keyframe

    // Bezier control points (optional)
    control_in: ?[2]f32,
    control_out: ?[2]f32,
};
```

### AnimationClip

```zig
pub const AnimationClip = struct {
    name: []const u8,
    duration: f32,
    keyframes: []Keyframe,
    loop: bool,
    speed: f32,

    pub fn sample(self: *const AnimationClip, time: f32) AnimationValue;
    pub fn blend(a: AnimationClip, b: AnimationClip, factor: f32) AnimationValue;
};
```

## Platform Integration

### iOS (SwiftUI)

```swift
import ZylixCore

struct AnimatedView: View {
    @State private var animationValue: CGFloat = 0

    var body: some View {
        Circle()
            .offset(x: animationValue)
            .onAppear {
                // Zylix animation drives SwiftUI
                Timer.scheduledTimer(withTimeInterval: 1/60.0, repeats: true) { _ in
                    zylix_animation_update(1.0/60.0)
                    animationValue = CGFloat(zylix_animation_get_value())
                }
            }
    }
}
```

### Android (Compose)

```kotlin
@Composable
fun AnimatedContent() {
    var animationValue by remember { mutableStateOf(0f) }

    LaunchedEffect(Unit) {
        while (true) {
            delay(16) // ~60fps
            ZylixCore.updateAnimation(0.016f)
            animationValue = ZylixCore.getAnimationValue()
        }
    }

    Box(
        modifier = Modifier.offset(x = animationValue.dp)
    ) {
        // Content
    }
}
```

### Web (WASM)

```javascript
let lastTime = performance.now();

function animate() {
    const now = performance.now();
    const deltaTime = (now - lastTime) / 1000;
    lastTime = now;

    wasm.exports.zylix_animation_update(deltaTime);
    const value = wasm.exports.zylix_animation_get_value();

    element.style.transform = `translateX(${value}px)`;

    requestAnimationFrame(animate);
}

requestAnimationFrame(animate);
```

## Performance Considerations

1. **Object Pooling**: Animation objects are pooled to avoid allocation during playback
2. **SIMD Optimization**: Vector math uses SIMD when available
3. **LOD Support**: Animations can specify level-of-detail for performance scaling
4. **Culling**: Off-screen animations can be paused automatically
