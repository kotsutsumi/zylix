# HeyBot Implementation Plan (Living Document)

## Purpose
This document is a long-term, mid-term, and short-term implementation plan for the HeyBot app
built on Zylix for iOS, watchOS, and Android. It is intentionally iterative and meant to be
revisited, refined, and expanded as Zylix evolves.

## Principles
- Keep the app thin; validate Zylix in real usage.
- Avoid privacy risk: no storage or upload of camera frames.
- Offline-first for MVP: all audio is bundled.
- Ads are secondary and never the main screen.
- Feed back missing Zylix features and implement them in Zylix, not in app-specific hacks.

## Product Summary
- App: HeyBot (iOS, Android, watchOS)
- Core loop: touch to react, eyes follow motion, simple voice responses
- Revenue: non-tracking ads + IAP remove ads
- Screens: Face, Settings, Shop (minimal)

## Long-Term Plan (3-12 months)

### L1. Multi-platform polish and parity
- iOS and Android feature parity with consistent behavior.
- watchOS companion mode: simplified face-only screen with limited reactions.
- Unified state machine spec shared across platforms.
- Define a visual language (colors, eye/face style variants) for future skin packs.

### L2. Platform-quality and store reliability
- Store compliance checklists with automated validation where possible.
- Multi-language support (JP/EN as initial targets).
- Permission and privacy copy that is platform-appropriate and consistent.
- Crash and performance monitoring (local diagnostics only at first).

### L3. Sustainable release operations
- Weekly release cadence with a stable feature flag mechanism.
- Internal QA checklist and device coverage matrix.
- Pipeline for audio pack and skin pack updates with minimal code changes.

### L4. Zylix contributions (long-term)
- Standardized camera motion detection module.
- Low-latency audio playback engine suitable for short clips.
- IAP abstraction that unifies StoreKit2 and Play Billing.
- Ads abstraction (provider-agnostic interface) with non-tracking defaults.
- Cross-platform haptics API with consistent amplitude and duration settings.

## Mid-Term Plan (4-12 weeks)

### M1. Core interaction stability
- State machine implementation validated by test scenarios.
- Input mapping tuned for touch patterns (tap, stroke, long-press).
- Battery-aware camera tracking (FPS and resolution throttling).
- Improved idle behaviors (blink cadence, small eye motion).

### M2. MVP monetization readiness
- Settings and Shop screens finalized with minimal UI.
- Remove-ads IAP flow and restore process in both platforms.
- Ad placement limited to Settings/Shop, with testing on different devices.

### M3. Zylix feedback loop
- Weekly gap list for missing Zylix features.
- Implement missing capabilities in Zylix before app-level work.
- Provide minimal repro examples inside Zylix test apps.

### M4. watchOS scope
- Decide on watchOS UI strategy (face-only, no camera tracking).
- Evaluate audio constraints and haptics for watch.
- Confirm store and privacy expectations for watch-only interactions.

## Short-Term Plan (Week-by-week)

### S1. Week 1: Core MVP foundation
Goal: minimal Face screen with reactions and simple motion tracking.
- Face screen layout (landscape only for phone/tablet).
- Eye tracking via motion centroid (no face detection).
- Touch responses: tap, stroke, long-press.
- Idle behavior: blink and small eye movement.
- Audio playback of bundled clips with random selection.
- Settings basics: audio on/off, volume, tracking on/off.
- Privacy text: no storage, no upload of camera data.
- Zylix gaps list created from this build.

### S2. Week 2: State machine and refinement
Goal: predictable behavior with better transitions.
- Implement explicit states: Idle, Tracking, Happy, Shy, Sleepy, Attention.
- Transition rules with timers and probabilities.
- Add smoothing (EMA) for eye movement.
- Add small reaction variations (eye shape change, short mouth motion).
- Add optional FPS throttling for low-power mode.

### S3. Week 3: Monetization layer
Goal: ads and remove-ads flow without disrupting core UX.
- Shop screen with remove-ads IAP.
- Restore purchase flows for iOS and Android.
- Banner ads only in Settings/Shop.
- Post-purchase thank-you reaction.

### S4. Week 4: Polishing and release readiness
Goal: store-ready MVP with minimal risk.
- Finalize privacy text and permission prompts.
- Battery and thermal checks; auto-degrade if needed.
- App store metadata: screenshots, description, privacy policy URL.
- Release checklist and basic QA pass.

## Pre-Implementation Design (Detailed)
This section expands the plan into concrete design and pseudo-code to guide actual implementation.
No code changes are made here; it is a specification to reduce ambiguity when coding starts.

### D1. Data model and state machine
Define a minimal, explicit state machine that can run on all platforms.

States:
- Idle, Tracking, Happy, Shy, Sleepy, Attention

Core events:
- TouchTap, TouchStroke, TouchLongPress
- IdleTimeout, AttentionTick
- TrackingEnabled, TrackingDisabled
- AppForeground, AppBackground

Pseudo-spec:
- Idle + TouchStroke => Happy (duration 1.5s)
- Idle + TouchLongPress => Shy (duration 1.2s)
- Idle + IdleTimeout(90s) => Sleepy
- Sleepy + TouchTap => Idle
- Idle/Tracking + AttentionTick => Attention (duration 1.0s)
- TrackingEnabled toggles eye-following logic only; it does not force a state.

Suggested structure:
```
enum class BotState { Idle, Tracking, Happy, Shy, Sleepy, Attention }

data class BotEvent(val type: EventType, val ts: Long)

data class BotContext(
  var state: BotState,
  var lastInteractionTs: Long,
  var trackingEnabled: Boolean,
  var lowPowerEnabled: Boolean
)

fun reduce(ctx: BotContext, event: BotEvent): BotContext { ... }
```

#### D1.1 Transition table (detailed)
Key:
- "Guard" is a boolean condition.
- "Action" describes side-effects at state entry.
- "Duration" is a fixed timer; on expiry, a Timeout event fires.

| From | Event | Guard | To | Action | Duration |
| --- | --- | --- | --- | --- | --- |
| Idle | TouchTap | audioEnabled | Idle | play(SFX_TAP); blinkOnce | none |
| Idle | TouchStroke | true | Happy | play(SFX_HAPPY); mouth=SmileBig; eyes=Sparkle | 1.5s |
| Idle | TouchLongPress | true | Shy | play(SFX_SHY); mouth=Tiny; eyes=Down | 1.2s |
| Idle | IdleTimeout | true | Sleepy | mouth=Small; eyes=Half | none |
| Idle | AttentionTick | rand < attentionProb | Attention | play(SFX_ATTENTION); eyes=Wide | 1.0s |
| Tracking | TouchStroke | true | Happy | play(SFX_HAPPY); mouth=SmileBig | 1.5s |
| Tracking | TouchLongPress | true | Shy | play(SFX_SHY); mouth=Tiny | 1.2s |
| Tracking | AttentionTick | rand < attentionProb | Attention | play(SFX_ATTENTION); eyes=Wide | 1.0s |
| Happy | Timeout | true | Idle/Tracking | restore default poses | none |
| Shy | Timeout | true | Idle/Tracking | restore default poses | none |
| Attention | Timeout | true | Idle/Tracking | restore default poses | none |
| Sleepy | TouchTap | true | Idle/Tracking | blinkOnce; mouth=SmileSmall | none |
| Any | AppBackground | true | Idle | stop tracking; stop audio | none |
| Any | TrackingEnabled | true | Tracking | enable eye follow | none |
| Any | TrackingDisabled | true | Idle | disable eye follow | none |

