//! Vim Keybinding System
//!
//! Provides vim-style modal editing with modes, operators, motions,
//! text objects, and registers.

const std = @import("std");
const editor = @import("editor.zig");

/// Vim editing mode
pub const Mode = enum(u8) {
    normal,
    insert,
    visual,
    visual_line,
    visual_block,
    command,
    replace,
    operator_pending,

    /// Get mode display name
    pub fn name(self: Mode) []const u8 {
        return switch (self) {
            .normal => "NORMAL",
            .insert => "INSERT",
            .visual => "VISUAL",
            .visual_line => "V-LINE",
            .visual_block => "V-BLOCK",
            .command => "COMMAND",
            .replace => "REPLACE",
            .operator_pending => "O-PENDING",
        };
    }

    /// Get mode indicator character
    pub fn indicator(self: Mode) u8 {
        return switch (self) {
            .normal => 'N',
            .insert => 'I',
            .visual, .visual_line, .visual_block => 'V',
            .command => ':',
            .replace => 'R',
            .operator_pending => 'O',
        };
    }
};

/// Vim operator
pub const Operator = enum(u8) {
    none = 0,
    delete, // d
    change, // c
    yank, // y
    indent_right, // >
    indent_left, // <
    format, // =
    uppercase, // gU
    lowercase, // gu
    swap_case, // g~
    filter, // !
    fold, // zf
    comment, // gc (custom)

    pub fn fromChar(c: u8) ?Operator {
        return switch (c) {
            'd' => .delete,
            'c' => .change,
            'y' => .yank,
            '>' => .indent_right,
            '<' => .indent_left,
            '=' => .format,
            '!' => .filter,
            else => null,
        };
    }
};

/// Motion type
pub const Motion = enum(u8) {
    // Character motions
    char_left, // h
    char_right, // l
    char_up, // k
    char_down, // j

    // Word motions
    word_start, // w
    word_end, // e
    word_back, // b
    big_word_start, // W
    big_word_end, // E
    big_word_back, // B

    // Line motions
    line_start, // 0
    line_first_non_blank, // ^
    line_end, // $
    line_last_non_blank, // g_

    // Paragraph motions
    paragraph_back, // {
    paragraph_forward, // }

    // Sentence motions
    sentence_back, // (
    sentence_forward, // )

    // Screen motions
    screen_top, // H
    screen_middle, // M
    screen_bottom, // L

    // Search motions
    find_char, // f
    find_char_before, // t
    find_char_back, // F
    find_char_back_after, // T
    repeat_find, // ;
    repeat_find_reverse, // ,

    // Mark motions
    mark_jump, // '
    mark_exact, // `

    // Matching bracket
    match_bracket, // %

    // Document motions
    document_start, // gg
    document_end, // G
    goto_line, // <count>G or :<count>

    // Column motions
    column, // |

    pub fn fromKey(key: u8, is_shifted: bool) ?Motion {
        return switch (key) {
            'h' => .char_left,
            'l' => .char_right,
            'k' => .char_up,
            'j' => .char_down,
            'w' => if (is_shifted) .big_word_start else .word_start,
            'e' => if (is_shifted) .big_word_end else .word_end,
            'b' => if (is_shifted) .big_word_back else .word_back,
            '0' => .line_start,
            '^' => .line_first_non_blank,
            '$' => .line_end,
            '{' => .paragraph_back,
            '}' => .paragraph_forward,
            '(' => .sentence_back,
            ')' => .sentence_forward,
            'f' => .find_char,
            't' => .find_char_before,
            ';' => .repeat_find,
            ',' => .repeat_find_reverse,
            '%' => .match_bracket,
            '|' => .column,
            else => null,
        };
    }

    /// Is this motion linewise?
    pub fn isLinewise(self: Motion) bool {
        return switch (self) {
            .char_up, .char_down, .paragraph_back, .paragraph_forward, .document_start, .document_end, .goto_line => true,
            else => false,
        };
    }

    /// Is this motion inclusive?
    pub fn isInclusive(self: Motion) bool {
        return switch (self) {
            .char_right, .word_end, .big_word_end, .line_end, .line_last_non_blank, .find_char, .match_bracket => true,
            else => false,
        };
    }
};

