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
const css = @import("css.zig");
const layout = @import("layout.zig");

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

// === ZigDom CSS Utility System ===

/// Initialize CSS module
export fn zigdom_css_init() void {
    css.init();
}

/// Create a new style (returns style ID)
export fn zigdom_css_create_style() u32 {
    return css.createStyle();
}

/// Get style pointer for direct manipulation
export fn zigdom_css_get_style_ptr(id: u32) ?*anyopaque {
    return @ptrCast(css.getStylePtr(id));
}

/// Set style display property
export fn zigdom_css_set_display(id: u32, display: u8) void {
    if (css.getStylePtr(id)) |style| {
        style.display = @enumFromInt(display);
    }
}

/// Set flex direction
export fn zigdom_css_set_flex_direction(id: u32, direction: u8) void {
    if (css.getStylePtr(id)) |style| {
        style.flex_direction = @enumFromInt(direction);
    }
}

/// Set justify content
export fn zigdom_css_set_justify_content(id: u32, justify: u8) void {
    if (css.getStylePtr(id)) |style| {
        style.justify_content = @enumFromInt(justify);
    }
}

/// Set align items
export fn zigdom_css_set_align_items(id: u32, align_val: u8) void {
    if (css.getStylePtr(id)) |style| {
        style.align_items = @enumFromInt(align_val);
    }
}

/// Set gap
export fn zigdom_css_set_gap(id: u32, gap: u8) void {
    if (css.getStylePtr(id)) |style| {
        style.gap = @enumFromInt(gap);
    }
}

/// Set padding (all sides)
export fn zigdom_css_set_padding(id: u32, top: u8, right: u8, bottom: u8, left: u8) void {
    if (css.getStylePtr(id)) |style| {
        style.padding_top = @enumFromInt(top);
        style.padding_right = @enumFromInt(right);
        style.padding_bottom = @enumFromInt(bottom);
        style.padding_left = @enumFromInt(left);
    }
}

/// Set margin (all sides)
export fn zigdom_css_set_margin(id: u32, top: u8, right: u8, bottom: u8, left: u8) void {
    if (css.getStylePtr(id)) |style| {
        style.margin_top = @enumFromInt(top);
        style.margin_right = @enumFromInt(right);
        style.margin_bottom = @enumFromInt(bottom);
        style.margin_left = @enumFromInt(left);
    }
}

/// Set background color
export fn zigdom_css_set_bg_color(id: u32, r: u8, g: u8, b: u8, a: u8) void {
    if (css.getStylePtr(id)) |style| {
        style.background_color = .{ .r = r, .g = g, .b = b, .a = a };
    }
}

/// Set text color
export fn zigdom_css_set_text_color(id: u32, r: u8, g: u8, b: u8, a: u8) void {
    if (css.getStylePtr(id)) |style| {
        style.color = .{ .r = r, .g = g, .b = b, .a = a };
    }
}

/// Set font size
export fn zigdom_css_set_font_size(id: u32, size: u8) void {
    if (css.getStylePtr(id)) |style| {
        style.font_size = @enumFromInt(size);
    }
}

/// Set font weight
export fn zigdom_css_set_font_weight(id: u32, weight: u16) void {
    if (css.getStylePtr(id)) |style| {
        style.font_weight = @enumFromInt(weight);
    }
}

/// Set border radius
export fn zigdom_css_set_border_radius(id: u32, radius: u8) void {
    if (css.getStylePtr(id)) |style| {
        style.border_radius = @enumFromInt(radius);
    }
}

/// Set shadow
export fn zigdom_css_set_shadow(id: u32, shadow: u8) void {
    if (css.getStylePtr(id)) |style| {
        style.shadow = @enumFromInt(shadow);
    }
}

/// Set width/height in pixels
export fn zigdom_css_set_size(id: u32, width: u16, height: u16) void {
    if (css.getStylePtr(id)) |style| {
        style.width_px = width;
        style.height_px = height;
    }
}

/// Generate CSS string for a style
export fn zigdom_css_generate(id: u32) ?[*]const u8 {
    return css.generateCss(id);
}

/// Get generated CSS length
export fn zigdom_css_get_len() usize {
    return css.getCssLen();
}

/// Get style count
export fn zigdom_css_get_style_count() u32 {
    return css.getStyleCount();
}

// === ZigDom Layout Engine ===

/// Initialize layout engine
export fn zigdom_layout_init() void {
    layout.init();
}

/// Create a layout node (returns node ID)
export fn zigdom_layout_create_node() u32 {
    return layout.createNode();
}

