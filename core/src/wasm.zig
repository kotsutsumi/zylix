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
const component = @import("component.zig");
const dsl = @import("dsl.zig");
const vdom = @import("vdom.zig");
const todo = @import("todo.zig");

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

// === ZigDom Component System ===

/// Initialize component system
export fn zigdom_component_init() void {
    component.initGlobal();
}

/// Reset component tree
export fn zigdom_component_reset() void {
    component.getTree().reset();
}

/// Create a container component
export fn zigdom_component_create_container() u32 {
    return component.getTree().create(component.Component.container());
}

/// Create a text component
export fn zigdom_component_create_text(text_ptr: [*]const u8, text_len: usize) u32 {
    return component.getTree().create(component.Component.text(text_ptr[0..text_len]));
}

/// Create a button component
export fn zigdom_component_create_button(label_ptr: [*]const u8, label_len: usize) u32 {
    return component.getTree().create(component.Component.button(label_ptr[0..label_len]));
}

/// Create an input component
export fn zigdom_component_create_input(input_type: u8) u32 {
    return component.getTree().create(component.Component.input(@enumFromInt(input_type)));
}

/// Create a heading component
export fn zigdom_component_create_heading(level: u8, text_ptr: [*]const u8, text_len: usize) u32 {
    return component.getTree().create(component.Component.heading(@enumFromInt(level), text_ptr[0..text_len]));
}

/// Create a paragraph component
export fn zigdom_component_create_paragraph(text_ptr: [*]const u8, text_len: usize) u32 {
    return component.getTree().create(component.Component.paragraph(text_ptr[0..text_len]));
}

/// Create a link component
export fn zigdom_component_create_link(href_ptr: [*]const u8, href_len: usize, label_ptr: [*]const u8, label_len: usize) u32 {
    return component.getTree().create(component.Component.link(href_ptr[0..href_len], label_ptr[0..label_len]));
}

/// Create an image component
export fn zigdom_component_create_image(src_ptr: [*]const u8, src_len: usize, alt_ptr: [*]const u8, alt_len: usize) u32 {
    return component.getTree().create(component.Component.image(src_ptr[0..src_len], alt_ptr[0..alt_len]));
}

// ============================================================================
// Form Components (v0.7.0)
// ============================================================================

/// Create a select/dropdown component
export fn zigdom_component_create_select(placeholder_ptr: [*]const u8, placeholder_len: usize) u32 {
    return component.getTree().create(component.Component.selectDropdown(placeholder_ptr[0..placeholder_len]));
}

/// Create a checkbox component
export fn zigdom_component_create_checkbox(label_ptr: [*]const u8, label_len: usize) u32 {
    return component.getTree().create(component.Component.checkbox(label_ptr[0..label_len]));
}

/// Create a radio button component
export fn zigdom_component_create_radio(label_ptr: [*]const u8, label_len: usize, group_ptr: [*]const u8, group_len: usize) u32 {
    return component.getTree().create(component.Component.radio(label_ptr[0..label_len], group_ptr[0..group_len]));
}

/// Create a textarea component
export fn zigdom_component_create_textarea(placeholder_ptr: [*]const u8, placeholder_len: usize) u32 {
    return component.getTree().create(component.Component.textarea(placeholder_ptr[0..placeholder_len]));
}

/// Create a form container component
export fn zigdom_component_create_form() u32 {
    return component.getTree().create(component.Component.formContainer());
}

/// Create a toggle switch component
export fn zigdom_component_create_toggle_switch(label_ptr: [*]const u8, label_len: usize) u32 {
    return component.getTree().create(component.Component.toggleSwitch(label_ptr[0..label_len]));
}

/// Set checkbox/radio checked state
export fn zigdom_component_set_checked(id: u32, is_checked: bool) void {
    if (component.getTree().get(id)) |c| {
        c.setChecked(is_checked);
    }
}

/// Get checkbox/radio checked state
export fn zigdom_component_get_checked(id: u32) bool {
    if (component.getTree().get(id)) |c| {
        return c.state.checked;
    }
    return false;
}

/// Set textarea rows
export fn zigdom_component_set_textarea_rows(id: u32, rows: u8) void {
    if (component.getTree().get(id)) |c| {
        c.props.textarea_rows = rows;
        c.needs_render = true;
    }
}

/// Set textarea cols
export fn zigdom_component_set_textarea_cols(id: u32, cols: u8) void {
    if (component.getTree().get(id)) |c| {
        c.props.textarea_cols = cols;
        c.needs_render = true;
    }
}

// ============================================================================
// Layout Components (v0.7.0)
// ============================================================================

/// Create a vertical stack component
export fn zigdom_component_create_vstack() u32 {
    return component.getTree().create(component.Component.vstack());
}

/// Create a horizontal stack component
export fn zigdom_component_create_hstack() u32 {
    return component.getTree().create(component.Component.hstack());
}

/// Create a z-stack (overlay) component
export fn zigdom_component_create_zstack() u32 {
    return component.getTree().create(component.Component.zstack());
}

/// Create a grid component
export fn zigdom_component_create_grid() u32 {
    return component.getTree().create(.{ .component_type = .grid });
}

/// Create a scroll view component
export fn zigdom_component_create_scroll_view() u32 {
    return component.getTree().create(component.Component.scrollView());
}

/// Create a spacer component
export fn zigdom_component_create_spacer() u32 {
    return component.getTree().create(component.Component.spacerComponent());
}

/// Create a divider component
export fn zigdom_component_create_divider() u32 {
    return component.getTree().create(component.Component.dividerComponent());
}

/// Create a card component
export fn zigdom_component_create_card() u32 {
    return component.getTree().create(component.Component.cardContainer());
}

/// Set stack spacing
export fn zigdom_component_set_stack_spacing(id: u32, spacing: u16) void {
    if (component.getTree().get(id)) |c| {
        c.props.stack_spacing = spacing;
        c.needs_render = true;
    }
}

/// Set stack alignment
export fn zigdom_component_set_stack_alignment(id: u32, alignment: u8) void {
    if (component.getTree().get(id)) |c| {
        c.props.stack_alignment = @enumFromInt(alignment);
        c.needs_render = true;
    }
}

// ============================================================================
// Navigation Components (v0.7.0)
// ============================================================================

/// Create a navigation bar component
export fn zigdom_component_create_nav_bar(title_ptr: [*]const u8, title_len: usize) u32 {
    return component.getTree().create(component.Component.navBar(title_ptr[0..title_len]));
}

/// Create a tab bar component
export fn zigdom_component_create_tab_bar() u32 {
    return component.getTree().create(component.Component.tabBar());
}

// ============================================================================
// Feedback Components (v0.7.0)
// ============================================================================

/// Create an alert dialog component
export fn zigdom_component_create_alert(message_ptr: [*]const u8, message_len: usize, style: u8) u32 {
    return component.getTree().create(component.Component.alertDialog(message_ptr[0..message_len], @enumFromInt(style)));
}