/// Text object type
pub const TextObject = enum(u8) {
    // Word objects
    inner_word, // iw
    a_word, // aw
    inner_big_word, // iW
    a_big_word, // aW

    // Quote objects
    inner_double_quote, // i"
    a_double_quote, // a"
    inner_single_quote, // i'
    a_single_quote, // a'
    inner_backtick, // i`
    a_backtick, // a`

    // Bracket objects
    inner_paren, // i( or i)
    a_paren, // a( or a)
    inner_bracket, // i[ or i]
    a_bracket, // a[ or a]
    inner_brace, // i{ or i}
    a_brace, // a{ or a}
    inner_angle, // i< or i>
    a_angle, // a< or a>

    // Tag objects
    inner_tag, // it
    a_tag, // at

    // Block objects
    inner_block, // iB or i{
    a_block, // aB or a{

    // Sentence/paragraph
    inner_sentence, // is
    a_sentence, // as
    inner_paragraph, // ip
    a_paragraph, // ap

    // Line
    inner_line, // il (custom)
    a_line, // al (custom)

    pub fn fromChars(modifier: u8, object: u8) ?TextObject {
        const is_inner = modifier == 'i';

        return switch (object) {
            'w' => if (is_inner) .inner_word else .a_word,
            'W' => if (is_inner) .inner_big_word else .a_big_word,
            '"' => if (is_inner) .inner_double_quote else .a_double_quote,
            '\'' => if (is_inner) .inner_single_quote else .a_single_quote,
            '`' => if (is_inner) .inner_backtick else .a_backtick,
            '(', ')' => if (is_inner) .inner_paren else .a_paren,
            '[', ']' => if (is_inner) .inner_bracket else .a_bracket,
            '{', '}' => if (is_inner) .inner_brace else .a_brace,
            '<', '>' => if (is_inner) .inner_angle else .a_angle,
            't' => if (is_inner) .inner_tag else .a_tag,
            'B' => if (is_inner) .inner_block else .a_block,
            's' => if (is_inner) .inner_sentence else .a_sentence,
            'p' => if (is_inner) .inner_paragraph else .a_paragraph,
            'l' => if (is_inner) .inner_line else .a_line,
            else => null,
        };
    }
};

/// Register identifier
pub const Register = enum(u8) {
    unnamed = 0, // "
    named_a = 1,
    named_b = 2,
    named_c = 3,
    named_d = 4,
    named_e = 5,
    named_f = 6,
    named_g = 7,
    named_h = 8,
    named_i = 9,
    named_j = 10,
    named_k = 11,
    named_l = 12,
    named_m = 13,
    named_n = 14,
    named_o = 15,
    named_p = 16,
    named_q = 17,
    named_r = 18,
    named_s = 19,
    named_t = 20,
    named_u = 21,
    named_v = 22,
    named_w = 23,
    named_x = 24,
    named_y = 25,
    named_z = 26,
    small_delete = 27, // -
    numbered_0 = 28, // 0
    numbered_1 = 29, // 1
    numbered_2 = 30, // 2
    numbered_3 = 31, // 3
    numbered_4 = 32, // 4
    numbered_5 = 33, // 5
    numbered_6 = 34, // 6
    numbered_7 = 35, // 7
    numbered_8 = 36, // 8
    numbered_9 = 37, // 9
    clipboard = 38, // + or *
    expression = 39, // =
    black_hole = 40, // _
    last_inserted = 41, // .
    filename = 42, // %
    alternate = 43, // #
    command = 44, // :
    last_search = 45, // /

    pub fn fromChar(c: u8) ?Register {
        return switch (c) {
            '"' => .unnamed,
            'a'...'z' => @enumFromInt(1 + (c - 'a')),
            '-' => .small_delete,
            '0' => .numbered_0,
            '1'...'9' => @enumFromInt(29 + (c - '1')),
            '+', '*' => .clipboard,
            '=' => .expression,
            '_' => .black_hole,
            '.' => .last_inserted,
            '%' => .filename,
            '#' => .alternate,
            ':' => .command,
            '/' => .last_search,
            else => null,
        };
    }

    /// Is this register read-only?
    pub fn isReadOnly(self: Register) bool {
        return switch (self) {
            .last_inserted, .filename, .alternate, .command, .last_search => true,
            else => false,
        };
    }
};