Notes:
- Idle/Tracking is chosen based on trackingEnabled flag at transition end.
- AttentionTick is emitted on a repeating timer (see D1.2).
- TouchTap does not change state by default to keep behavior calm.

#### D1.2 Timers and probabilities
Timers:
- IdleTimeout: fires after 90s with no interaction (touch events).
- AttentionTick: every 20-60s (randomized each cycle).
- BlinkTick: every 3-6s (randomized each cycle).

Suggested parameters (tunable):
```
idleTimeoutMs = 90_000
attentionTickRangeMs = [20_000, 60_000]
blinkTickRangeMs = [3_000, 6_000]
attentionProb = 0.35
```

Timer behavior:
- Each tick re-schedules itself with a new random interval in its range.
- Timers pause on AppBackground; resume on AppForeground with reset.

#### D1.3 Event emission rules
- Touch events emit immediately.
- IdleTimeout resets on any touch event.
- AttentionTick is ignored if state is Happy/Shy/Attention (no overlapping).
- TrackingEnabled/Disabled should not interrupt timed states (unless AppBackground).

### D2. Rendering model (eyes + mouth)
Represent eyes and mouth as layered sprites or vector paths.

Eyes:
- Base eye shape (white), pupil circle, highlight dot.
- Eye offset computed from tracking target (x, y in [-1..1]).
- Clamp pupil movement to a small radius.

Mouth:
- Idle: small smile curve.
- Happy: larger smile; optional short mouth-open animation.
- Shy: tiny mouth or angled line.

Suggested render parameters:
```
struct EyePose { float offsetX; float offsetY; float blink; }
struct MouthPose { float openness; float curve; }
```

#### D2.1 Eye geometry parameters
Base parameters (normalized):
- eyeRadius: 1.0
- pupilRadius: 0.35
- pupilMaxOffset: 0.25
- highlightRadius: 0.12
- blinkAmount: 0.0..1.0 (0 open, 1 closed)

Pose mapping:
- offsetX/Y in [-1..1] scaled by pupilMaxOffset.
- blinkAmount maps to vertical scale of eye white.

Blink curve:
```
// t: 0..1
blink = sin(pi * t)  // quick close, quick open
```

#### D2.2 Mouth parameters
- curve: -1.0..1.0 (frown to smile)
- openness: 0.0..1.0 (closed to open)
- jitter: small random offset for "alive" feeling (disabled in Sleepy)

Mapping:
- Idle: curve=0.4, openness=0.1
- Happy: curve=0.9, openness=0.4
- Shy: curve=0.1, openness=0.0
- Sleepy: curve=0.2, openness=0.0
- Attention: curve=0.6, openness=0.2

#### D2.3 Animation timing
- Blink duration: 120ms total (close 40ms, open 80ms).
- Mouth open/close: 150ms ease-in-out.
- State entry pose tween: 200ms with cubic easing.

#### D2.4 Rendering implementation notes
- Keep rendering on a single canvas layer if possible to reduce overdraw.
- Avoid alpha blending heavy effects; use solid colors + subtle gradient background.
- Pupil and highlight should be clipped within eye white bounds.

### D3. Motion tracking algorithm (camera)
Lightweight frame-diff centroid detection.

Algorithm outline:
1) Capture grayscale frame at low resolution (e.g., 320x240).
2) Compute absolute difference with previous frame.
3) Threshold to binary mask.
4) Compute centroid of white pixels.
5) Normalize centroid to [-1..1] range.
6) Smooth with EMA.

Pseudo-code:
```
diff = abs(curr - prev)
mask = diff > threshold
if mask.count > minPixels:
  cx = sum(x * mask) / count
  cy = sum(y * mask) / count
  nx = (cx / width) * 2 - 1
  ny = (cy / height) * 2 - 1
  target = (nx, ny)
else:
  target = (0, 0)

eye.x = lerp(eye.x, target.x, 0.15)
eye.y = lerp(eye.y, target.y, 0.15)
```

Zylix needs:
- Camera capture with frame callback, no preview.
- Grayscale or raw buffer access.
- Fixed FPS cap (e.g., 15 fps) and resolution.

#### D3.1 Optimization and low-power behavior
Targets:
- Default tracking: 320x240 @ 15 fps.
- Low power mode: 160x120 @ 8 fps.

Optimizations:
- Downscale in camera pipeline (avoid CPU scaling).
- Use integer math for diff and threshold where possible.
- Early exit if motion pixel count < minPixels.
- Skip processing every N frames if device is hot or battery low.

Dynamic throttling:
```
if (lowPowerEnabled) {
  fps = 8
  resolution = 160x120
} else if (batteryLow || thermalHigh) {
  fps = 10
  resolution = 160x120
} else {
  fps = 15
  resolution = 320x240
}
```

Smoothing:
- EMA alpha 0.15 for normal mode.
- EMA alpha 0.10 for low power (slightly slower, calmer movement).

Fallback:
- If no motion detected for 3s, ease target to center (0,0).

### D4. Touch gesture mapping
Gesture thresholds:
- Tap: < 200ms, movement < 10px
- Long press: > 500ms, movement < 10px
- Stroke: movement > 20px within 500ms

Mapping:
- Tap => short happy sound + blink
- Long press => Shy state + soft sound
- Stroke => Happy state + excited sound

### D5. Audio playback spec
Audio assets:
- 40-80 short clips (0.3-1.2s), categorized by state.
Playback:
- Debounce to avoid overlap (e.g., minimum 250ms between clips).
- Random selection with last-N exclusion.

Pseudo-code:
```
fun playCategory(cat: AudioCategory) {
  if (now - lastPlay < 250) return
  val clip = pickRandom(cat, excludeLast = 2)
  audio.play(clip)
}
```

Zylix needs:
- Low-latency clip player.
- Preload to memory.
- Simple category-based selection helper.

### D6. Settings and persistence
Settings model:
- trackingEnabled: bool
- trackingSensitivity: enum { Low, Mid, High }
- lowPowerEnabled: bool
- audioEnabled: bool
- volume: 0..1

Persist:
- Local key-value store, no cloud.
- Apply on startup before first render.

### D7. UI layout (Face)
Layout:
- Fullscreen landscape.
- Eyes centered horizontally; mouth below eyes.
- Settings icon top-right; Shop icon bottom-right.

Interaction layering:
- Entire screen receives touch gestures.
- Buttons have priority if touched within bounds.