/// Create a toast notification component
export fn zigdom_component_create_toast(message_ptr: [*]const u8, message_len: usize, position: u8) u32 {
    return component.getTree().create(component.Component.toastNotification(message_ptr[0..message_len], @enumFromInt(position)));
}

/// Create a modal dialog component
export fn zigdom_component_create_modal(title_ptr: [*]const u8, title_len: usize) u32 {
    return component.getTree().create(component.Component.modalDialog(title_ptr[0..title_len]));
}

/// Create a progress indicator component
export fn zigdom_component_create_progress(style: u8) u32 {
    return component.getTree().create(component.Component.progressIndicator(@enumFromInt(style)));
}

/// Create a loading spinner component
export fn zigdom_component_create_spinner() u32 {
    return component.getTree().create(component.Component.loadingSpinner());
}

/// Set progress value (0.0 to 1.0)
export fn zigdom_component_set_progress_value(id: u32, value: f32) void {
    if (component.getTree().get(id)) |c| {
        c.props.progress_value = value;
        c.needs_render = true;
    }
}

// ============================================================================
// Data Display Components (v0.7.0)
// ============================================================================

/// Create an icon component
export fn zigdom_component_create_icon(name_ptr: [*]const u8, name_len: usize) u32 {
    return component.getTree().create(component.Component.iconComponent(name_ptr[0..name_len]));
}

/// Create an avatar component
export fn zigdom_component_create_avatar(src_ptr: [*]const u8, src_len: usize, alt_ptr: [*]const u8, alt_len: usize) u32 {
    return component.getTree().create(component.Component.avatarComponent(src_ptr[0..src_len], alt_ptr[0..alt_len]));
}

/// Create a tag/badge component
export fn zigdom_component_create_tag(label_ptr: [*]const u8, label_len: usize) u32 {
    return component.getTree().create(component.Component.tagComponent(label_ptr[0..label_len]));
}

/// Create a badge component with count
export fn zigdom_component_create_badge(count: i64) u32 {
    return component.getTree().create(component.Component.badgeComponent(count));
}

/// Create an accordion component
export fn zigdom_component_create_accordion(title_ptr: [*]const u8, title_len: usize) u32 {
    return component.getTree().create(component.Component.accordionComponent(title_ptr[0..title_len]));
}

/// Set expanded state (for accordion, etc.)
export fn zigdom_component_set_expanded(id: u32, is_expanded: bool) void {
    if (component.getTree().get(id)) |c| {
        c.state.expanded = is_expanded;
        c.needs_render = true;
    }
}

/// Get expanded state
export fn zigdom_component_get_expanded(id: u32) bool {
    if (component.getTree().get(id)) |c| {
        return c.state.expanded;
    }
    return false;
}

/// Add child to parent component
export fn zigdom_component_add_child(parent_id: u32, child_id: u32) bool {
    return component.getTree().addChild(parent_id, child_id);
}

/// Remove component
export fn zigdom_component_remove(id: u32, recursive: bool) void {
    component.getTree().remove(id, recursive);
}

/// Set component style
export fn zigdom_component_set_style(id: u32, style_id: u32) void {
    if (component.getTree().get(id)) |c| {
        c.props.style_id = style_id;
        c.needs_render = true;
    }
}

/// Set component hover style
export fn zigdom_component_set_hover_style(id: u32, style_id: u32) void {
    if (component.getTree().get(id)) |c| {
        c.props.hover_style_id = style_id;
    }
}

/// Set component focus style
export fn zigdom_component_set_focus_style(id: u32, style_id: u32) void {
    if (component.getTree().get(id)) |c| {
        c.props.focus_style_id = style_id;
    }
}

/// Set component active style
export fn zigdom_component_set_active_style(id: u32, style_id: u32) void {
    if (component.getTree().get(id)) |c| {
        c.props.active_style_id = style_id;
    }
}

/// Set component disabled style
export fn zigdom_component_set_disabled_style(id: u32, style_id: u32) void {
    if (component.getTree().get(id)) |c| {
        c.props.disabled_style_id = style_id;
    }
}

/// Set component layout
export fn zigdom_component_set_layout(id: u32, layout_id: u32) void {
    if (component.getTree().get(id)) |c| {
        c.props.layout_id = layout_id;
        c.needs_render = true;
    }
}

/// Set component text content
export fn zigdom_component_set_text(id: u32, text_ptr: [*]const u8, text_len: usize) void {
    if (component.getTree().get(id)) |c| {
        c.props.setText(text_ptr[0..text_len]);
        c.needs_render = true;
    }
}

/// Set component class name
export fn zigdom_component_set_class(id: u32, class_ptr: [*]const u8, class_len: usize) void {
    if (component.getTree().get(id)) |c| {
        c.props.setClassName(class_ptr[0..class_len]);
        c.needs_render = true;
    }
}

/// Set input placeholder
export fn zigdom_component_set_placeholder(id: u32, text_ptr: [*]const u8, text_len: usize) void {
    if (component.getTree().get(id)) |c| {
        c.props.setPlaceholder(text_ptr[0..text_len]);
        c.needs_render = true;
    }
}

/// Set input value
export fn zigdom_component_set_value(id: u32, text_ptr: [*]const u8, text_len: usize) void {
    if (component.getTree().get(id)) |c| {
        c.props.setValue(text_ptr[0..text_len]);
        c.needs_render = true;
    }
}

/// Set aria label
export fn zigdom_component_set_aria_label(id: u32, label_ptr: [*]const u8, label_len: usize) void {
    if (component.getTree().get(id)) |c| {
        c.props.setAriaLabel(label_ptr[0..label_len]);
    }
}

/// Set tab index
export fn zigdom_component_set_tab_index(id: u32, index: i8) void {
    if (component.getTree().get(id)) |c| {
        c.props.tab_index = index;
    }
}

/// Set data value
export fn zigdom_component_set_data(id: u32, value: i64) void {
    if (component.getTree().get(id)) |c| {
        c.props.data_value = value;
    }
}

/// Add click event handler
export fn zigdom_component_on_click(id: u32, callback_id: u32) void {
    if (component.getTree().get(id)) |c| {
        if (c.handler_count < component.MAX_EVENT_HANDLERS) {
            c.handlers[c.handler_count] = .{
                .event_type = .click,
                .callback_id = callback_id,
            };
            c.handler_count += 1;
        }
    }
}

/// Add input event handler
export fn zigdom_component_on_input(id: u32, callback_id: u32) void {
    if (component.getTree().get(id)) |c| {
        if (c.handler_count < component.MAX_EVENT_HANDLERS) {
            c.handlers[c.handler_count] = .{
                .event_type = .input,
                .callback_id = callback_id,
            };
            c.handler_count += 1;
        }
    }
}

/// Add change event handler
export fn zigdom_component_on_change(id: u32, callback_id: u32) void {
    if (component.getTree().get(id)) |c| {
        if (c.handler_count < component.MAX_EVENT_HANDLERS) {
            c.handlers[c.handler_count] = .{
                .event_type = .change,
                .callback_id = callback_id,
            };
            c.handler_count += 1;
        }
    }
}

