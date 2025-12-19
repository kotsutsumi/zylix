//! Zylix WASM Entry Point
//!
//! WebAssembly-specific module that adds WASM-specific utilities.
//! Core C ABI functions are exported from abi.zig.
//!
//! ZigDom Philosophy:
//! - Zig handles all computation (state, math, GPU data)
//! - JavaScript handles I/O (DOM, WebGPU API calls)

const std = @import("std");
const state = @import("state.zig");
const gpu = @import("gpu.zig");
const particles = @import("particles.zig");
const scheduler = @import("scheduler.zig");
const llm = @import("llm.zig");

// Import abi module to trigger its comptime exports
const abi = @import("abi.zig");

// Force abi module to be included in compilation
comptime {
    _ = abi;
}

// === WASM-specific utilities ===

/// Get current counter value (convenience function for JS)
export fn zylix_wasm_get_counter() i64 {
    if (!state.isInitialized()) return 0;
    return state.getAppState().counter;
}

/// Get pointer to counter value for direct memory access from JS
export fn zylix_wasm_get_counter_ptr() ?*const i64 {
    if (!state.isInitialized()) return null;
    return &state.getAppState().counter;
}

/// Allocate memory in WASM linear memory (for JS to pass data)
export fn zylix_wasm_alloc(size: usize) ?[*]u8 {
    const arena = state.getScratchArena();
    if (arena.alloc(u8, size)) |slice| {
        return slice.ptr;
    }
    return null;
}

/// Free/reset scratch memory
export fn zylix_wasm_free_scratch() void {
    state.resetScratchArena();
}

/// Get memory info for debugging
export fn zylix_wasm_memory_used() usize {
    return state.getScratchArena().used();
}

/// Get memory peak for debugging
export fn zylix_wasm_memory_peak() usize {
    return state.getScratchArena().peak;
}

// === ZigDom GPU exports ===

/// Initialize GPU resources
export fn zigdom_gpu_init() void {
    gpu.init();
}

/// Deinitialize GPU resources
export fn zigdom_gpu_deinit() void {
    gpu.deinit();
}

/// Update GPU state (call each frame with delta time in seconds)
export fn zigdom_gpu_update(delta_time: f32) void {
    gpu.update(delta_time);
}

/// Set aspect ratio for projection matrix
export fn zigdom_gpu_set_aspect(aspect: f32) void {
    gpu.setAspectRatio(aspect);
}

/// Get pointer to vertex buffer (for GPU upload)
export fn zigdom_gpu_get_vertex_buffer() ?*const anyopaque {
    return @ptrCast(gpu.getVertexBuffer());
}

/// Get vertex buffer size in bytes
export fn zigdom_gpu_get_vertex_buffer_size() usize {
    return gpu.getVertexBufferSize();
}

/// Get pointer to uniform buffer (for GPU upload)
export fn zigdom_gpu_get_uniform_buffer() ?*const anyopaque {
    return @ptrCast(gpu.getUniformBuffer());
}

/// Get uniform buffer size in bytes
export fn zigdom_gpu_get_uniform_buffer_size() usize {
    return gpu.getUniformBufferSize();
}

/// Get vertex count for draw call
export fn zigdom_gpu_get_vertex_count() u32 {
    return gpu.getVertexCount();
}

// === ZigDom Particle System exports ===

/// Initialize particle system with count
export fn zigdom_particles_init(count: u32) void {
    particles.init(@intCast(count));
}

/// Deinitialize particle system
export fn zigdom_particles_deinit() void {
    particles.deinit();
}

/// Reset particles to initial state
export fn zigdom_particles_reset() void {
    particles.reset();
}

/// Update simulation time
export fn zigdom_particles_update_time(delta: f32) void {
    particles.updateTime(delta);
}

/// Set gravity
export fn zigdom_particles_set_gravity(x: f32, y: f32) void {
    particles.setGravity(x, y);
}

/// Set mouse interaction
export fn zigdom_particles_set_mouse(x: f32, y: f32, strength: f32) void {
    particles.setMouse(x, y, strength);
}

/// Get particle buffer pointer
export fn zigdom_particles_get_buffer() ?*const anyopaque {
    return @ptrCast(particles.getParticleBuffer());
}

/// Get particle buffer size in bytes
export fn zigdom_particles_get_buffer_size() usize {
    return particles.getParticleBufferSize();
}

/// Get simulation params pointer
export fn zigdom_particles_get_params() ?*const anyopaque {
    return @ptrCast(particles.getSimParams());
}

/// Get simulation params size
export fn zigdom_particles_get_params_size() usize {
    return particles.getSimParamsSize();
}

/// Get particle count
export fn zigdom_particles_get_count() u32 {
    return particles.getParticleCount();
}