### D8. Privacy and permissions
Permission flow:
- Explain why camera is needed (motion-only, no face recognition).
- Provide in-app privacy section.
- If camera off, default to Idle behavior (no tracking).

Required copy examples:
- "HeyBot uses the camera only to detect motion. Images are not stored or sent."

#### D8.1 Suggested settings copy (store-review friendly)
Camera permission explanation:
- "We use the camera only to detect motion so the eyes can follow you. No photos or videos are saved or sent."

Privacy section (in-app):
- "Camera frames are processed on-device to detect motion only."
- "We do not store, share, or upload camera data."
- "HeyBot works offline. No account is required."

Data collection statement:
- "We do not collect personal data. Ads, if enabled, are non-tracking."

#### D8.2 Permission handling behavior
- If user denies camera permission, show a one-time tip with a button to Settings.
- App remains usable with fixed eye behavior (no tracking).
- Do not re-prompt aggressively; wait for user action.

### D9. Ads and IAP integration notes
Ads:
- Only load in Settings/Shop.
- Hide ads entirely after purchase.

IAP:
- Single product: remove_ads
- Restore button for iOS/Android.

Zylix needs:
- IAP abstraction with restore.
- Ads abstraction with banner lifecycle.

### D10. WatchOS scope (design-only for now)
- Face-only view, no camera tracking.
- Tap reactions only.
- Haptics for feedback.

## Detailed Task Breakdown (Implementation-Ready)
These tasks are intended to become actual implementation tickets later.

### T1. Core rendering pipeline
- Define data structures for EyePose and MouthPose.
- Implement eye/pupil rendering in Zylix scene.
- Implement mouth shapes and transitions.

### T2. Motion tracking module
- Create frame-diff processor.
- Add throttled update loop (15fps).
- Output smoothed target offset.

### T3. Input handling
- Implement gesture recognizer for tap, long press, stroke.
- Emit BotEvent from gestures.

### T4. State machine engine
- Implement reduce() with explicit transition rules.
- Add timers and probability triggers.
- Add hooks to update rendering and audio on state entry.

### T5. Audio system
- Build clip manager (preload, category routing).
- Implement random selection with exclusion.
- Add debounce and audio enabled/volume controls.

### T6. Settings UI
- Build settings screen layout.
- Bind toggles and sliders to persisted state.
- Implement privacy section with static text.

### T7. Shop UI + IAP wiring
- Build shop screen with remove-ads CTA.
- Implement purchase + restore.
- Add post-purchase reaction.

### T8. Ads in Settings/Shop
- Add banner slot and lifecycle.
- Disable ads when purchase is active.

### T9. Release preparation
- Add permission copy + privacy policy URL placeholders.
- Validate battery/fps throttling behavior.
- Prepare store metadata checklist.

## Platform-Specific Implementation Notes

### iOS (Zylix)
API usage patterns (design-level):
- Camera: use `AVCaptureSession` + `AVCaptureVideoDataOutput` for low-res frames.
  - Configure `sessionPreset = .cif352x288` or `.vga640x480` with downscale.
  - Set `videoOutput.alwaysDiscardsLateVideoFrames = true`.
  - Use `setSampleBufferDelegate(queue:)` and convert to grayscale buffer.
- Permissions: `NSCameraUsageDescription` from D8.1; open Settings via `UIApplication.openSettingsURLString`.
- Audio: `AVAudioEngine` + `AVAudioPlayerNode` for low-latency short clips.
  - Preload clips into `AVAudioPCMBuffer`.
  - Use a shared engine; do not recreate per tap.
- Haptics: `UIImpactFeedbackGenerator(style: .light)` on tap/long press.
- Orientation: set `supportedInterfaceOrientations` to landscape; apply `safeAreaInsets`.
- IAP: StoreKit2 `Product.purchase()`; verify `Transaction`; `Transaction.currentEntitlements` for restore.
- Ads: use a banner view in Settings/Shop only; pin to safe area.
- Background: stop camera and timers in `applicationDidEnterBackground`, resume in `applicationWillEnterForeground`.

### Android (Zylix)
API usage patterns (design-level):
- Camera: use CameraX `ImageAnalysis` use case (no Preview).
  - `setTargetResolution(Size(320, 240))`, `setBackpressureStrategy(STRATEGY_KEEP_ONLY_LATEST)`.
  - Convert `ImageProxy` to grayscale; release frame promptly.
- Permissions: `ActivityResultContracts.RequestPermission`, show rationale with `shouldShowRequestPermissionRationale`.
- Audio: `SoundPool` for short clips; preload on init; manage max streams.
- Haptics: `Vibrator` or `VibratorManager` with short `VibrationEffect`.
- Orientation: set `android:screenOrientation="landscape"`; handle cutouts with `WindowInsets`.
- IAP: Play Billing `BillingClient` purchase flow; `acknowledgePurchase`; `queryPurchasesAsync` for restore.
- Ads: banner in Settings/Shop only; attach/detach on `onStart/onStop`.
- Background: stop analysis in `onPause`, resume in `onResume`.

### watchOS (Zylix)
API usage patterns (design-level):
- Camera: none; disable tracking pipeline entirely.
- Input: `WKTapGestureRecognizer` on full-screen view.
- Haptics: `WKInterfaceDevice.current().play(.click)` or `.notification`.
- Audio: `AVAudioPlayer` if permitted; otherwise skip audio.
- UI: `WKInterfaceGroup` with custom drawing or image sequence.
- Battery: limit tick timers; increase blink intervals (6-10s).

## Test Scenarios (Specification-Level)

### TS1. State transitions
- Start in Idle, tap -> no state change, blink and sound.
- Stroke -> Happy for 1.5s, then return to Idle/Tracking.
- Long press -> Shy for 1.2s, then return.
- 90s no touch -> Sleepy; tap -> Idle.
- Attention tick while Idle -> Attention, then return.

### TS2. Tracking behavior
- Tracking enabled -> eyes follow motion; disabled -> eyes centered.
- No motion for 3s -> target recenters smoothly.
- Low power enabled -> movement slower, fps reduced.

### TS3. Gesture recognition
- Tap within 200ms, <10px movement -> tap event.
- Long press >500ms, <10px movement -> long press event.
- Stroke >20px movement within 500ms -> stroke event.

### TS4. Audio playback
- Rapid taps -> debounce prevents overlapping clips.
- Category randomization avoids same clip repeating consecutively.
- Audio disabled -> no playback.

### TS5. Settings persistence
- Toggle tracking, audio, low power -> persists after restart.
- Volume changes apply immediately and persist.

### TS6. Permissions
- Deny camera -> app still functional with fixed eyes.
- Re-open settings -> enable camera -> tracking resumes.

### TS7. Ads and IAP
- Ads visible only on Settings/Shop.
- Purchase remove-ads -> ads hidden immediately.
- Restore purchase -> ads remain hidden.

### TS8. Background/foreground
- App background -> camera and timers stop.
- App foreground -> timers reset; tracking resumes if enabled.

## Test Checklist (Given/When/Then)