/// Add focus event handler
export fn zigdom_component_on_focus(id: u32, callback_id: u32) void {
    if (component.getTree().get(id)) |c| {
        if (c.handler_count < component.MAX_EVENT_HANDLERS) {
            c.handlers[c.handler_count] = .{
                .event_type = .focus,
                .callback_id = callback_id,
            };
            c.handler_count += 1;
        }
    }
}

/// Add blur event handler
export fn zigdom_component_on_blur(id: u32, callback_id: u32) void {
    if (component.getTree().get(id)) |c| {
        if (c.handler_count < component.MAX_EVENT_HANDLERS) {
            c.handlers[c.handler_count] = .{
                .event_type = .blur,
                .callback_id = callback_id,
            };
            c.handler_count += 1;
        }
    }
}

/// Set component hover state
export fn zigdom_component_set_hover(id: u32, is_hover: bool) void {
    if (component.getTree().get(id)) |c| {
        c.setHover(is_hover);
    }
}

/// Set component focus state
export fn zigdom_component_set_focus(id: u32, is_focus: bool) void {
    if (component.getTree().get(id)) |c| {
        c.setFocus(is_focus);
    }
}

/// Set component active state
export fn zigdom_component_set_active(id: u32, is_active: bool) void {
    if (component.getTree().get(id)) |c| {
        c.setActive(is_active);
    }
}

/// Set component disabled state
export fn zigdom_component_set_disabled(id: u32, is_disabled: bool) void {
    if (component.getTree().get(id)) |c| {
        c.state.disabled = is_disabled;
        c.needs_render = true;
    }
}

/// Set component visible state
export fn zigdom_component_set_visible(id: u32, visible: bool) void {
    if (component.getTree().get(id)) |c| {
        c.visible = visible;
        c.needs_render = true;
    }
}

/// Dispatch event to component (returns callback ID or 0)
export fn zigdom_component_dispatch_event(id: u32, event_type: u8) u32 {
    return component.getTree().dispatchEvent(id, @enumFromInt(event_type)) orelse 0;
}

/// Mark component as dirty (needs re-render)
export fn zigdom_component_mark_dirty(id: u32) void {
    component.getTree().markDirty(id);
}

/// Get component count
export fn zigdom_component_get_count() u32 {
    return component.getTree().count();
}

/// Get root component ID
export fn zigdom_component_get_root() u32 {
    return component.getTree().root_id;
}

/// Render component tree (generates render commands)
export fn zigdom_component_render(root_id: u32) void {
    component.getRenderer().render(root_id);
}

/// Get render command count
export fn zigdom_component_get_render_command_count() u32 {
    return component.getRenderer().getCommandCount();
}

/// Get render command type at index
export fn zigdom_component_get_render_command_type(index: u32) u8 {
    if (component.getRenderer().getCommand(index)) |cmd| {
        return @intFromEnum(cmd.command_type);
    }
    return 0;
}

/// Get render command component ID at index
export fn zigdom_component_get_render_command_component_id(index: u32) u32 {
    if (component.getRenderer().getCommand(index)) |cmd| {
        return cmd.component_id;
    }
    return 0;
}

/// Get render command parent ID at index
export fn zigdom_component_get_render_command_parent_id(index: u32) u32 {
    if (component.getRenderer().getCommand(index)) |cmd| {
        return cmd.parent_id;
    }
    return 0;
}

/// Get render command component type at index
export fn zigdom_component_get_render_command_component_type(index: u32) u8 {
    if (component.getRenderer().getCommand(index)) |cmd| {
        return @intFromEnum(cmd.component_type);
    }
    return 0;
}

/// Get render command style ID at index
export fn zigdom_component_get_render_command_style_id(index: u32) u32 {
    if (component.getRenderer().getCommand(index)) |cmd| {
        return cmd.style_id;
    }
    return 0;
}

/// Get render command event type at index
export fn zigdom_component_get_render_command_event_type(index: u32) u8 {
    if (component.getRenderer().getCommand(index)) |cmd| {
        return @intFromEnum(cmd.event_type);
    }
    return 0;
}

/// Get render command callback ID at index
export fn zigdom_component_get_render_command_callback_id(index: u32) u32 {
    if (component.getRenderer().getCommand(index)) |cmd| {
        return cmd.callback_id;
    }
    return 0;
}

/// Get render command data pointer at index
export fn zigdom_component_get_render_command_data(index: u32) ?[*]const u8 {
    if (component.getRenderer().getCommand(index)) |cmd| {
        if (cmd.data_len > 0) {
            return &cmd.data;
        }
    }
    return null;
}

/// Get render command data length at index
export fn zigdom_component_get_render_command_data_len(index: u32) u16 {
    if (component.getRenderer().getCommand(index)) |cmd| {
        return cmd.data_len;
    }
    return 0;
}

/// Get component text content
export fn zigdom_component_get_text(id: u32) ?[*]const u8 {
    if (component.getTree().get(id)) |c| {
        if (c.props.text_len > 0) {
            return &c.props.text;
        }
    }
    return null;
}

/// Get component text length
export fn zigdom_component_get_text_len(id: u32) u16 {
    if (component.getTree().get(id)) |c| {
        return c.props.text_len;
    }
    return 0;
}

/// Get component type
export fn zigdom_component_get_type(id: u32) u8 {
    if (component.getTree().get(id)) |c| {
        return @intFromEnum(c.component_type);
    }
    return 0;
}

/// Get effective style ID (based on current state)
export fn zigdom_component_get_effective_style(id: u32) u32 {
    if (component.getTree().get(id)) |c| {
        return c.getEffectiveStyleId();
    }
    return 0;
}

/// Check if component needs render
export fn zigdom_component_needs_render(id: u32) bool {
    if (component.getTree().get(id)) |c| {
        return c.needs_render;
    }
    return false;
}

/// Clear needs render flag
export fn zigdom_component_clear_render_flag(id: u32) void {
    if (component.getTree().get(id)) |c| {
        c.needs_render = false;
    }
}

// === ZigDom Declarative UI DSL ===

/// Initialize DSL builder
export fn zigdom_dsl_init() void {
    dsl.initBuilder();
}

/// Reset DSL builder (clears component tree)
export fn zigdom_dsl_reset() void {
    dsl.resetBuilder();
}

// Runtime element storage for JS-driven DSL
const MAX_RUNTIME_ELEMENTS = 256;
var runtime_elements: [MAX_RUNTIME_ELEMENTS]dsl.Element = undefined;
var runtime_element_count: u32 = 0;
var runtime_element_children: [MAX_RUNTIME_ELEMENTS][16]dsl.Element = undefined;
var runtime_children_counts: [MAX_RUNTIME_ELEMENTS]u8 = [_]u8{0} ** MAX_RUNTIME_ELEMENTS;