/// Register content
pub const RegisterContent = struct {
    text: []const u8,
    linewise: bool = false,
    blockwise: bool = false,
};

/// Vim state machine
pub const VimState = struct {
    allocator: std.mem.Allocator,

    /// Current mode
    mode: Mode = .normal,

    /// Pending operator
    operator: Operator = .none,

    /// Command count (e.g., 3dw means count=3)
    count: u32 = 0,

    /// Second count for operators (e.g., 2d3w)
    count2: u32 = 0,

    /// Selected register
    register: Register = .unnamed,

    /// Find character for f/t/F/T
    find_char: ?u8 = null,

    /// Last find direction (true = forward)
    find_forward: bool = true,

    /// Last find was 't' style (before char)
    find_before: bool = false,

    /// Command line buffer
    command_buffer: std.ArrayList(u8),

    /// Registers storage
    registers: std.AutoHashMap(Register, RegisterContent),

    /// Marks storage (lowercase = buffer local, uppercase = global)
    marks: std.AutoHashMap(u8, MarkPosition),

    /// Macro recording register
    recording_macro: ?Register = null,

    /// Macro buffers
    macros: std.AutoHashMap(Register, []const u8),

    /// Last change for repeat (.)
    last_change: ?ChangeRecord = null,

    /// Jump list
    jump_list: JumpList,

    /// Change list
    change_list: ChangeList,

    const MarkPosition = struct {
        line: u32,
        column: u32,
        file: ?[]const u8 = null,
    };

    const ChangeRecord = struct {
        operator: Operator,
        motion: ?Motion,
        text_object: ?TextObject,
        count: u32,
        inserted_text: ?[]const u8,
    };

    const JumpList = struct {
        positions: [100]MarkPosition = undefined,
        current: u8 = 0,
        count: u8 = 0,

        pub fn push(self: *JumpList, pos: MarkPosition) void {
            if (self.count < 100) {
                self.positions[self.count] = pos;
                self.count += 1;
                self.current = self.count;
            } else {
                // Shift and add new
                for (0..99) |i| {
                    self.positions[i] = self.positions[i + 1];
                }
                self.positions[99] = pos;
                self.current = 100;
            }
        }

        pub fn jumpBack(self: *JumpList) ?MarkPosition {
            if (self.current > 0) {
                self.current -= 1;
                return self.positions[self.current];
            }
            return null;
        }

        pub fn jumpForward(self: *JumpList) ?MarkPosition {
            if (self.current < self.count) {
                const pos = self.positions[self.current];
                self.current += 1;
                return pos;
            }
            return null;
        }
    };

    const ChangeList = struct {
        positions: [100]MarkPosition = undefined,
        current: u8 = 0,
        count: u8 = 0,

        pub fn push(self: *ChangeList, pos: MarkPosition) void {
            if (self.count < 100) {
                self.positions[self.count] = pos;
                self.count += 1;
                self.current = self.count;
            } else {
                for (0..99) |i| {
                    self.positions[i] = self.positions[i + 1];
                }
                self.positions[99] = pos;
                self.current = 100;
            }
        }
    };

    pub fn init(allocator: std.mem.Allocator) VimState {
        return .{
            .allocator = allocator,
            .command_buffer = .{},
            .registers = std.AutoHashMap(Register, RegisterContent).init(allocator),
            .marks = std.AutoHashMap(u8, MarkPosition).init(allocator),
            .macros = std.AutoHashMap(Register, []const u8).init(allocator),
            .jump_list = .{},
            .change_list = .{},
        };
    }

    pub fn deinit(self: *VimState) void {
        self.command_buffer.deinit(self.allocator);

        var reg_iter = self.registers.valueIterator();
        while (reg_iter.next()) |content| {
            self.allocator.free(content.text);
        }
        self.registers.deinit();

        var mark_iter = self.marks.valueIterator();
        while (mark_iter.next()) |mark| {
            if (mark.file) |f| {
                self.allocator.free(f);
            }
        }
        self.marks.deinit();

        var macro_iter = self.macros.valueIterator();
        while (macro_iter.next()) |macro_ptr| {
            self.allocator.free(macro_ptr.*);
        }
        self.macros.deinit();

        if (self.last_change) |change| {
            if (change.inserted_text) |text| {
                self.allocator.free(text);
            }
        }
    }

    /// Reset operator state
    pub fn resetOperator(self: *VimState) void {
        self.operator = .none;
        self.count = 0;
        self.count2 = 0;
        self.register = .unnamed;
        if (self.mode == .operator_pending) {
            self.mode = .normal;
        }
    }

    /// Get effective count (count * count2, min 1)
    pub fn getCount(self: *const VimState) u32 {
        const c1 = if (self.count > 0) self.count else 1;
        const c2 = if (self.count2 > 0) self.count2 else 1;
        return c1 * c2;
    }

    /// Set register content
    pub fn setRegister(self: *VimState, reg: Register, text: []const u8, linewise: bool) !void {
        if (reg.isReadOnly()) return;

        // Free existing content
        if (self.registers.get(reg)) |existing| {
            self.allocator.free(existing.text);
        }

        const copied = try self.allocator.dupe(u8, text);
        try self.registers.put(reg, .{
            .text = copied,
            .linewise = linewise,
        });

        // Also update unnamed register for most operations
        if (reg != .unnamed and reg != .black_hole) {
            if (self.registers.get(.unnamed)) |existing| {
                self.allocator.free(existing.text);
            }
            const unnamed_copy = try self.allocator.dupe(u8, text);
            try self.registers.put(.unnamed, .{
                .text = unnamed_copy,
                .linewise = linewise,
            });
        }
    }

    /// Get register content
    pub fn getRegister(self: *const VimState, reg: Register) ?RegisterContent {
        return self.registers.get(reg);
    }

    /// Set mark
    pub fn setMark(self: *VimState, mark: u8, line: u32, column: u32, file: ?[]const u8) !void {
        // Free existing file path
        if (self.marks.get(mark)) |existing| {
            if (existing.file) |f| {
                self.allocator.free(f);
            }
        }

        const copied_file = if (file) |f| try self.allocator.dupe(u8, f) else null;
        try self.marks.put(mark, .{
            .line = line,
            .column = column,
            .file = copied_file,
        });
    }

    /// Get mark
    pub fn getMark(self: *const VimState, mark: u8) ?MarkPosition {
        return self.marks.get(mark);
    }

    /// Enter insert mode
    pub fn enterInsert(self: *VimState) void {
        self.mode = .insert;
        self.resetOperator();
    }

    /// Enter normal mode
    pub fn enterNormal(self: *VimState) void {
        self.mode = .normal;
        self.resetOperator();
    }

    /// Enter visual mode
    pub fn enterVisual(self: *VimState, line_mode: bool, block_mode: bool) void {
        if (block_mode) {
            self.mode = .visual_block;
        } else if (line_mode) {
            self.mode = .visual_line;
        } else {
            self.mode = .visual;
        }
        self.resetOperator();
    }

    /// Enter command mode
    pub fn enterCommand(self: *VimState) void {
        self.mode = .command;
        self.command_buffer.clearRetainingCapacity();
    }
};