### GWT1. Tap reaction
Given the app is in Idle state and audio is enabled  
When the user taps the face within 200ms and <10px movement  
Then the app plays a tap sound and blinks without changing state

### GWT2. Stroke reaction
Given the app is in Idle state  
When the user strokes >20px within 500ms  
Then the app enters Happy for 1.5s, plays a happy sound, and then returns to Idle/Tracking

### GWT3. Long press reaction
Given the app is in Idle state  
When the user presses for >500ms with <10px movement  
Then the app enters Shy for 1.2s, plays a shy sound, and returns to Idle/Tracking

### GWT4. Sleepy transition
Given the app has no touch input for 90s  
When the IdleTimeout fires  
Then the app enters Sleepy and uses half-open eyes

### GWT5. Wake from Sleepy
Given the app is in Sleepy  
When the user taps  
Then the app returns to Idle/Tracking and blinks once

### GWT6. Attention behavior
Given the app is in Idle or Tracking  
When an AttentionTick occurs and rand < attentionProb  
Then the app enters Attention for 1.0s and plays attention sound

### GWT7. Tracking enabled
Given tracking is enabled  
When motion is detected  
Then the pupil offset follows the EMA-smoothed target

### GWT8. Tracking disabled
Given tracking is disabled  
When motion is detected  
Then the pupils remain centered (0,0)

### GWT9. Low power throttling
Given low power is enabled  
When tracking is active  
Then capture runs at reduced fps/resolution and EMA alpha is 0.10

### GWT10. Audio debounce
Given audio is enabled  
When the user taps rapidly within 250ms  
Then only one clip plays within the debounce window

### GWT11. Permission denied
Given the user denies camera permission  
When the app starts  
Then tracking is off and the face remains responsive to touch

### GWT12. Permission granted later
Given the user previously denied camera permission  
When the user enables camera permission in Settings and returns  
Then tracking resumes automatically if the toggle is on

### GWT13. Ads visibility
Given the user has not purchased remove-ads  
When the user opens Settings or Shop  
Then banner ads are visible

### GWT14. Ads removed
Given the user has purchased remove-ads  
When the user opens Settings or Shop  
Then banner ads are hidden

### GWT15. Restore purchase
Given the user previously purchased remove-ads  
When the user taps Restore  
Then ads remain hidden after restore completes

### GWT16. Background behavior
Given tracking is running  
When the app moves to background  
Then camera capture and timers stop

### GWT17. Foreground behavior
Given the app was backgrounded  
When the app returns to foreground  
Then timers reset and tracking resumes if enabled

## Zylix API Stubs (Interfaces + Example Call Sites)
Design-level API sketches to align Zylix and HeyBot usage before implementation.

### Z1. Camera motion frames
Interface (Zylix core):
```
interface MotionFrameProvider {
  fun start(config: MotionFrameConfig, onFrame: (MotionFrame) -> Unit)
  fun stop()
}

data class MotionFrameConfig(
  val width: Int,
  val height: Int,
  val fps: Int,
  val grayscale: Boolean = true
)

data class MotionFrame(
  val width: Int,
  val height: Int,
  val luma: ByteArray // grayscale buffer
)
```

Example call site (HeyBot app):
```
val camera = Zylix.motionFrameProvider()
camera.start(MotionFrameConfig(320, 240, 15)) { frame ->
  val target = motionTracker.update(frame.luma, frame.width, frame.height)
  eyePose.updateTarget(target.x, target.y)
}
```

### Z2. Audio clip player
Interface (Zylix core):
```
interface AudioClipPlayer {
  fun preload(clips: List<AudioClip>)
  fun play(clipId: String, volume: Float)
  fun stopAll()
}

data class AudioClip(val id: String, val path: String)
```

Example call site:
```
audio.preload(allClips)
if (settings.audioEnabled) {
  audio.play(clipId = pickHappyClip(), volume = settings.volume)
}
```

### Z3. Haptics
Interface (Zylix core):
```
interface Haptics {
  fun pulse(intensity: Float, durationMs: Int)
}
```

Example call site:
```
haptics.pulse(intensity = 0.3f, durationMs = 20)
```

### Z4. Settings store
Interface (Zylix core):
```
interface KeyValueStore {
  fun getBool(key: String, default: Boolean): Boolean
  fun getFloat(key: String, default: Float): Float
  fun putBool(key: String, value: Boolean)
  fun putFloat(key: String, value: Float)
}
```

Example call site:
```
settings.trackingEnabled = store.getBool("trackingEnabled", true)
store.putBool("trackingEnabled", settings.trackingEnabled)
```

### Z5. IAP
Interface (Zylix core):
```
interface Store {
  fun purchase(productId: String, onResult: (PurchaseResult) -> Unit)
  fun restore(onResult: (RestoreResult) -> Unit)
  fun hasEntitlement(productId: String): Boolean
}
```

Example call site:
```
store.purchase("heybot_remove_ads") { result ->
  if (result.success) ads.disable()
}
```

### Z6. Ads
Interface (Zylix core):
```
interface Ads {
  fun showBanner(placementId: String)
  fun hideBanner(placementId: String)
}
```

Example call site:
```
if (!store.hasEntitlement("heybot_remove_ads")) {
  ads.showBanner("settings")
}
```

### Z7. App lifecycle
Interface (Zylix core):
```
interface AppLifecycle {
  fun onForeground(callback: () -> Unit)
  fun onBackground(callback: () -> Unit)
}
```

Example call site:
```
lifecycle.onBackground { camera.stop(); timers.stopAll() }
lifecycle.onForeground { if (settings.trackingEnabled) camera.start(config, onFrame) }
```

## Platform Adapter Notes (Zylix)
Guidance for implementing Zylix adapters on each platform.

### A1. iOS adapter mapping
- MotionFrameProvider:
  - Map to `AVCaptureSession` + `AVCaptureVideoDataOutput`.
  - Ensure `alwaysDiscardsLateVideoFrames = true`.
  - Use a serial queue for frame processing; drop frames if queue is busy.
- AudioClipPlayer:
  - Map to `AVAudioEngine` + `AVAudioPlayerNode` with preloaded `AVAudioPCMBuffer`.
  - Reuse a single engine and keep it running to reduce latency.
- Haptics:
  - Map to `UIImpactFeedbackGenerator` (light) and cache generator.
- KeyValueStore:
  - Map to `UserDefaults`.
- Store:
  - Map to StoreKit2 `Product.purchase()` and `Transaction.currentEntitlements`.
  - Handle `.pending`, `.userCancelled`, and verification failures.
- Ads:
  - Map to banner provider; attach/detach views on view lifecycle events.
- AppLifecycle:
  - Map to app delegate foreground/background notifications.

### A2. Android adapter mapping
- MotionFrameProvider:
  - Map to CameraX `ImageAnalysis` with `STRATEGY_KEEP_ONLY_LATEST`.
  - Ensure `ImageProxy.close()` in all paths.
- AudioClipPlayer:
  - Map to `SoundPool` (short clips) with preloading on init.
  - Limit simultaneous streams to avoid clipping.