/// Create a container element (div, span, etc.)
export fn zigdom_dsl_create_container(element_type: u8) u32 {
    if (runtime_element_count >= MAX_RUNTIME_ELEMENTS) return 0;
    const id = runtime_element_count;
    runtime_elements[id] = dsl.Element{
        .element_type = @enumFromInt(element_type),
        .attrs = .{},
        .text = null,
        .children = &[_]dsl.Element{},
    };
    runtime_children_counts[id] = 0;
    runtime_element_count += 1;
    return id + 1; // 1-based IDs
}

/// Create a text element (h1-h6, p, button, etc.)
export fn zigdom_dsl_create_text_element(element_type: u8, text_ptr: [*]const u8, text_len: usize) u32 {
    if (runtime_element_count >= MAX_RUNTIME_ELEMENTS) return 0;
    const id = runtime_element_count;
    runtime_elements[id] = dsl.Element{
        .element_type = @enumFromInt(element_type),
        .attrs = .{},
        .text = text_ptr[0..text_len],
        .children = &[_]dsl.Element{},
    };
    runtime_children_counts[id] = 0;
    runtime_element_count += 1;
    return id + 1;
}

/// Set element attribute: class
export fn zigdom_dsl_set_class(id: u32, class_ptr: [*]const u8, class_len: usize) void {
    if (id == 0 or id > runtime_element_count) return;
    runtime_elements[id - 1].attrs.class = class_ptr[0..class_len];
}

/// Set element attribute: id
export fn zigdom_dsl_set_id(id: u32, id_ptr: [*]const u8, id_len: usize) void {
    if (id == 0 or id > runtime_element_count) return;
    runtime_elements[id - 1].attrs.id = id_ptr[0..id_len];
}

/// Set element attribute: style ID
export fn zigdom_dsl_set_style(id: u32, style_id: u32) void {
    if (id == 0 or id > runtime_element_count) return;
    runtime_elements[id - 1].attrs.style = style_id;
}

/// Set element attribute: onClick callback ID
export fn zigdom_dsl_set_onclick(id: u32, callback_id: u32) void {
    if (id == 0 or id > runtime_element_count) return;
    runtime_elements[id - 1].attrs.onClick = callback_id;
}

/// Set element attribute: onInput callback ID
export fn zigdom_dsl_set_oninput(id: u32, callback_id: u32) void {
    if (id == 0 or id > runtime_element_count) return;
    runtime_elements[id - 1].attrs.onInput = callback_id;
}

/// Set element attribute: onChange callback ID
export fn zigdom_dsl_set_onchange(id: u32, callback_id: u32) void {
    if (id == 0 or id > runtime_element_count) return;
    runtime_elements[id - 1].attrs.onChange = callback_id;
}

/// Set element attribute: placeholder
export fn zigdom_dsl_set_placeholder(id: u32, text_ptr: [*]const u8, text_len: usize) void {
    if (id == 0 or id > runtime_element_count) return;
    runtime_elements[id - 1].attrs.placeholder = text_ptr[0..text_len];
}

/// Set element attribute: href
export fn zigdom_dsl_set_href(id: u32, href_ptr: [*]const u8, href_len: usize) void {
    if (id == 0 or id > runtime_element_count) return;
    runtime_elements[id - 1].attrs.href = href_ptr[0..href_len];
}

/// Set element attribute: src
export fn zigdom_dsl_set_src(id: u32, src_ptr: [*]const u8, src_len: usize) void {
    if (id == 0 or id > runtime_element_count) return;
    runtime_elements[id - 1].attrs.src = src_ptr[0..src_len];
}

/// Set element attribute: alt
export fn zigdom_dsl_set_alt(id: u32, alt_ptr: [*]const u8, alt_len: usize) void {
    if (id == 0 or id > runtime_element_count) return;
    runtime_elements[id - 1].attrs.alt = alt_ptr[0..alt_len];
}

/// Set element attribute: input type
export fn zigdom_dsl_set_input_type(id: u32, input_type: u8) void {
    if (id == 0 or id > runtime_element_count) return;
    runtime_elements[id - 1].attrs.input_type = @enumFromInt(input_type);
}

/// Set element attribute: disabled
export fn zigdom_dsl_set_disabled(id: u32, is_disabled: bool) void {
    if (id == 0 or id > runtime_element_count) return;
    runtime_elements[id - 1].attrs.disabled = is_disabled;
}

/// Set element attribute: aria-label
export fn zigdom_dsl_set_aria_label(id: u32, label_ptr: [*]const u8, label_len: usize) void {
    if (id == 0 or id > runtime_element_count) return;
    runtime_elements[id - 1].attrs.aria_label = label_ptr[0..label_len];
}

/// Set element attribute: role
export fn zigdom_dsl_set_role(id: u32, role_ptr: [*]const u8, role_len: usize) void {
    if (id == 0 or id > runtime_element_count) return;
    runtime_elements[id - 1].attrs.role = role_ptr[0..role_len];
}

/// Set element attribute: tab index
export fn zigdom_dsl_set_tab_index(id: u32, index: i8) void {
    if (id == 0 or id > runtime_element_count) return;
    runtime_elements[id - 1].attrs.tab_index = index;
}

/// Set element attribute: data value
export fn zigdom_dsl_set_data(id: u32, value: i64) void {
    if (id == 0 or id > runtime_element_count) return;
    runtime_elements[id - 1].attrs.data = value;
}

/// Add child element to parent
export fn zigdom_dsl_add_child(parent_id: u32, child_id: u32) bool {
    if (parent_id == 0 or parent_id > runtime_element_count) return false;
    if (child_id == 0 or child_id > runtime_element_count) return false;

    const parent_idx = parent_id - 1;
    const child_count = runtime_children_counts[parent_idx];
    if (child_count >= 16) return false;

    runtime_element_children[parent_idx][child_count] = runtime_elements[child_id - 1];
    runtime_children_counts[parent_idx] = child_count + 1;
    runtime_elements[parent_idx].children = runtime_element_children[parent_idx][0 .. child_count + 1];

    return true;
}

/// Build element into component tree (returns component ID)
export fn zigdom_dsl_build(element_id: u32) u32 {
    if (element_id == 0 or element_id > runtime_element_count) return 0;
    return dsl.buildElement(&runtime_elements[element_id - 1]);
}

/// Get element count
export fn zigdom_dsl_get_element_count() u32 {
    return runtime_element_count;
}

/// Clear all runtime elements
export fn zigdom_dsl_clear_elements() void {
    runtime_element_count = 0;
    for (&runtime_children_counts) |*count| {
        count.* = 0;
    }
}

/// Get element type constants
export fn zigdom_dsl_element_type_div() u8 {
    return @intFromEnum(dsl.ElementType.div);
}

export fn zigdom_dsl_element_type_span() u8 {
    return @intFromEnum(dsl.ElementType.span);
}

export fn zigdom_dsl_element_type_section() u8 {
    return @intFromEnum(dsl.ElementType.section);
}

export fn zigdom_dsl_element_type_article() u8 {
    return @intFromEnum(dsl.ElementType.article);
}

export fn zigdom_dsl_element_type_header() u8 {
    return @intFromEnum(dsl.ElementType.header);
}