/// Key input result
pub const KeyResult = struct {
    /// Whether the key was handled
    handled: bool = false,

    /// New mode (if changed)
    new_mode: ?Mode = null,

    /// Action to perform
    action: Action = .none,

    /// Motion to execute
    motion: ?Motion = null,

    /// Text object to select
    text_object: ?TextObject = null,

    /// Character for find/till
    char: ?u8 = null,

    /// Error message
    error_msg: ?[]const u8 = null,
};

/// Action to perform
pub const Action = enum(u8) {
    none,

    // Cursor movement
    move_cursor,

    // Mode changes
    enter_insert,
    enter_insert_after,
    enter_insert_line_start,
    enter_insert_line_end,
    enter_insert_new_line_below,
    enter_insert_new_line_above,
    enter_normal,
    enter_visual,
    enter_visual_line,
    enter_visual_block,
    enter_command,
    enter_replace,

    // Operations
    delete,
    change,
    yank,
    put_after,
    put_before,
    undo,
    redo,
    repeat_last,
    indent_right,
    indent_left,
    join_lines,

    // Search
    search_forward,
    search_backward,
    search_next,
    search_prev,
    search_word_under_cursor,
    search_word_under_cursor_back,

    // Scrolling
    scroll_up,
    scroll_down,
    scroll_half_up,
    scroll_half_down,
    scroll_page_up,
    scroll_page_down,
    scroll_line_center,
    scroll_line_top,
    scroll_line_bottom,

    // Commands
    save,
    quit,
    save_quit,
    force_quit,

    // Macros
    record_macro,
    play_macro,
};