- Haptics:
  - Map to `VibratorManager` (API 31+) or `Vibrator` fallback.
- KeyValueStore:
  - Map to `SharedPreferences`.
- Store:
  - Map to Play Billing `BillingClient`; ack purchases.
  - Handle `USER_CANCELED`, `ITEM_ALREADY_OWNED`, and network failures.
- Ads:
  - Map to banner provider with proper lifecycle (attach/detach on start/stop).
- AppLifecycle:
  - Map to Activity/Fragment `onResume/onPause`.

### A3. watchOS adapter mapping
- MotionFrameProvider:
  - Not supported; stub provider returns centered target.
- AudioClipPlayer:
  - Map to `AVAudioPlayer` if permitted; otherwise no-op.
- Haptics:
  - Map to `WKInterfaceDevice.current().play(_)`.
- KeyValueStore:
  - Map to `UserDefaults`.
- Store/Ads:
  - Not used in MVP; implement as no-op or feature-gated.
- AppLifecycle:
  - Map to `WKExtension` lifecycle notifications.

## Error Handling and Edge Cases (Interfaces)

### E1. MotionFrameProvider
- If permission denied: return error and emit no frames; app falls back to non-tracking.
- If camera fails to start: retry once after 1s; then disable tracking with user-visible note.
- If frames are late: drop frames; do not queue.
- If buffer size mismatch: ignore frame and log once.

### E2. AudioClipPlayer
- If audio engine init fails: disable audio and persist setting.
- If clip missing: skip playback and log; do not crash.
- If too many clips requested: enforce debounce window.
- If audio disabled: no-op.

### E3. Haptics
- If device has no haptics: no-op.
- If system haptics disabled: respect system setting.

### E4. KeyValueStore
- If value missing or corrupt: use defaults.
- Avoid blocking IO on main thread when writing large values (not expected here).

### E5. Store (IAP)
- Purchase cancelled: treat as non-error.
- Purchase pending: show gentle status; keep ads enabled.
- Verification failed: do not grant entitlement.
- Restore empty: show "no purchases found".

### E6. Ads
- If ad load fails: hide banner and retry later (e.g., on next screen enter).
- Do not show ads on Face screen under any condition.
- If remove-ads entitlement becomes active: immediately hide banners.

### E7. AppLifecycle
- On background: stop timers and camera; prevent memory leaks.
- On foreground: re-check permissions and tracking toggle before starting camera.

## Interface Contracts (Pre/Postconditions)
Define minimal contracts for Zylix interfaces to reduce ambiguity.

### C1. MotionFrameProvider
- Pre: `start()` called only when app is foregrounded.
- Pre: `MotionFrameConfig` width/height/fps are supported or will be clamped.
- Post: `onFrame` callbacks are serialized (no concurrent calls).
- Post: `stop()` guarantees no further `onFrame` callbacks after return.
- Post: If permission denied, `start()` must return an error or trigger a failure callback.

### C2. AudioClipPlayer
- Pre: `preload()` called before `play()` for a clip id.
- Post: `play()` is non-blocking and returns immediately.
- Post: If clip missing, `play()` is a no-op with a warning.

### C3. Haptics
- Pre: `pulse()` can be called repeatedly; implementation must rate-limit if needed.
- Post: No crash on devices lacking haptics; no-op is acceptable.

### C4. KeyValueStore
- Pre: keys are ASCII, stable, and versioned if schema changes.
- Post: `get*()` returns default if key missing or invalid.

### C5. Store (IAP)
- Pre: `purchase()` only when network is available (best-effort).
- Post: `purchase()` calls result callback exactly once.
- Post: `hasEntitlement()` is safe to call before restore.

### C6. Ads
- Pre: `showBanner()` called on UI thread.
- Post: `hideBanner()` is idempotent.

### C7. AppLifecycle
- Post: foreground/background callbacks are called at most once per transition.

## Logging and Diagnostics Guidance
Keep logs minimal and privacy-safe; use coarse-grained counters only.

### L1. Events to log (local only)
- Camera start/stop success/failure (no frame data).
- Audio clip play failures (missing id).
- IAP purchase/restore outcomes (no user identifiers).
- Ad load failures (error code only).
- Permission denial events.

### L2. Redaction and privacy
- Never log camera frames or derived positions.
- Avoid logging raw touch coordinates; use categorical events (tap/stroke).
- Avoid device identifiers; use session-scoped random IDs if needed.

### L3. Rate limits
- Limit repeated error logs (e.g., once per session for the same code).
- Suppress noisy warnings (e.g., frame drop) unless in debug builds.

### L4. Debug-only diagnostics (optional)
- Overlay FPS and motion target in debug builds only.
- Expose a hidden toggle to dump last 10 state transitions for QA.

## Error Code Taxonomy
Use stable, low-cardinality error codes to support debugging without leaking data.

### EC1. Camera
- CAM_PERMISSION_DENIED
- CAM_START_FAILED
- CAM_FRAME_TIMEOUT
- CAM_FRAME_SIZE_MISMATCH

### EC2. Audio
- AUD_INIT_FAILED
- AUD_CLIP_NOT_FOUND
- AUD_PLAYBACK_FAILED

### EC3. Haptics
- HPT_UNAVAILABLE

### EC4. Store (IAP)
- IAP_NETWORK_UNAVAILABLE
- IAP_USER_CANCELLED
- IAP_PENDING
- IAP_VERIFICATION_FAILED
- IAP_RESTORE_EMPTY

### EC5. Ads
- ADS_LOAD_FAILED
- ADS_PROVIDER_UNAVAILABLE

### EC6. Lifecycle
- LFC_BACKGROUND_START
- LFC_FOREGROUND_START

## Logging Schema (Local Only)
Structured record with fixed fields to keep logs consistent and filterable.

```
{
  "ts": "2025-01-01T12:34:56.000Z",
  "level": "WARN",
  "code": "CAM_START_FAILED",
  "component": "camera",
  "context": {
    "platform": "ios",
    "sessionId": "s-1234",
    "trackingEnabled": true
  }
}
```

Field guidelines:
- ts: ISO-8601 string
- level: INFO/WARN/ERROR
- code: one of Error Code Taxonomy values
- component: camera/audio/haptics/store/ads/lifecycle
- context: small, fixed fields only (no PII)

Context examples:
- camera: platform, trackingEnabled, lowPowerEnabled
- audio: audioEnabled, clipId (short id only)
- store: productId (short id), result
- ads: placementId, errorDomain

## Log Retention and Debug Flags
Guidelines to keep logs minimal and avoid privacy risks.

### LR1. Retention policy
- Logs are in-memory by default.
- If persisted for QA builds, keep at most 24 hours or 200 entries.
- Release builds should not persist logs to disk.

### LR2. Debug flags
- `DEBUG_OVERLAY`: show FPS and tracking target.
- `DEBUG_STATE_TRACE`: store last 10 state transitions.
- `DEBUG_VERBOSE_LOGS`: enable detailed error logs (still no PII).