/// Apply fountain preset
export fn zigdom_particles_preset_fountain() void {
    particles.fountainPreset();
}

/// Apply explosion preset
export fn zigdom_particles_preset_explosion() void {
    particles.explosionPreset();
}

/// Apply rain preset
export fn zigdom_particles_preset_rain() void {
    particles.rainPreset();
}

// === ZigDom Scheduler exports ===

/// Initialize scheduler
export fn zigdom_scheduler_init() void {
    scheduler.init();
}

/// Deinitialize scheduler
export fn zigdom_scheduler_deinit() void {
    scheduler.deinit();
}

/// Reset scheduler (clear all tasks)
export fn zigdom_scheduler_reset() void {
    scheduler.reset();
}

/// Update scheduler (call every frame with delta time in seconds)
export fn zigdom_scheduler_update(delta_time: f32) void {
    scheduler.update(delta_time);
}

/// Pause the scheduler
export fn zigdom_scheduler_pause() void {
    scheduler.pause();
}

/// Resume the scheduler
export fn zigdom_scheduler_resume() void {
    scheduler.resume_();
}

/// Check if paused
export fn zigdom_scheduler_is_paused() bool {
    return scheduler.isPaused();
}

/// Set time scale (1.0 = normal)
export fn zigdom_scheduler_set_time_scale(scale: f32) void {
    scheduler.setTimeScale(scale);
}

/// Get time scale
export fn zigdom_scheduler_get_time_scale() f32 {
    return scheduler.getTimeScale();
}

/// Cancel a task by ID
export fn zigdom_scheduler_cancel(task_id: u32) bool {
    return scheduler.cancel(task_id);
}

/// Check if task is active
export fn zigdom_scheduler_is_active(task_id: u32) bool {
    return scheduler.isActive(task_id);
}

/// Get remaining time for a task
export fn zigdom_scheduler_get_remaining_time(task_id: u32) f32 {
    return scheduler.getRemainingTime(task_id);
}

/// Get active task count
export fn zigdom_scheduler_get_active_count() u32 {
    return scheduler.getActiveTaskCount();
}

/// Get total elapsed time
export fn zigdom_scheduler_get_total_time() f32 {
    return scheduler.getTotalTime();
}

/// Get current frame number
export fn zigdom_scheduler_get_frame_number() u64 {
    return scheduler.getFrameNumber();
}

/// Get scheduler stats pointer
export fn zigdom_scheduler_get_stats() ?*const anyopaque {
    return @ptrCast(scheduler.getStats());
}

/// Get scheduler stats size
export fn zigdom_scheduler_get_stats_size() usize {
    return @sizeOf(scheduler.SchedulerStats);
}

// === WASM Timer API (event-based for JS interop) ===

/// Initialize WASM timer system
export fn zigdom_timer_init() void {
    scheduler.initWasmTimers();
}

/// Create a one-shot timer (returns task ID)
/// tag: JS callback identifier
export fn zigdom_timer_create(delay_seconds: f32, tag: u32) u32 {
    return scheduler.createWasmTimer(delay_seconds, tag);
}

/// Create a repeating interval timer
export fn zigdom_timer_create_interval(interval_seconds: f32, tag: u32) u32 {
    return scheduler.createWasmInterval(interval_seconds, tag);
}

/// Cancel a timer by ID
export fn zigdom_timer_cancel(task_id: u32) bool {
    return scheduler.cancelWasmTimer(task_id);
}

/// Update timers (call every frame)
export fn zigdom_timer_update(delta_time: f32) void {
    scheduler.updateWasmTimers(delta_time);
}

/// Get number of pending timer events
export fn zigdom_timer_get_event_count() u32 {
    return scheduler.getEventCount();
}

/// Pop next timer event (returns tag, 0 if no events)
/// Use this to check which timers fired
export fn zigdom_timer_pop_event_tag() u32 {
    if (scheduler.popEvent()) |event| {
        return event.tag;
    }
    return 0;
}

/// Get event buffer pointer (for direct memory access)
export fn zigdom_timer_get_event_buffer() ?*const anyopaque {
    return @ptrCast(scheduler.getEventBuffer());
}

/// Get event buffer size
export fn zigdom_timer_get_event_buffer_size() usize {
    return scheduler.getEventBufferSize();
}

/// Get single event size
export fn zigdom_timer_get_event_size() usize {
    return scheduler.getEventSize();
}

// === ZigDom LLM Integration ===

/// Initialize LLM module
export fn zigdom_llm_init() void {
    llm.init();
}

/// Deinitialize LLM module
export fn zigdom_llm_deinit() void {
    llm.deinit();
}