/// Process a key input in vim mode
pub fn processKey(state: *VimState, key: u8, modifiers: KeyModifiers) KeyResult {
    return switch (state.mode) {
        .normal => processNormalKey(state, key, modifiers),
        .insert => processInsertKey(state, key, modifiers),
        .visual, .visual_line, .visual_block => processVisualKey(state, key, modifiers),
        .command => processCommandKey(state, key, modifiers),
        .operator_pending => processOperatorPendingKey(state, key, modifiers),
        .replace => processReplaceKey(state, key, modifiers),
    };
}

/// Key modifiers
pub const KeyModifiers = struct {
    ctrl: bool = false,
    alt: bool = false,
    shift: bool = false,
    super: bool = false,
};

fn processNormalKey(state: *VimState, key: u8, mods: KeyModifiers) KeyResult {
    var result = KeyResult{ .handled = true };

    // Handle Ctrl combinations
    if (mods.ctrl) {
        switch (key) {
            'r' => result.action = .redo,
            'u' => result.action = .scroll_half_up,
            'd' => result.action = .scroll_half_down,
            'b' => result.action = .scroll_page_up,
            'f' => result.action = .scroll_page_down,
            'e' => result.action = .scroll_down,
            'y' => result.action = .scroll_up,
            'o' => { // Jump back
                result.handled = true;
            },
            'i' => { // Jump forward
                result.handled = true;
            },
            '[' => { // Escape
                state.resetOperator();
            },
            else => result.handled = false,
        }
        return result;
    }

    // Handle counts
    if (key >= '1' and key <= '9') {
        state.count = state.count * 10 + (key - '0');
        return result;
    }
    if (key == '0' and state.count > 0) {
        state.count = state.count * 10;
        return result;
    }

    // Handle register prefix
    if (key == '"') {
        // Next key is register name
        return result;
    }

    // Check for motion
    if (Motion.fromKey(key, mods.shift)) |motion| {
        result.motion = motion;
        result.action = .move_cursor;
        return result;
    }

    // Check for operator
    if (Operator.fromChar(key)) |op| {
        if (state.operator == op) {
            // Double operator (dd, yy, cc, etc.)
            result.motion = .goto_line; // Current line
            result.action = switch (op) {
                .delete => .delete,
                .change => .change,
                .yank => .yank,
                else => .none,
            };
        } else {
            state.operator = op;
            state.mode = .operator_pending;
        }
        return result;
    }

    // Handle other normal mode keys
    switch (key) {
        // Mode changes
        'i' => result.action = .enter_insert,
        'a' => result.action = .enter_insert_after,
        'I' => result.action = .enter_insert_line_start,
        'A' => result.action = .enter_insert_line_end,
        'o' => result.action = .enter_insert_new_line_below,
        'O' => result.action = .enter_insert_new_line_above,
        'v' => result.action = .enter_visual,
        'V' => result.action = .enter_visual_line,
        ':' => result.action = .enter_command,
        'R' => result.action = .enter_replace,

        // Line movement
        '0' => {
            result.motion = .line_start;
            result.action = .move_cursor;
        },
        '^' => {
            result.motion = .line_first_non_blank;
            result.action = .move_cursor;
        },
        '$' => {
            result.motion = .line_end;
            result.action = .move_cursor;
        },
        'G' => {
            result.motion = .document_end;
            result.action = .move_cursor;
        },

        // Operations
        'x' => result.action = .delete, // Delete char under cursor
        'X' => result.action = .delete, // Delete char before cursor
        's' => result.action = .change, // Substitute char
        'S' => result.action = .change, // Substitute line
        'p' => result.action = .put_after,
        'P' => result.action = .put_before,
        'u' => result.action = .undo,
        'J' => result.action = .join_lines,
        '.' => result.action = .repeat_last,

        // Search
        '/' => result.action = .search_forward,
        '?' => result.action = .search_backward,
        'n' => result.action = .search_next,
        'N' => result.action = .search_prev,
        '*' => result.action = .search_word_under_cursor,
        '#' => result.action = .search_word_under_cursor_back,

        // Scrolling
        'z' => {
            // Wait for next key (zz, zt, zb)
        },

        // Macros
        'q' => result.action = .record_macro,
        '@' => result.action = .play_macro,

        else => result.handled = false,
    }

    return result;
}

