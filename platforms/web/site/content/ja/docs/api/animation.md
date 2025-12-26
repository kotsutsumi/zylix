---
title: "アニメーション"
weight: 5
---

# アニメーションシステム

アニメーションモジュールは、タイムラインベースのキーフレームアニメーション、ステートマシン、LottieおよびLive2D形式のサポートを含む包括的なアニメーションシステムを提供します。

## 概要

```
┌─────────────────────────────────────────────┐
│           アニメーションモジュール            │
│  ┌───────────────┐  ┌───────────────┐       │
│  │ タイムライン  │  │ ステート      │       │
│  │ (キーフレーム)│  │ マシン        │       │
│  │               │  │ (トランジション)│      │
│  └───────────────┘  └───────────────┘       │
│  ┌───────────────┐  ┌───────────────┐       │
│  │    Lottie     │  │    Live2D     │       │
│  │   (ベクター)  │  │  (2Dモデル)   │       │
│  └───────────────┘  └───────────────┘       │
└─────────────────────────────────────────────┘
```

## モジュール

### タイムライン（`timeline.zig`）

イージング関数を使用したキーフレームベースのアニメーション。

```zig
const animation = @import("animation/animation.zig");

// タイムラインを作成
var timeline = animation.Timeline.init(allocator);
defer timeline.deinit();

// キーフレームを追加
try timeline.addKeyframe(0.0, .{ .x = 0, .y = 0 });      // 開始
try timeline.addKeyframe(0.5, .{ .x = 100, .y = 50 });   // 中間点
try timeline.addKeyframe(1.0, .{ .x = 200, .y = 0 });    // 終了

// イージングを設定
timeline.setEasing(.ease_in_out);

// アニメーションを更新
timeline.update(delta_time);
const current_value = timeline.getValue();
```

**イージング関数:**

| 関数 | 説明 |
|----------|-------------|
| `linear` | 一定速度 |
| `ease_in` | ゆっくり開始、速く終了 |
| `ease_out` | 速く開始、ゆっくり終了 |
| `ease_in_out` | ゆっくり開始と終了 |
| `ease_in_quad` | 二次イーズイン |
| `ease_out_quad` | 二次イーズアウト |
| `ease_in_cubic` | 三次イーズイン |
| `ease_out_cubic` | 三次イーズアウト |
| `ease_in_elastic` | 弾性イーズイン |
| `ease_out_elastic` | 弾性イーズアウト |
| `ease_in_bounce` | バウンスイーズイン |
| `ease_out_bounce` | バウンスイーズアウト |

### ステートマシン（`state_machine.zig`）

複雑なアニメーションロジック用のアニメーションステートマシン。

```zig
const animation = @import("animation/animation.zig");

// ステートマシンを作成
var sm = animation.StateMachine.init(allocator);
defer sm.deinit();

// 状態を定義
try sm.addState("idle", idle_animation);
try sm.addState("walking", walk_animation);
try sm.addState("running", run_animation);
try sm.addState("jumping", jump_animation);

// トランジションを定義
try sm.addTransition("idle", "walking", .{ .trigger = "move" });
try sm.addTransition("walking", "running", .{ .trigger = "run" });
try sm.addTransition("walking", "idle", .{ .trigger = "stop" });
try sm.addTransition("*", "jumping", .{ .trigger = "jump" });

// 初期状態を設定
sm.setState("idle");

// トランジションをトリガー
sm.trigger("move");   // idle -> walking
sm.trigger("run");    // walking -> running
sm.trigger("jump");   // running -> jumping（任意の状態から）

// 更新
sm.update(delta_time);
```

**トランジションプロパティ:**

| プロパティ | 型 | 説明 |
|----------|------|-------------|
| `trigger` | `[]const u8` | トランジションをトリガーするイベント名 |
| `duration` | `f32` | ブレンド時間（秒） |
| `condition` | `?fn() bool` | オプションの条件関数 |
| `priority` | `u8` | トランジション優先度（高い = 優先） |

### Lottie（`lottie.zig`）

Lottieベクターアニメーション（After Effectsエクスポート）のサポート。

```zig
const animation = @import("animation/animation.zig");

// Lottieアニメーションをロード
var lottie = try animation.Lottie.load(allocator, "animation.json");
defer lottie.deinit();

// アニメーション情報を取得
const duration = lottie.getDuration();
const frame_rate = lottie.getFrameRate();
const total_frames = lottie.getTotalFrames();

// アニメーションを再生
lottie.play();

// 更新とレンダリング
lottie.update(delta_time);
const frame = lottie.getCurrentFrame();

// 再生制御
lottie.pause();
lottie.stop();
lottie.setSpeed(2.0);  // 2倍速
lottie.setLoop(true);
lottie.seekTo(0.5);    // 50%にシーク
```

### Live2D（`live2d.zig`）

Live2D 2Dキャラクターアニメーションのサポート。

```zig
const animation = @import("animation/animation.zig");

// Live2Dモデルをロード
var model = try animation.Live2D.load(allocator, "model.moc3");
defer model.deinit();

// パラメータを設定
model.setParameter("ParamAngleX", 15.0);   // 頭の角度X
model.setParameter("ParamAngleY", -10.0);  // 頭の角度Y
model.setParameter("ParamEyeLOpen", 1.0);  // 左目を開く
model.setParameter("ParamMouthOpenY", 0.5); // 口を開く

// モーションを再生
try model.playMotion("idle", .{ .loop = true });
try model.playMotion("talk", .{ .layer = 1, .priority = .high });

// 表情を設定
model.setExpression("happy");

// 更新
model.update(delta_time);

// レンダリングデータを取得
const mesh_data = model.getMeshData();
```

## 型

### AnimationValue

汎用アニメーション値型。

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
    rotation: [4]f32,  // クォータニオン
    scale: [3]f32,
};
```

### Keyframe

```zig
pub const Keyframe = struct {
    time: f32,           // 秒単位の時間
    value: AnimationValue,
    easing: Easing,      // このキーフレームのイージング関数

    // ベジェ制御点（オプション）
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

## プラットフォーム統合

### iOS（SwiftUI）

```swift
import ZylixCore

struct AnimatedView: View {
    @State private var animationValue: CGFloat = 0

    var body: some View {
        Circle()
            .offset(x: animationValue)
            .onAppear {
                // ZylixアニメーションがSwiftUIを駆動
                Timer.scheduledTimer(withTimeInterval: 1/60.0, repeats: true) { _ in
                    zylix_animation_update(1.0/60.0)
                    animationValue = CGFloat(zylix_animation_get_value())
                }
            }
    }
}
```

### Android（Compose）

```kotlin
@Composable
fun AnimatedContent() {
    var animationValue by remember { mutableStateOf(0f) }

    LaunchedEffect(Unit) {
        while (true) {
            delay(16) // 約60fps
            ZylixCore.updateAnimation(0.016f)
            animationValue = ZylixCore.getAnimationValue()
        }
    }

    Box(
        modifier = Modifier.offset(x = animationValue.dp)
    ) {
        // コンテンツ
    }
}
```

### Web（WASM）

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

## パフォーマンス考慮事項

1. **オブジェクトプーリング**: 再生中のアロケーションを避けるためにアニメーションオブジェクトをプール
2. **SIMD最適化**: 利用可能な場合、ベクター演算にSIMDを使用
3. **LODサポート**: パフォーマンススケーリングのためのレベルオブディテールを指定可能
4. **カリング**: 画面外のアニメーションを自動的に一時停止可能