/// Clear conversation (keep system prompt)
export fn zigdom_llm_clear_conversation() void {
    llm.clearConversation();
}

/// Reset everything
export fn zigdom_llm_reset() void {
    llm.reset();
}

/// Set system prompt
export fn zigdom_llm_set_system_prompt(ptr: [*]const u8, len: usize) void {
    llm.setSystemPrompt(ptr[0..len]);
}

/// Add user message
export fn zigdom_llm_add_user_message(ptr: [*]const u8, len: usize) bool {
    return llm.addUserMessage(ptr[0..len]);
}

/// Add assistant message
export fn zigdom_llm_add_assistant_message(ptr: [*]const u8, len: usize) bool {
    return llm.addAssistantMessage(ptr[0..len]);
}

/// Get message count
export fn zigdom_llm_get_message_count() u32 {
    return llm.getMessageCount();
}

/// Get messages buffer pointer
export fn zigdom_llm_get_messages_buffer() ?*const anyopaque {
    return @ptrCast(llm.getMessagesBuffer());
}

/// Get single message size
export fn zigdom_llm_get_message_size() usize {
    return @sizeOf(llm.Message);
}

/// Set model name
export fn zigdom_llm_set_model(ptr: [*]const u8, len: usize) void {
    llm.setModel(ptr[0..len]);
}

/// Set temperature
export fn zigdom_llm_set_temperature(temp: f32) void {
    llm.setTemperature(temp);
}

/// Set max tokens
export fn zigdom_llm_set_max_tokens(max: u32) void {
    llm.setMaxTokens(max);
}

/// Enable/disable streaming
export fn zigdom_llm_set_streaming(enabled: bool) void {
    llm.setStreaming(enabled);
}

/// Get config pointer
export fn zigdom_llm_get_config() ?*const anyopaque {
    return @ptrCast(llm.getConfig());
}

/// Get config size
export fn zigdom_llm_get_config_size() usize {
    return llm.getConfigSize();
}

/// Begin request (mark as pending)
export fn zigdom_llm_begin_request() void {
    llm.beginRequest();
}

/// Begin streaming
export fn zigdom_llm_begin_streaming() void {
    llm.beginStreaming();
}

/// Push stream chunk
export fn zigdom_llm_push_stream_chunk(ptr: [*]const u8, len: usize, index: u32, is_final: bool, reason: u8) void {
    llm.pushStreamChunk(ptr[0..len], index, is_final, @enumFromInt(reason));
}

/// Get stream chunk count
export fn zigdom_llm_get_stream_chunk_count() u32 {
    return llm.getStreamChunkCount();
}

/// Pop stream chunk content (returns length, writes to provided buffer)
export fn zigdom_llm_pop_stream_chunk(out_ptr: [*]u8, out_len: usize) u32 {
    if (llm.popStreamChunk()) |chunk| {
        const copy_len = @min(chunk.content_len, out_len);
        @memcpy(out_ptr[0..copy_len], chunk.content[0..copy_len]);
        return chunk.content_len;
    }
    return 0;
}

/// Complete request with response
export fn zigdom_llm_complete_request(ptr: [*]const u8, len: usize, prompt_tokens: u32, completion_tokens: u32, reason: u8) void {
    llm.completeRequest(ptr[0..len], prompt_tokens, completion_tokens, @enumFromInt(reason));
}

/// Fail request with error
export fn zigdom_llm_fail_request(ptr: [*]const u8, len: usize) void {
    llm.failRequest(ptr[0..len]);
}

/// Cancel request
export fn zigdom_llm_cancel_request() void {
    llm.cancelRequest();
}

/// Get stats pointer
export fn zigdom_llm_get_stats() ?*const anyopaque {
    return @ptrCast(llm.getStats());
}

/// Get stats size
export fn zigdom_llm_get_stats_size() usize {
    return llm.getStatsSize();
}

/// Get context token estimate
export fn zigdom_llm_get_context_tokens() u32 {
    return llm.getContextTokens();
}

/// Estimate tokens for text
export fn zigdom_llm_estimate_tokens(ptr: [*]const u8, len: usize) u32 {
    return llm.estimateTokens(ptr[0..len]);
}

/// Register a tool
export fn zigdom_llm_register_tool(name_ptr: [*]const u8, name_len: usize, desc_ptr: [*]const u8, desc_len: usize, schema_ptr: [*]const u8, schema_len: usize) bool {
    return llm.registerTool(name_ptr[0..name_len], desc_ptr[0..desc_len], schema_ptr[0..schema_len]);
}

/// Get tool count
export fn zigdom_llm_get_tool_count() u32 {
    return llm.getToolCount();
}

// === Panic handler for WASM ===

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = msg;
    @trap();
}