export fn zigdom_dsl_element_type_footer() u8 {
    return @intFromEnum(dsl.ElementType.footer);
}

export fn zigdom_dsl_element_type_nav() u8 {
    return @intFromEnum(dsl.ElementType.nav);
}

export fn zigdom_dsl_element_type_main() u8 {
    return @intFromEnum(dsl.ElementType.main);
}

export fn zigdom_dsl_element_type_h1() u8 {
    return @intFromEnum(dsl.ElementType.h1);
}

export fn zigdom_dsl_element_type_h2() u8 {
    return @intFromEnum(dsl.ElementType.h2);
}

export fn zigdom_dsl_element_type_h3() u8 {
    return @intFromEnum(dsl.ElementType.h3);
}

export fn zigdom_dsl_element_type_h4() u8 {
    return @intFromEnum(dsl.ElementType.h4);
}

export fn zigdom_dsl_element_type_h5() u8 {
    return @intFromEnum(dsl.ElementType.h5);
}

export fn zigdom_dsl_element_type_h6() u8 {
    return @intFromEnum(dsl.ElementType.h6);
}

export fn zigdom_dsl_element_type_p() u8 {
    return @intFromEnum(dsl.ElementType.p);
}

export fn zigdom_dsl_element_type_text() u8 {
    return @intFromEnum(dsl.ElementType.text);
}

export fn zigdom_dsl_element_type_button() u8 {
    return @intFromEnum(dsl.ElementType.button);
}

export fn zigdom_dsl_element_type_a() u8 {
    return @intFromEnum(dsl.ElementType.a);
}

export fn zigdom_dsl_element_type_input() u8 {
    return @intFromEnum(dsl.ElementType.input);
}

export fn zigdom_dsl_element_type_img() u8 {
    return @intFromEnum(dsl.ElementType.img);
}

export fn zigdom_dsl_element_type_ul() u8 {
    return @intFromEnum(dsl.ElementType.ul);
}

export fn zigdom_dsl_element_type_ol() u8 {
    return @intFromEnum(dsl.ElementType.ol);
}

export fn zigdom_dsl_element_type_li() u8 {
    return @intFromEnum(dsl.ElementType.li);
}

export fn zigdom_dsl_element_type_form() u8 {
    return @intFromEnum(dsl.ElementType.form);
}

export fn zigdom_dsl_element_type_label() u8 {
    return @intFromEnum(dsl.ElementType.label);
}

// === ZigDom Virtual DOM & Reconciliation ===

/// Initialize VDOM reconciler
export fn zigdom_vdom_init() void {
    vdom.initGlobal();
}

/// Reset reconciler state
export fn zigdom_vdom_reset() void {
    vdom.resetGlobal();
}

/// Create element node in next tree
export fn zigdom_vdom_create_element(tag: u8) u32 {
    return vdom.createElement(@enumFromInt(tag));
}

/// Create text node in next tree
export fn zigdom_vdom_create_text(text_ptr: [*]const u8, text_len: usize) u32 {
    return vdom.createText(text_ptr[0..text_len]);
}

/// Set node class
export fn zigdom_vdom_set_class(node_id: u32, class_ptr: [*]const u8, class_len: usize) void {
    vdom.setClass(node_id, class_ptr[0..class_len]);
}

/// Set node onClick handler
export fn zigdom_vdom_set_onclick(node_id: u32, callback_id: u32) void {
    vdom.setOnClick(node_id, callback_id);
}

/// Set node text content
export fn zigdom_vdom_set_text(node_id: u32, text_ptr: [*]const u8, text_len: usize) void {
    vdom.setText(node_id, text_ptr[0..text_len]);
}

/// Set node key (for list reconciliation)
export fn zigdom_vdom_set_key(node_id: u32, key_ptr: [*]const u8, key_len: usize) void {
    vdom.setKey(node_id, key_ptr[0..key_len]);
}

/// Add child to parent
export fn zigdom_vdom_add_child(parent_id: u32, child_id: u32) bool {
    return vdom.addChild(parent_id, child_id);
}

/// Set root node
export fn zigdom_vdom_set_root(node_id: u32) void {
    vdom.setRoot(node_id);
}

/// Commit changes and generate patches
export fn zigdom_vdom_commit() u32 {
    const result = vdom.commit();
    return result.count;
}

/// Get patch count
export fn zigdom_vdom_get_patch_count() u32 {
    return vdom.getPatchCount();
}

/// Get patch type at index
export fn zigdom_vdom_get_patch_type(index: u32) u8 {
    if (vdom.getPatch(index)) |patch| {
        return @intFromEnum(patch.patch_type);
    }
    return 0;
}

/// Get patch node ID at index
export fn zigdom_vdom_get_patch_node_id(index: u32) u32 {
    if (vdom.getPatch(index)) |patch| {
        return patch.node_id;
    }
    return 0;
}

/// Get patch DOM ID at index
export fn zigdom_vdom_get_patch_dom_id(index: u32) u32 {
    if (vdom.getPatch(index)) |patch| {
        return patch.dom_id;
    }
    return 0;
}

/// Get patch parent ID at index
export fn zigdom_vdom_get_patch_parent_id(index: u32) u32 {
    if (vdom.getPatch(index)) |patch| {
        return patch.parent_id;
    }
    return 0;
}

/// Get patch tag at index
export fn zigdom_vdom_get_patch_tag(index: u32) u8 {
    if (vdom.getPatch(index)) |patch| {
        return @intFromEnum(patch.new_tag);
    }
    return 0;
}

/// Get patch node type at index
export fn zigdom_vdom_get_patch_node_type(index: u32) u8 {
    if (vdom.getPatch(index)) |patch| {
        return @intFromEnum(patch.new_node_type);
    }
    return 0;
}

/// Get patch index (for insert/remove child)
export fn zigdom_vdom_get_patch_index(index: u32) u16 {
    if (vdom.getPatch(index)) |patch| {
        return patch.index;
    }
    return 0;
}

/// Get patch text at index
export fn zigdom_vdom_get_patch_text(index: u32) ?[*]const u8 {
    if (vdom.getPatch(index)) |patch| {
        if (patch.text_len > 0) {
            return &patch.text;
        }
    }
    return null;
}

/// Get patch text length at index
export fn zigdom_vdom_get_patch_text_len(index: u32) u16 {
    if (vdom.getPatch(index)) |patch| {
        return patch.text_len;
    }
    return 0;
}

/// Get patch class at index
export fn zigdom_vdom_get_patch_class(index: u32) ?[*]const u8 {
    if (vdom.getPatch(index)) |patch| {
        if (patch.props.class_len > 0) {
            return &patch.props.class;
        }
    }
    return null;
}

/// Get patch class length at index
export fn zigdom_vdom_get_patch_class_len(index: u32) u8 {
    if (vdom.getPatch(index)) |patch| {
        return patch.props.class_len;
    }
    return 0;
}

/// Get patch style ID at index
export fn zigdom_vdom_get_patch_style_id(index: u32) u32 {
    if (vdom.getPatch(index)) |patch| {
        return patch.props.style_id;
    }
    return 0;
}