fn processInsertKey(state: *VimState, key: u8, mods: KeyModifiers) KeyResult {
    var result = KeyResult{ .handled = true };

    if (mods.ctrl) {
        switch (key) {
            '[', 'c' => { // Escape
                result.action = .enter_normal;
                result.new_mode = .normal;
            },
            'w' => { // Delete word back
                result.handled = true;
            },
            'u' => { // Delete to line start
                result.handled = true;
            },
            'h' => { // Backspace
                result.handled = true;
            },
            else => result.handled = false,
        }
    } else if (key == 27) { // ESC
        result.action = .enter_normal;
        result.new_mode = .normal;
    } else {
        result.handled = false; // Let the editor handle the character
    }

    _ = state;
    return result;
}

fn processVisualKey(state: *VimState, key: u8, mods: KeyModifiers) KeyResult {
    var result = KeyResult{ .handled = true };

    if (mods.ctrl) {
        switch (key) {
            '[', 'c' => {
                result.action = .enter_normal;
                result.new_mode = .normal;
            },
            else => result.handled = false,
        }
        return result;
    }

    if (key == 27) { // ESC
        result.action = .enter_normal;
        result.new_mode = .normal;
        return result;
    }

    // Check for motion
    if (Motion.fromKey(key, mods.shift)) |motion| {
        result.motion = motion;
        result.action = .move_cursor;
        return result;
    }

    switch (key) {
        'd', 'x' => result.action = .delete,
        'c', 's' => result.action = .change,
        'y' => result.action = .yank,
        'v' => {
            if (state.mode == .visual) {
                result.action = .enter_normal;
                result.new_mode = .normal;
            } else {
                result.action = .enter_visual;
                result.new_mode = .visual;
            }
        },
        'V' => {
            if (state.mode == .visual_line) {
                result.action = .enter_normal;
                result.new_mode = .normal;
            } else {
                result.action = .enter_visual_line;
                result.new_mode = .visual_line;
            }
        },
        '>' => result.action = .indent_right,
        '<' => result.action = .indent_left,
        'o' => { // Swap visual anchor
            result.handled = true;
        },
        'O' => { // Swap visual anchor (block mode)
            result.handled = true;
        },
        else => result.handled = false,
    }

    return result;
}

fn processCommandKey(state: *VimState, key: u8, mods: KeyModifiers) KeyResult {
    var result = KeyResult{ .handled = true };
    _ = mods;

    switch (key) {
        27 => { // ESC
            result.action = .enter_normal;
            result.new_mode = .normal;
        },
        '\r', '\n' => { // Enter
            // Execute command
            const cmd = state.command_buffer.items;
            if (std.mem.eql(u8, cmd, "w")) {
                result.action = .save;
            } else if (std.mem.eql(u8, cmd, "q")) {
                result.action = .quit;
            } else if (std.mem.eql(u8, cmd, "wq") or std.mem.eql(u8, cmd, "x")) {
                result.action = .save_quit;
            } else if (std.mem.eql(u8, cmd, "q!")) {
                result.action = .force_quit;
            }
            result.new_mode = .normal;
        },
        127, 8 => { // Backspace
            if (state.command_buffer.items.len > 0) {
                _ = state.command_buffer.pop();
            } else {
                result.action = .enter_normal;
                result.new_mode = .normal;
            }
        },
        else => {
            state.command_buffer.append(state.allocator, key) catch {};
        },
    }

    return result;
}