### LR3. Exposure
- Debug flags are only available in development builds.
- Never expose debug toggles in production UI.

## QA Workflow (Lightweight)
Minimal process to validate behavior before release.

### QA1. Pre-merge checklist
- All GWT tests for state transitions pass.
- Camera tracking works on at least 2 devices (low-end + mid/high).
- Low power mode reduces FPS/resolution and keeps UI responsive.
- Audio playback works with debounce; no overlapping clips.
- Settings persist after restart.
- Ads visible only in Settings/Shop; Face remains clean.
- Purchase/restore flow verified in sandbox.

### QA2. Device matrix (suggested)
- iOS: 1 older device + 1 current device
- Android: 1 low-end + 1 mid/high device
- watchOS: 1 recent watch (if watch app enabled)

### QA3. Pre-release sanity run (10 min)
- Launch app, verify Idle behavior.
- Test tap/stroke/long press reactions.
- Toggle tracking and confirm eye behavior changes.
- Deny and allow camera permission flows.
- Background/foreground transitions.
- Open Settings and Shop; verify ads visibility rules.

## Store Submission Checklist (MVP)
Quick checklist for app review readiness.

### SS1. Privacy and permissions
- Camera usage text matches D8.1.
- In-app privacy section present.
- No camera data stored or transmitted.
- Ads are non-tracking by default.

### SS2. UX and stability
- No ads on Face screen.
- App usable without camera permission.
- Offline functionality verified (no network dependency).
- Battery/thermal throttling in effect.

### SS3. Metadata
- App description emphasizes playful/relaxing use case.
- Screenshots show Face, Settings, Shop.
- Privacy policy URL prepared.

## Release Gate Template
Use this for weekly release decisions.

### RG1. Must-pass criteria
- No crashes in the last QA run.
- All GWT tests for state transitions pass.
- Camera permission denial path is usable.
- Ads are not present on Face screen.
- IAP purchase + restore works in sandbox.
- Battery/thermal throttling verified on at least one device.

### RG2. Nice-to-have criteria
- Motion tracking stable under low light.
- Audio latency feels acceptable (<150ms subjective).
- No visual glitches on notch/cutout devices.

### RG3. Go/No-Go decision
- Go if all Must-pass criteria are green.
- If any Must-pass fails, delay release and log a blocking issue.

## Zylix Feedback Issue Template
Use this format when reporting missing Zylix features.

```
Title: [HeyBot] <short feature need>

Context:
- Where in HeyBot this is needed:
- User-facing impact:
- Current workaround (if any):

Proposed API:
// Pseudocode interface

Acceptance criteria:
- [ ] Behavior on iOS
- [ ] Behavior on Android
- [ ] Behavior on watchOS (if applicable)

Notes:
- Perf constraints:
- Privacy considerations:
```

## Weekly Planning Ritual
Lightweight routine to keep scope tight and feedback flowing.

### WP1. Monday (Planning)
- Review last week's release gate outcomes.
- Pick 1-2 focus items (no more than 3 changes).
- Update Zylix gap list and open issues as needed.

### WP2. Midweek (Checkpoint)
- Verify core behaviors still pass GWT tests.
- Adjust scope if Zylix changes are blocked.
- Re-evaluate power/thermal results if tracking was touched.

### WP3. Friday (Release decision)
- Run QA checklist and decide Go/No-Go.
- Record regressions and roll into next week.
- Prepare store notes if release is Go.

## Backlog Template (Structured)
Use this format to keep HeyBot tasks small and reviewable.

```
Title: [HeyBot] <task name>

Goal:
- User-visible outcome

Scope:
- In scope
- Out of scope

Dependencies:
- Zylix APIs or platform requirements

Acceptance Criteria:
- [ ] GWT test references
- [ ] QA checklist references

Risks:
- Battery/thermal
- Review/permissions
```

## Risk Register (Format)
Use this to track major risks and mitigations.

```
ID: R-###
Risk: <short description>
Impact: Low/Medium/High
Likelihood: Low/Medium/High
Mitigation:
- <action>
Owner:
Status: Open/Mitigated/Closed
```

## Definition of Ready (DoR)
Checklist before pulling a task into active work.

### DR1. Requirements
- User outcome is clear and testable.
- Scope boundaries are explicit.

### DR2. Dependencies
- Zylix APIs identified and available (or issue filed).
- Platform constraints noted (iOS/Android/watchOS).

### DR3. QA and review
- GWT tests mapped or to be added.
- Store review implications checked (privacy/permissions).

## Definition of Done (DoD)
Checklist for completing a HeyBot task or milestone.

### DD1. Functionality
- Feature works on target platforms (iOS/Android/watchOS where applicable).
- No crashes or degraded core behavior.

### DD2. QA
- Relevant GWT tests pass.
- QA checklist items completed.

### DD3. Performance
- No significant battery/thermal regression.
- Tracking FPS and resolution within expected limits.

### DD4. Compliance
- Privacy and permission text updated if needed.
- Ads placement rules followed.

## Stability and UX Metrics (Lightweight)
Non-PII indicators to judge health and user experience.

### M1. Stability
- Crash-free sessions (local QA): target 100%.
- Camera start failure rate (local QA): target < 2%.

### M2. UX
- Average reaction latency (subjective): feels <150ms.
- Visual stutter in tracking: minimal under normal lighting.

### M3. Power
- Low power mode reduces FPS and resolution as configured.
- Background stops camera within 1s.

## Release Notes Template
Use for weekly updates and store submission notes.

```
Version: <x.y.z>
Date: <YYYY-MM-DD>

Highlights:
- <1-3 bullet points>

Fixes:
- <bug fixes>

Notes:
- <store or review notes>
```

## Incident Response (Mini-Playbook)
Lightweight steps if a critical issue appears.

### IR1. Triage
- Reproduce on at least one device.
- Identify scope (platform, version, frequency).
- Decide if hotfix is required.

### IR2. Mitigation
- Disable affected feature if possible (e.g., tracking or ads).
- Prepare a small patch and verify with QA checklist.

### IR3. Communication
- Record incident summary in release notes.
- If store review impacted, prepare a brief explanation.

## Security and Privacy Checklist
Minimal checks to avoid review or policy issues.

### SP1. Camera usage
- Camera used only for motion detection.
- No storage, no upload, no background capture.
- Permission rationale matches D8.1.

### SP2. Audio
- No microphone access requested.
- Audio assets are bundled and offline.

### SP3. Ads
- Ads are non-tracking.
- Ads SDKs are declared in privacy policy if used.

### SP4. Data
- No analytics with device identifiers.
- Logs do not contain sensitive data.

## Performance Profiling Checklist
Quick checks before release.

### PF1. Tracking
- FPS within target range (default 15, low power 8).
- Motion pipeline drops frames gracefully under load.

### PF2. Rendering
- No frame drops during idle animations.
- Eye/mouth animations stay within target durations.

### PF3. Battery/Thermal
- Low power mode reduces CPU usage measurably.
- App stops camera within 1s on background.