/// Get patch onClick callback at index
export fn zigdom_vdom_get_patch_onclick(index: u32) u32 {
    if (vdom.getPatch(index)) |patch| {
        return patch.props.on_click;
    }
    return 0;
}

/// Get current tree node count
export fn zigdom_vdom_get_node_count() u32 {
    return vdom.getReconciler().getCurrentTree().getNodeCount();
}

/// Element tag constants
export fn zigdom_vdom_tag_div() u8 {
    return @intFromEnum(vdom.ElementTag.div);
}

export fn zigdom_vdom_tag_span() u8 {
    return @intFromEnum(vdom.ElementTag.span);
}

export fn zigdom_vdom_tag_section() u8 {
    return @intFromEnum(vdom.ElementTag.section);
}

export fn zigdom_vdom_tag_article() u8 {
    return @intFromEnum(vdom.ElementTag.article);
}

export fn zigdom_vdom_tag_header() u8 {
    return @intFromEnum(vdom.ElementTag.header);
}

export fn zigdom_vdom_tag_footer() u8 {
    return @intFromEnum(vdom.ElementTag.footer);
}

export fn zigdom_vdom_tag_nav() u8 {
    return @intFromEnum(vdom.ElementTag.nav);
}

export fn zigdom_vdom_tag_main() u8 {
    return @intFromEnum(vdom.ElementTag.main);
}

export fn zigdom_vdom_tag_h1() u8 {
    return @intFromEnum(vdom.ElementTag.h1);
}

export fn zigdom_vdom_tag_h2() u8 {
    return @intFromEnum(vdom.ElementTag.h2);
}

export fn zigdom_vdom_tag_h3() u8 {
    return @intFromEnum(vdom.ElementTag.h3);
}

export fn zigdom_vdom_tag_h4() u8 {
    return @intFromEnum(vdom.ElementTag.h4);
}

export fn zigdom_vdom_tag_h5() u8 {
    return @intFromEnum(vdom.ElementTag.h5);
}

export fn zigdom_vdom_tag_h6() u8 {
    return @intFromEnum(vdom.ElementTag.h6);
}

export fn zigdom_vdom_tag_p() u8 {
    return @intFromEnum(vdom.ElementTag.p);
}

export fn zigdom_vdom_tag_button() u8 {
    return @intFromEnum(vdom.ElementTag.button);
}

export fn zigdom_vdom_tag_a() u8 {
    return @intFromEnum(vdom.ElementTag.a);
}

export fn zigdom_vdom_tag_input() u8 {
    return @intFromEnum(vdom.ElementTag.input);
}

export fn zigdom_vdom_tag_img() u8 {
    return @intFromEnum(vdom.ElementTag.img);
}

export fn zigdom_vdom_tag_ul() u8 {
    return @intFromEnum(vdom.ElementTag.ul);
}

export fn zigdom_vdom_tag_ol() u8 {
    return @intFromEnum(vdom.ElementTag.ol);
}

export fn zigdom_vdom_tag_li() u8 {
    return @intFromEnum(vdom.ElementTag.li);
}

export fn zigdom_vdom_tag_form() u8 {
    return @intFromEnum(vdom.ElementTag.form);
}

export fn zigdom_vdom_tag_label() u8 {
    return @intFromEnum(vdom.ElementTag.label);
}

/// Patch type constants
export fn zigdom_vdom_patch_none() u8 {
    return @intFromEnum(vdom.PatchType.none);
}

export fn zigdom_vdom_patch_create() u8 {
    return @intFromEnum(vdom.PatchType.create);
}

export fn zigdom_vdom_patch_remove() u8 {
    return @intFromEnum(vdom.PatchType.remove);
}

export fn zigdom_vdom_patch_replace() u8 {
    return @intFromEnum(vdom.PatchType.replace);
}

export fn zigdom_vdom_patch_update_props() u8 {
    return @intFromEnum(vdom.PatchType.update_props);
}

export fn zigdom_vdom_patch_update_text() u8 {
    return @intFromEnum(vdom.PatchType.update_text);
}

export fn zigdom_vdom_patch_reorder() u8 {
    return @intFromEnum(vdom.PatchType.reorder);
}

export fn zigdom_vdom_patch_insert_child() u8 {
    return @intFromEnum(vdom.PatchType.insert_child);
}

export fn zigdom_vdom_patch_remove_child() u8 {
    return @intFromEnum(vdom.PatchType.remove_child);
}

// === ZigDom Todo Application ===

/// Initialize todo state
export fn zigdom_todo_init() void {
    todo.getState().reset();
}

/// Add a todo item (returns item ID or 0 on failure)
export fn zigdom_todo_add(text_ptr: [*]const u8, text_len: usize) u32 {
    return todo.getState().add(text_ptr[0..text_len]) orelse 0;
}

/// Remove a todo item by ID
export fn zigdom_todo_remove(id: u32) bool {
    return todo.getState().remove(id);
}

/// Toggle todo completion status
export fn zigdom_todo_toggle(id: u32) bool {
    return todo.getState().toggle(id);
}

/// Toggle all todos
export fn zigdom_todo_toggle_all() void {
    todo.getState().toggleAll();
}

/// Clear completed todos (returns count removed)
export fn zigdom_todo_clear_completed() u32 {
    return todo.getState().clearCompleted();
}

/// Set filter mode (0=all, 1=active, 2=completed)
export fn zigdom_todo_set_filter(filter: u8) void {
    todo.getState().setFilter(@enumFromInt(filter));
}

/// Get current filter mode
export fn zigdom_todo_get_filter() u8 {
    return @intFromEnum(todo.getState().filter);
}

/// Get total todo count
export fn zigdom_todo_get_count() u32 {
    return todo.getState().item_count;
}

/// Get active (not completed) count
export fn zigdom_todo_get_active_count() u32 {
    return todo.getState().getActiveCount();
}

/// Get completed count
export fn zigdom_todo_get_completed_count() u32 {
    return todo.getState().getCompletedCount();
}

/// Get visible count (based on current filter)
export fn zigdom_todo_get_visible_count() u32 {
    return todo.getState().getVisibleCount();
}

/// Get item text by ID
export fn zigdom_todo_get_item_text(id: u32) ?[*]const u8 {
    if (todo.getState().getItem(id)) |item| {
        if (item.text_len > 0) {
            return &item.text;
        }
    }
    return null;
}

/// Get item text length by ID
export fn zigdom_todo_get_item_text_len(id: u32) u16 {
    if (todo.getState().getItem(id)) |item| {
        return item.text_len;
    }
    return 0;
}

/// Get item completed status by ID
export fn zigdom_todo_get_item_completed(id: u32) bool {
    if (todo.getState().getItem(id)) |item| {
        return item.completed;
    }
    return false;
}

/// Update item text
export fn zigdom_todo_update_text(id: u32, text_ptr: [*]const u8, text_len: usize) bool {
    return todo.getState().updateText(id, text_ptr[0..text_len]);
}