fn processOperatorPendingKey(state: *VimState, key: u8, mods: KeyModifiers) KeyResult {
    var result = KeyResult{ .handled = true };

    if (key == 27 or (mods.ctrl and (key == '[' or key == 'c'))) {
        state.resetOperator();
        result.new_mode = .normal;
        return result;
    }

    // Check for motion
    if (Motion.fromKey(key, mods.shift)) |motion| {
        result.motion = motion;
        result.action = switch (state.operator) {
            .delete => .delete,
            .change => .change,
            .yank => .yank,
            .indent_right => .indent_right,
            .indent_left => .indent_left,
            else => .none,
        };
        state.resetOperator();
        return result;
    }

    // Check for text object
    if (key == 'i' or key == 'a') {
        // Need next key for text object
        state.count2 = key;
        return result;
    }

    if (state.count2 == 'i' or state.count2 == 'a') {
        if (TextObject.fromChars(@intCast(state.count2), key)) |text_obj| {
            result.text_object = text_obj;
            result.action = switch (state.operator) {
                .delete => .delete,
                .change => .change,
                .yank => .yank,
                else => .none,
            };
            state.resetOperator();
            return result;
        }
    }

    result.handled = false;
    return result;
}

fn processReplaceKey(state: *VimState, key: u8, mods: KeyModifiers) KeyResult {
    var result = KeyResult{ .handled = true };

    if (key == 27 or (mods.ctrl and (key == '[' or key == 'c'))) {
        result.action = .enter_normal;
        result.new_mode = .normal;
    } else {
        // Replace character
        result.char = key;
    }

    _ = state;
    return result;
}

// Tests
test "mode names" {
    try std.testing.expectEqualStrings("NORMAL", Mode.normal.name());
    try std.testing.expectEqualStrings("INSERT", Mode.insert.name());
    try std.testing.expectEqualStrings("VISUAL", Mode.visual.name());
}

test "operator from char" {
    try std.testing.expectEqual(Operator.delete, Operator.fromChar('d'));
    try std.testing.expectEqual(Operator.yank, Operator.fromChar('y'));
    try std.testing.expect(Operator.fromChar('z') == null);
}

test "motion from key" {
    try std.testing.expectEqual(Motion.char_left, Motion.fromKey('h', false));
    try std.testing.expectEqual(Motion.word_start, Motion.fromKey('w', false));
    try std.testing.expectEqual(Motion.big_word_start, Motion.fromKey('w', true));
}

test "text object from chars" {
    try std.testing.expectEqual(TextObject.inner_word, TextObject.fromChars('i', 'w'));
    try std.testing.expectEqual(TextObject.a_paren, TextObject.fromChars('a', '('));
}

test "register from char" {
    try std.testing.expectEqual(Register.unnamed, Register.fromChar('"'));
    try std.testing.expectEqual(Register.named_a, Register.fromChar('a'));
    try std.testing.expectEqual(Register.clipboard, Register.fromChar('+'));
}

test "vim state init/deinit" {
    const allocator = std.testing.allocator;
    var state = VimState.init(allocator);
    defer state.deinit();

    try std.testing.expectEqual(Mode.normal, state.mode);
    try std.testing.expectEqual(Operator.none, state.operator);
}

test "vim state count" {
    const allocator = std.testing.allocator;
    var state = VimState.init(allocator);
    defer state.deinit();

    state.count = 3;
    state.count2 = 2;
    try std.testing.expectEqual(@as(u32, 6), state.getCount());

    state.count = 0;
    state.count2 = 0;
    try std.testing.expectEqual(@as(u32, 1), state.getCount());
}

test "vim register operations" {
    const allocator = std.testing.allocator;
    var state = VimState.init(allocator);
    defer state.deinit();

    try state.setRegister(.named_a, "hello", false);

    const content = state.getRegister(.named_a);
    try std.testing.expect(content != null);
    try std.testing.expectEqualStrings("hello", content.?.text);
}

test "process normal key" {
    const allocator = std.testing.allocator;
    var state = VimState.init(allocator);
    defer state.deinit();

    const result = processKey(&state, 'i', .{});
    try std.testing.expect(result.handled);
    try std.testing.expectEqual(Action.enter_insert, result.action);
}

test "process motion key" {
    const allocator = std.testing.allocator;
    var state = VimState.init(allocator);
    defer state.deinit();

    const result = processKey(&state, 'w', .{});
    try std.testing.expect(result.handled);
    try std.testing.expectEqual(Action.move_cursor, result.action);
    try std.testing.expectEqual(Motion.word_start, result.motion);
}