## Localization Checklist
Keep early localization simple and compliant.

### LC1. UI text
- All user-facing strings are externalized.
- JP/EN are default languages.
- Camera permission rationale localized.

### LC2. Store metadata
- App description localized for JP/EN.
- Screenshots with localized captions.

### LC3. Audio
- Text-based captions for reactions in Settings/Help (optional).

## Asset Pipeline Guidelines
Keep assets small, versioned, and auditable.

### AP1. Audio assets
- Clip naming: `happy_01.wav`, `shy_02.wav` etc.
- Store under `assets/audio/` (bundle location per platform).
- Keep clips normalized and short (<1.2s).

### AP2. Visual assets
- Eye/mouth shapes as vector or high-res PNGs.
- Use a single color palette file for theming.

### AP3. Versioning
- Track asset changes in release notes.
- Add new packs as separate folders for easy toggling.

## Design Tokens (Initial Proposal)
Keep a small, explicit token set to avoid ad-hoc values.

### DT1. Colors
- background.primary: #0E1116
- background.secondary: #1A1F2A
- eye.white: #F5F7FB
- eye.pupil: #0B0E13
- eye.highlight: #FFFFFF
- mouth.primary: #EDE1D0
- accent.heart: #F07A8B

### DT2. Sizes
- eye.radius: 120
- pupil.radius: 42
- mouth.width: 140
- mouth.height: 36
- icon.size: 28

### DT3. Motion
- blink.duration.ms: 120
- state.tween.ms: 200
- mouth.tween.ms: 150
- tracking.ema.alpha: 0.15

## Theme Variants (Proposal)
Small variations that can be introduced without new logic.

### TV1. Classic Dark (default)
- background.primary: #0E1116
- background.secondary: #1A1F2A
- eye.white: #F5F7FB
- eye.pupil: #0B0E13
- mouth.primary: #EDE1D0
- accent.heart: #F07A8B

### TV2. Soft Mint
- background.primary: #0B1413
- background.secondary: #15302A
- eye.white: #F2FAF8
- eye.pupil: #0B0E13
- mouth.primary: #DDEEE8
- accent.heart: #7FD1B9

### TV3. Sunset Warm
- background.primary: #1C0F12
- background.secondary: #3A1E24
- eye.white: #FFF1E8
- eye.pupil: #1A0D10
- mouth.primary: #F4D9C7
- accent.heart: #F28C7A

## Theme Selection UI Spec
How to present theme options in Settings without expanding scope.

### TSU1. Placement
- Settings: add a "Theme" row below Audio.
- Tapping opens a simple modal/list with 3 options.

### TSU2. Behavior
- Selection applies immediately on Face screen.
- Persist selection in settings store.
- Default to Classic Dark.

### TSU3. UI elements
- Each theme shows a small preview swatch (background + eye color).
- Only one selection allowed (radio list).

### TSU4. Accessibility
- Ensure contrast ratio for eye white and mouth remains readable.

## Theme Animation Notes
Optional adjustments per theme (keep logic identical).

### TAN1. Classic Dark
- Blink duration: 120ms (default).
- EMA alpha: 0.15 (default).

### TAN2. Soft Mint
- Blink duration: 140ms (softer feel).
- EMA alpha: 0.13 (slightly smoother).

### TAN3. Sunset Warm
- Blink duration: 110ms (snappier).
- EMA alpha: 0.16 (slightly more responsive).

## Theme Asset Requirements
Keep asset needs minimal and consistent across themes.

### TAR1. Required assets
- Background gradient or solid color (token-based).
- Eye white + pupil color (token-based).
- Mouth color (token-based).
- Icon color (token-based).

### TAR2. Optional assets
- Subtle noise texture (low alpha) for background.
- Tiny sparkle overlay for eyes (Happy state only).

### TAR3. Constraints
- Avoid large bitmap sizes; prefer vector shapes or procedural drawing.
- Keep total theme asset size under 1 MB.

## Settings Screen Wireframe Notes
Minimal UI to keep scope small and review-friendly.

### SW1. Sections order
1) Audio (toggle + volume)
2) Tracking (toggle + sensitivity)
3) Low power (toggle)
4) Theme (selector)
5) Privacy (static text)
6) Help (FAQ, permission help)
7) Shop (remove ads CTA)

### SW2. Layout rules
- Use a simple vertical list.
- Toggles right-aligned.
- Sliders full width below row label.
- Banner ad at bottom (Settings only).

### SW3. Navigation
- Gear icon from Face opens Settings.
- Back button returns to Face (no nested navigation).

## Shop Screen Wireframe Notes
Keep purchase flow simple and review-safe.

### SH1. Layout
- Title: "Remove Ads"
- Short description (1-2 lines)
- Primary button: "Purchase"
- Secondary button: "Restore"
- Footer note: "Ads never appear on the Face screen."

### SH2. Behavior
- Purchase success -> hide ads immediately + thank-you reaction.
- Purchase cancel -> no change.
- Restore success -> hide ads.
- Loading state while purchase/restore in progress.

### SH3. Banner ads
- If ads are enabled, banner appears at bottom.
- Hide banner after remove-ads entitlement is active.

## Audio Clip Naming and Load Order
Define a simple, deterministic scheme to avoid duplicates and confusion.

### AC1. Naming
- Format: `<category>_<nn>.wav`
- Categories: happy, shy, attention, tap
- Example: `happy_01.wav`, `tap_03.wav`

### AC2. Load order
- Load in lexical order per category.
- Preload on app start; if memory pressure, defer less-used categories.

### AC3. Selection rules
- Randomize within category.
- Avoid repeating the last 2 clips.

## Face Screen Wireframe Notes
Primary experience layout notes for the main screen.

### FW1. Layout
- Fullscreen landscape only.
- Eyes centered horizontally; mouth below eyes by 24-36px.
- Settings icon top-right; Shop icon bottom-right.
- Heart icon indicates remove-ads in Shop entry point.

### FW2. Interaction zones
- Entire face area captures tap/stroke/long press.
- Icons have higher priority; taps on icons do not trigger gestures.

### FW3. Idle visuals
- Slow blink (3-6s cadence).
- Subtle eye drift (small amplitude) when tracking off.

## Gesture Tuning Parameters
Keep values centralized for easy adjustment.

### GT1. Thresholds
- Tap: max duration 200ms, movement < 10px
- Long press: min duration 500ms, movement < 10px
- Stroke: movement > 20px within 500ms

### GT2. Timing
- Gesture evaluation window: 500ms
- Long press start: 500ms

## State-Driven Animation Curves
Define easing per state entry to keep motion consistent.

### SAC1. Easing presets
- idle: cubic-out
- happy: elastic-out (subtle)
- shy: cubic-in-out
- sleepy: quadratic-out
- attention: back-out (tiny overshoot)

### SAC2. Application
- Apply easing to eye offset and mouth pose transitions.
- Keep blink easing separate (sin curve).

## Touch Handling Edge Cases
Clarify behavior when gestures overlap or conflict.