/// Render todo app to VDOM (generates VNode tree)
export fn zigdom_todo_render() void {
    todo.renderTodoApp(todo.getState());
}

/// Render and commit (returns patch count)
export fn zigdom_todo_render_and_commit() u32 {
    todo.renderTodoApp(todo.getState());
    const result = vdom.commit();
    return result.count;
}

/// Get event ID constants
export fn zigdom_todo_event_add() u32 {
    return todo.EventId.ADD_TODO;
}

export fn zigdom_todo_event_toggle_base() u32 {
    return todo.EventId.TOGGLE_TODO;
}

export fn zigdom_todo_event_remove_base() u32 {
    return todo.EventId.REMOVE_TODO;
}

export fn zigdom_todo_event_toggle_all() u32 {
    return todo.EventId.TOGGLE_ALL;
}

export fn zigdom_todo_event_clear_completed() u32 {
    return todo.EventId.CLEAR_COMPLETED;
}

export fn zigdom_todo_event_filter_all() u32 {
    return todo.EventId.FILTER_ALL;
}

export fn zigdom_todo_event_filter_active() u32 {
    return todo.EventId.FILTER_ACTIVE;
}

export fn zigdom_todo_event_filter_completed() u32 {
    return todo.EventId.FILTER_COMPLETED;
}

/// Dispatch event by callback ID (returns true if handled)
export fn zigdom_todo_dispatch(callback_id: u32) bool {
    const todo_state = todo.getState();

    // Check base event IDs
    if (callback_id == todo.EventId.TOGGLE_ALL) {
        todo_state.toggleAll();
        return true;
    }
    if (callback_id == todo.EventId.CLEAR_COMPLETED) {
        _ = todo_state.clearCompleted();
        return true;
    }
    if (callback_id == todo.EventId.FILTER_ALL) {
        todo_state.setFilter(.all);
        return true;
    }
    if (callback_id == todo.EventId.FILTER_ACTIVE) {
        todo_state.setFilter(.active);
        return true;
    }
    if (callback_id == todo.EventId.FILTER_COMPLETED) {
        todo_state.setFilter(.completed);
        return true;
    }

    // Check toggle/remove events (callback_id = base + item_id * 1000)
    if (callback_id >= 1000) {
        const item_id = callback_id / 1000;
        const base_event = callback_id % 1000;

        if (base_event == todo.EventId.TOGGLE_TODO) {
            return todo_state.toggle(item_id);
        }
        if (base_event == todo.EventId.REMOVE_TODO) {
            return todo_state.remove(item_id);
        }
    }

    return false;
}

// === Panic handler for WASM ===

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = msg;
    @trap();
}

// ============================================================================
// Tests
// ============================================================================

test "MAX_RUNTIME_ELEMENTS constant" {
    try std.testing.expectEqual(@as(usize, 256), MAX_RUNTIME_ELEMENTS);
}

// --- DSL Element Type Constants ---

test "DSL element type div" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.div)), zigdom_dsl_element_type_div());
}

test "DSL element type span" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.span)), zigdom_dsl_element_type_span());
}

test "DSL element type section" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.section)), zigdom_dsl_element_type_section());
}

test "DSL element type article" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.article)), zigdom_dsl_element_type_article());
}

test "DSL element type header" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.header)), zigdom_dsl_element_type_header());
}

test "DSL element type footer" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.footer)), zigdom_dsl_element_type_footer());
}

test "DSL element type nav" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.nav)), zigdom_dsl_element_type_nav());
}

test "DSL element type main" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.main)), zigdom_dsl_element_type_main());
}

test "DSL element type h1" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.h1)), zigdom_dsl_element_type_h1());
}

test "DSL element type h2" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.h2)), zigdom_dsl_element_type_h2());
}

test "DSL element type h3" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.h3)), zigdom_dsl_element_type_h3());
}

test "DSL element type h4" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.h4)), zigdom_dsl_element_type_h4());
}

test "DSL element type h5" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.h5)), zigdom_dsl_element_type_h5());
}

test "DSL element type h6" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.h6)), zigdom_dsl_element_type_h6());
}

test "DSL element type p" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.p)), zigdom_dsl_element_type_p());
}

test "DSL element type text" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.text)), zigdom_dsl_element_type_text());
}

test "DSL element type button" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.button)), zigdom_dsl_element_type_button());
}

test "DSL element type a" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.a)), zigdom_dsl_element_type_a());
}

test "DSL element type input" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.input)), zigdom_dsl_element_type_input());
}

test "DSL element type img" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.img)), zigdom_dsl_element_type_img());
}

test "DSL element type ul" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.ul)), zigdom_dsl_element_type_ul());
}

test "DSL element type ol" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.ol)), zigdom_dsl_element_type_ol());
}

test "DSL element type li" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.li)), zigdom_dsl_element_type_li());
}

test "DSL element type form" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.form)), zigdom_dsl_element_type_form());
}

test "DSL element type label" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(dsl.ElementType.label)), zigdom_dsl_element_type_label());
}

// --- VDOM Tag Constants ---

test "VDOM tag div" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.div)), zigdom_vdom_tag_div());
}

test "VDOM tag span" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.span)), zigdom_vdom_tag_span());
}

test "VDOM tag section" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.section)), zigdom_vdom_tag_section());
}

test "VDOM tag article" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.article)), zigdom_vdom_tag_article());
}

test "VDOM tag header" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.header)), zigdom_vdom_tag_header());
}

test "VDOM tag footer" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.footer)), zigdom_vdom_tag_footer());
}

test "VDOM tag nav" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.nav)), zigdom_vdom_tag_nav());
}

test "VDOM tag main" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.main)), zigdom_vdom_tag_main());
}

test "VDOM tag h1" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.h1)), zigdom_vdom_tag_h1());
}

test "VDOM tag h2" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.h2)), zigdom_vdom_tag_h2());
}

test "VDOM tag h3" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.h3)), zigdom_vdom_tag_h3());
}

test "VDOM tag h4" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.h4)), zigdom_vdom_tag_h4());
}

test "VDOM tag h5" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.h5)), zigdom_vdom_tag_h5());
}

test "VDOM tag h6" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.h6)), zigdom_vdom_tag_h6());
}

test "VDOM tag p" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.p)), zigdom_vdom_tag_p());
}

test "VDOM tag button" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.button)), zigdom_vdom_tag_button());
}

test "VDOM tag a" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.a)), zigdom_vdom_tag_a());
}

test "VDOM tag input" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.input)), zigdom_vdom_tag_input());
}

test "VDOM tag img" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.img)), zigdom_vdom_tag_img());
}

test "VDOM tag ul" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.ul)), zigdom_vdom_tag_ul());
}

test "VDOM tag ol" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.ol)), zigdom_vdom_tag_ol());
}

test "VDOM tag li" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.li)), zigdom_vdom_tag_li());
}

test "VDOM tag form" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.form)), zigdom_vdom_tag_form());
}

test "VDOM tag label" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.ElementTag.label)), zigdom_vdom_tag_label());
}