/// Set root node
export fn zigdom_layout_set_root(id: u32) void {
    layout.setRoot(id);
}

/// Add child to parent node
export fn zigdom_layout_add_child(parent_id: u32, child_id: u32) bool {
    return layout.addChild(parent_id, child_id);
}

/// Set node display type
export fn zigdom_layout_set_display(id: u32, display: u8) void {
    if (layout.getNode(id)) |node| {
        node.display = @enumFromInt(display);
    }
}

/// Set flex direction
export fn zigdom_layout_set_flex_direction(id: u32, direction: u8) void {
    if (layout.getNode(id)) |node| {
        node.flex_direction = @enumFromInt(direction);
    }
}

/// Set justify content
export fn zigdom_layout_set_justify_content(id: u32, justify: u8) void {
    if (layout.getNode(id)) |node| {
        node.justify_content = @enumFromInt(justify);
    }
}

/// Set align items
export fn zigdom_layout_set_align_items(id: u32, align_val: u8) void {
    if (layout.getNode(id)) |node| {
        node.align_items = @enumFromInt(align_val);
    }
}

/// Set flex properties
export fn zigdom_layout_set_flex(id: u32, grow: f32, shrink: f32, basis: f32) void {
    if (layout.getNode(id)) |node| {
        node.flex_grow = grow;
        node.flex_shrink = shrink;
        node.flex_basis = basis;
    }
}

/// Set node dimensions
export fn zigdom_layout_set_size(id: u32, width: f32, height: f32) void {
    if (layout.getNode(id)) |node| {
        node.width = width;
        node.height = height;
    }
}

/// Set min dimensions
export fn zigdom_layout_set_min_size(id: u32, min_width: f32, min_height: f32) void {
    if (layout.getNode(id)) |node| {
        node.min_width = min_width;
        node.min_height = min_height;
    }
}

/// Set max dimensions
export fn zigdom_layout_set_max_size(id: u32, max_width: f32, max_height: f32) void {
    if (layout.getNode(id)) |node| {
        node.max_width = max_width;
        node.max_height = max_height;
    }
}

/// Set gap
export fn zigdom_layout_set_gap(id: u32, gap: f32) void {
    if (layout.getNode(id)) |node| {
        node.gap = gap;
    }
}

/// Set padding
export fn zigdom_layout_set_padding(id: u32, top: f32, right: f32, bottom: f32, left: f32) void {
    if (layout.getNode(id)) |node| {
        node.padding_top = top;
        node.padding_right = right;
        node.padding_bottom = bottom;
        node.padding_left = left;
    }
}

/// Set margin
export fn zigdom_layout_set_margin(id: u32, top: f32, right: f32, bottom: f32, left: f32) void {
    if (layout.getNode(id)) |node| {
        node.margin_top = top;
        node.margin_right = right;
        node.margin_bottom = bottom;
        node.margin_left = left;
    }
}

/// Set intrinsic content size
export fn zigdom_layout_set_intrinsic_size(id: u32, width: f32, height: f32) void {
    if (layout.getNode(id)) |node| {
        node.intrinsic_width = width;
        node.intrinsic_height = height;
    }
}

/// Compute layout
export fn zigdom_layout_compute(container_width: f32, container_height: f32) void {
    layout.compute(container_width, container_height);
}

/// Get computed X position
export fn zigdom_layout_get_x(id: u32) f32 {
    if (layout.getNode(id)) |node| {
        return node.result.x;
    }
    return 0;
}

/// Get computed Y position
export fn zigdom_layout_get_y(id: u32) f32 {
    if (layout.getNode(id)) |node| {
        return node.result.y;
    }
    return 0;
}

/// Get computed width
export fn zigdom_layout_get_width(id: u32) f32 {
    if (layout.getNode(id)) |node| {
        return node.result.width;
    }
    return 0;
}

/// Get computed height
export fn zigdom_layout_get_height(id: u32) f32 {
    if (layout.getNode(id)) |node| {
        return node.result.height;
    }
    return 0;
}

/// Get node count
export fn zigdom_layout_get_node_count() u32 {
    return layout.getNodeCount();
}

/// Get results buffer pointer (for batch reading)
export fn zigdom_layout_get_results_ptr() ?*const anyopaque {
    return @ptrCast(layout.getResultsPtr());
}

/// Get result struct size
export fn zigdom_layout_get_result_size() usize {
    return layout.getResultSize();
}

// === Panic handler for WASM ===

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = msg;
    @trap();
}