### TE1. Tap vs long press
- If duration exceeds 500ms, emit long press only (no tap).

### TE2. Stroke vs tap
- If movement exceeds 20px, emit stroke and suppress tap.

### TE3. Multi-touch
- Ignore secondary touches; only track the first pointer.

### TE4. Interrupted gestures
- If touch is cancelled (app background), emit no event.

## State Entry/Exit Hooks
Standardize side-effects to avoid scattered logic.

### SE1. Entry actions
- Idle: set default eye/mouth pose; schedule blink.
- Tracking: enable tracking pipeline; keep Idle pose.
- Happy: play happy audio; sparkle eyes.
- Shy: play shy audio; small mouth; eyes down.
- Sleepy: reduce blink rate; half-open eyes.
- Attention: play attention audio; eyes wide.

### SE2. Exit actions
- Happy/Shy/Attention: restore previous pose baseline.
- Sleepy: restore normal blink cadence.
- Any: cancel state-specific timers on exit.

### SE3. Transition utilities
- `enterState(state)` handles pose tween and audio routing.
- `exitState(state)` handles cleanup and timer cancel.

## Visual Regression Checklist
Quick checks to catch UI breaks.

### VR1. Face screen
- Eyes centered and symmetric.
- Pupil stays within eye bounds.
- Mouth aligned under eyes.
- Icons in top-right/bottom-right and visible.

### VR2. Settings screen
- Toggles and sliders align properly.
- Theme selector shows selection.
- Banner ad (if enabled) does not overlap content.

### VR3. Shop screen
- Purchase and restore buttons visible.
- Banner ad hidden when remove-ads active.

## Audio Routing Rules
Keep audio behavior consistent and calm.

### AR1. Priority
- Attention > Happy > Shy > Tap
- Higher priority interrupts lower priority within 150ms window.

### AR2. Debounce
- Minimum 250ms between clips (global).
- If a clip is playing, allow only higher priority to preempt.

### AR3. Volume
- Master volume from settings.
- Cap maximum volume to avoid harshness.

## Performance Budgets
Targets to prevent regressions.

### PB1. CPU
- Motion tracking processing < 3ms per frame (target).
- Rendering < 8ms per frame on mid-tier devices.

### PB2. Memory
- Audio clips total < 10MB.
- Total assets < 20MB for MVP.

### PB3. Battery
- Tracking mode should not exceed moderate usage; low power reduces usage by ~30%.

## Memory Pressure Behavior
Rules to keep the app responsive on low-memory devices.

### MP1. Audio
- If memory warning: unload least-used audio category (e.g., Attention).
- Reload on demand when memory recovers (or on next app launch).

### MP2. Rendering
- Reduce background effects (disable noise texture).
- Lower any offscreen buffer sizes if used.

### MP3. Tracking
- Reduce resolution to 160x120 and fps to 8.
- Increase EMA smoothing to 0.10.

## Low Light and Exposure Fallback
Behavior when camera frames are too dark to detect motion.

### LL1. Detection
- Track average luma; if below threshold for 3s, consider low light.

### LL2. Response
- Display a subtle hint in Settings: "Low light may reduce tracking."
- Keep eyes centered and enable subtle idle drift.
- Do not prompt for camera permission again.

## Startup and Shutdown Sequence
Define a consistent boot/shutdown flow to avoid race conditions.

### SSQ1. Startup
- Load settings from KeyValueStore.
- Apply theme tokens and layout.
- Initialize audio engine and preload clips.
- Initialize state machine (Idle).
- If tracking enabled and permission granted: start camera.
- Start timers (blink, attention, idle timeout).

### SSQ2. Shutdown / background
- Stop camera capture.
- Stop timers.
- Flush any pending state transitions.
- Do not persist logs in release builds.

## App Launch Performance Checklist
Keep launch fast and avoid blocking the UI thread.

### AL1. Budget
- Target cold start < 2s on mid-tier devices.

### AL2. Practices
- Defer audio preload if it blocks startup; load after first frame.
- Avoid heavy asset decoding on main thread.
- Delay ad SDK init until Settings/Shop open.

## Background Task Policy
Keep background behavior minimal for review safety.

### BP1. Rules
- Do not process camera frames in background.
- Do not play audio in background.
- Do not schedule background work for tracking.

### BP2. Lifecycle hooks
- On background: stop camera, audio, and timers immediately.
- On foreground: restart only if user enabled tracking/audio.

## A/B Testing (Disabled by Default)
Documented as future scope, not active for MVP.

### AB1. Current stance
- No A/B testing in MVP.
- No remote config for behavior changes.

### AB2. Future notes
- If introduced, must be non-tracking and local-only.
- All variants must pass the same privacy and ad rules.

## Store Review Risk Checklist
Quick scan for common rejection risks.

### SR1. Privacy
- Camera usage is clearly explained in-app and in store listing.
- No face recognition or biometric claims.
- No data collection without disclosure.

### SR2. Ads and IAP
- Ads are not primary function and do not block core use.
- Remove-ads IAP works and restores correctly.
- No misleading UI around purchases.

### SR3. Content and UX
- App delivers a consistent experience even offline.
- No hidden/locked core features without purchase.
- Crash-free in basic flows.

## Permission Prompt UX Flow
Describe how permission requests are presented.

### PP1. First launch
- Show an in-app explanation screen before OS prompt.
- If user agrees, trigger OS camera permission.

### PP2. Denial path
- Show a one-time hint: "Enable camera in Settings to enable tracking."
- Provide a Settings button.

### PP3. Subsequent launches
- Do not auto-prompt; rely on Settings toggle.

## Voice Clip Inventory Template
Use to track bundled audio clips.

```
Category: Happy
- happy_01.wav (0.6s)
- happy_02.wav (0.8s)

Category: Shy
- shy_01.wav (0.5s)
- shy_02.wav (0.7s)

Category: Attention
- attention_01.wav (0.4s)
- attention_02.wav (0.6s)
```

## Zylix Feature Gap Tracker (Template)
Use this table as a recurring update point when you find missing Zylix features.

| Area | Need | Current Status | Proposed Zylix API | Priority |
| --- | --- | --- | --- | --- |
| Camera | Motion-only frame access | Unknown | MotionFrameProvider | High |
| Audio | Low-latency clip playback | Unknown | AudioClipPlayer | High |
| Haptics | Light tap feedback | Unknown | Haptics.pulse | Medium |
| IAP | Unified purchase flow | Unknown | Store.purchase | High |
| Ads | Provider-agnostic banner | Unknown | Ads.banner | Medium |

## Risk Notes
- Camera usage needs explicit, friendly explanation for store review.
- Eye tracking must be motion-based only to avoid biometric concerns.
- Audio should be bundled to avoid network and latency issues.
- Ad placement must not reduce core experience.

## Next Iteration Questions
- What exact minimum UI style do we want (flat, gradient, or subtle texture)?
- Do we allow vertical orientation on phones or enforce landscape only?
- What default sensitivity values feel best on typical devices?
- Do we want a daily or weekly novelty behavior (very light)?