// --- VDOM Patch Type Constants ---

test "VDOM patch none" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.PatchType.none)), zigdom_vdom_patch_none());
}

test "VDOM patch create" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.PatchType.create)), zigdom_vdom_patch_create());
}

test "VDOM patch remove" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.PatchType.remove)), zigdom_vdom_patch_remove());
}

test "VDOM patch replace" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.PatchType.replace)), zigdom_vdom_patch_replace());
}

test "VDOM patch update_props" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.PatchType.update_props)), zigdom_vdom_patch_update_props());
}

test "VDOM patch update_text" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.PatchType.update_text)), zigdom_vdom_patch_update_text());
}

test "VDOM patch reorder" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.PatchType.reorder)), zigdom_vdom_patch_reorder());
}

test "VDOM patch insert_child" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.PatchType.insert_child)), zigdom_vdom_patch_insert_child());
}

test "VDOM patch remove_child" {
    try std.testing.expectEqual(@as(u8, @intFromEnum(vdom.PatchType.remove_child)), zigdom_vdom_patch_remove_child());
}

// --- Todo Event ID Constants ---

test "Todo event ADD_TODO" {
    try std.testing.expectEqual(todo.EventId.ADD_TODO, zigdom_todo_event_add());
}

test "Todo event TOGGLE_TODO" {
    try std.testing.expectEqual(todo.EventId.TOGGLE_TODO, zigdom_todo_event_toggle_base());
}

test "Todo event REMOVE_TODO" {
    try std.testing.expectEqual(todo.EventId.REMOVE_TODO, zigdom_todo_event_remove_base());
}

test "Todo event TOGGLE_ALL" {
    try std.testing.expectEqual(todo.EventId.TOGGLE_ALL, zigdom_todo_event_toggle_all());
}

test "Todo event CLEAR_COMPLETED" {
    try std.testing.expectEqual(todo.EventId.CLEAR_COMPLETED, zigdom_todo_event_clear_completed());
}

test "Todo event FILTER_ALL" {
    try std.testing.expectEqual(todo.EventId.FILTER_ALL, zigdom_todo_event_filter_all());
}

test "Todo event FILTER_ACTIVE" {
    try std.testing.expectEqual(todo.EventId.FILTER_ACTIVE, zigdom_todo_event_filter_active());
}

test "Todo event FILTER_COMPLETED" {
    try std.testing.expectEqual(todo.EventId.FILTER_COMPLETED, zigdom_todo_event_filter_completed());
}

// --- Runtime Element Storage ---

test "runtime_elements array size" {
    try std.testing.expectEqual(@as(usize, 256), runtime_elements.len);
}

test "runtime_element_children array size" {
    try std.testing.expectEqual(@as(usize, 256), runtime_element_children.len);
}

test "runtime_children_counts initial zero" {
    for (runtime_children_counts) |count| {
        try std.testing.expectEqual(@as(u8, 0), count);
    }
}

test "DSL element types are unique" {
    const types = [_]u8{
        zigdom_dsl_element_type_div(),
        zigdom_dsl_element_type_span(),
        zigdom_dsl_element_type_section(),
        zigdom_dsl_element_type_article(),
        zigdom_dsl_element_type_header(),
        zigdom_dsl_element_type_footer(),
        zigdom_dsl_element_type_nav(),
        zigdom_dsl_element_type_main(),
        zigdom_dsl_element_type_h1(),
        zigdom_dsl_element_type_h2(),
        zigdom_dsl_element_type_h3(),
        zigdom_dsl_element_type_h4(),
        zigdom_dsl_element_type_h5(),
        zigdom_dsl_element_type_h6(),
        zigdom_dsl_element_type_p(),
        zigdom_dsl_element_type_text(),
        zigdom_dsl_element_type_button(),
        zigdom_dsl_element_type_a(),
        zigdom_dsl_element_type_input(),
        zigdom_dsl_element_type_img(),
        zigdom_dsl_element_type_ul(),
        zigdom_dsl_element_type_ol(),
        zigdom_dsl_element_type_li(),
        zigdom_dsl_element_type_form(),
        zigdom_dsl_element_type_label(),
    };

    // Check uniqueness by looking for duplicates
    for (types, 0..) |t1, i| {
        for (types[i + 1 ..]) |t2| {
            try std.testing.expect(t1 != t2);
        }
    }
}

test "VDOM tags are unique" {
    const tags = [_]u8{
        zigdom_vdom_tag_div(),
        zigdom_vdom_tag_span(),
        zigdom_vdom_tag_section(),
        zigdom_vdom_tag_article(),
        zigdom_vdom_tag_header(),
        zigdom_vdom_tag_footer(),
        zigdom_vdom_tag_nav(),
        zigdom_vdom_tag_main(),
        zigdom_vdom_tag_h1(),
        zigdom_vdom_tag_h2(),
        zigdom_vdom_tag_h3(),
        zigdom_vdom_tag_h4(),
        zigdom_vdom_tag_h5(),
        zigdom_vdom_tag_h6(),
        zigdom_vdom_tag_p(),
        zigdom_vdom_tag_button(),
        zigdom_vdom_tag_a(),
        zigdom_vdom_tag_input(),
        zigdom_vdom_tag_img(),
        zigdom_vdom_tag_ul(),
        zigdom_vdom_tag_ol(),
        zigdom_vdom_tag_li(),
        zigdom_vdom_tag_form(),
        zigdom_vdom_tag_label(),
    };

    // Check uniqueness
    for (tags, 0..) |t1, i| {
        for (tags[i + 1 ..]) |t2| {
            try std.testing.expect(t1 != t2);
        }
    }
}

test "VDOM patch types are unique" {
    const patches = [_]u8{
        zigdom_vdom_patch_none(),
        zigdom_vdom_patch_create(),
        zigdom_vdom_patch_remove(),
        zigdom_vdom_patch_replace(),
        zigdom_vdom_patch_update_props(),
        zigdom_vdom_patch_update_text(),
        zigdom_vdom_patch_reorder(),
        zigdom_vdom_patch_insert_child(),
        zigdom_vdom_patch_remove_child(),
    };

    // Check uniqueness
    for (patches, 0..) |p1, i| {
        for (patches[i + 1 ..]) |p2| {
            try std.testing.expect(p1 != p2);
        }
    }
}

test "Todo event IDs are unique" {
    const events = [_]u32{
        zigdom_todo_event_add(),
        zigdom_todo_event_toggle_base(),
        zigdom_todo_event_remove_base(),
        zigdom_todo_event_toggle_all(),
        zigdom_todo_event_clear_completed(),
        zigdom_todo_event_filter_all(),
        zigdom_todo_event_filter_active(),
        zigdom_todo_event_filter_completed(),
    };

    // Check uniqueness
    for (events, 0..) |e1, i| {
        for (events[i + 1 ..]) |e2| {
            try std.testing.expect(e1 != e2);
        }
    }
}

test "scheduler stats size" {
    try std.testing.expect(zigdom_scheduler_get_stats_size() > 0);
}
