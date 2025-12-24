//! Device Lab - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum {
    column,
    row,
    div,
    text,
    button,
    scroll,
    icon,
    progress,
    spacer,
};

pub const Alignment = enum { start, center, end, stretch };
pub const Justify = enum { start, center, end, space_between, space_around };

pub const Spacing = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,

    pub fn all(v: f32) Spacing {
        return .{ .top = v, .right = v, .bottom = v, .left = v };
    }

    pub fn symmetric(h: f32, v: f32) Spacing {
        return .{ .top = v, .right = h, .bottom = v, .left = h };
    }
};

pub const Style = struct {
    padding: Spacing = .{},
    margin: Spacing = .{},
    background: u32 = 0,
    border_radius: f32 = 0,
    font_size: f32 = 14,
    font_weight: u16 = 400,
    color: u32 = Color.text,
    alignment: Alignment = .start,
    justify: Justify = .start,
    gap: f32 = 0,
    flex: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

pub const Color = struct {
    pub const background: u32 = 0xFF1C1C1E;
    pub const surface: u32 = 0xFF2C2C2E;
    pub const card: u32 = 0xFF3A3A3C;
    pub const text: u32 = 0xFFFFFFFF;
    pub const text_secondary: u32 = 0xFF8E8E93;
    pub const primary: u32 = 0xFF007AFF;
    pub const success: u32 = 0xFF34C759;
    pub const warning: u32 = 0xFFFF9500;
    pub const error_color: u32 = 0xFFFF3B30;
    pub const motion: u32 = 0xFF5856D6;
    pub const location: u32 = 0xFF34C759;
    pub const camera: u32 = 0xFFFF9500;
    pub const biometric: u32 = 0xFFFF2D55;
    pub const haptic: u32 = 0xFF5AC8FA;
    pub const notification: u32 = 0xFFFFCC00;
    pub const device: u32 = 0xFF8E8E93;
};

pub const Props = struct {
    style: Style = .{},
    on_press: ?*const fn () void = null,
    text: []const u8 = "",
    icon: []const u8 = "",
    value: f32 = 0,
};

pub const VNode = struct {
    tag: Tag,
    props: Props,
    children: []const VNode,
};

// Component constructors
fn column(props: Props, children: []const VNode) VNode {
    return .{ .tag = .column, .props = props, .children = children };
}

fn row(props: Props, children: []const VNode) VNode {
    return .{ .tag = .row, .props = props, .children = children };
}

fn div(props: Props, children: []const VNode) VNode {
    return .{ .tag = .div, .props = props, .children = children };
}

fn text(content: []const u8, props: Props) VNode {
    var p = props;
    p.text = content;
    return .{ .tag = .text, .props = p, .children = &.{} };
}

fn button(label: []const u8, props: Props) VNode {
    var p = props;
    p.text = label;
    return .{ .tag = .button, .props = p, .children = &.{} };
}

fn iconView(name: []const u8, props: Props) VNode {
    var p = props;
    p.icon = name;
    return .{ .tag = .icon, .props = p, .children = &.{} };
}

fn progress(value: f32, props: Props) VNode {
    var p = props;
    p.value = value;
    return .{ .tag = .progress, .props = p, .children = &.{} };
}

fn scroll(props: Props, children: []const VNode) VNode {
    return .{ .tag = .scroll, .props = props, .children = children };
}

fn spacer() VNode {
    return .{ .tag = .spacer, .props = .{ .style = .{ .flex = 1 } }, .children = &.{} };
}

// Main app builder
pub fn buildApp(state: *const app.AppState) VNode {
    const S = struct {
        var content: [2]VNode = undefined;
    };

    S.content[0] = buildHeader(state);
    S.content[1] = buildContent(state);

    return column(.{
        .style = .{
            .background = Color.background,
            .padding = Spacing.all(16),
            .gap = 16,
        },
    }, &S.content);
}

fn buildHeader(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = text("Device Lab", .{
        .style = .{
            .font_size = 28,
            .font_weight = 700,
            .color = Color.text,
        },
    });
    S.items[1] = text(state.current_feature.description(), .{
        .style = .{
            .font_size = 14,
            .color = Color.text_secondary,
        },
    });

    return column(.{ .style = .{ .gap = 4 } }, &S.items);
}

fn buildContent(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = buildFeatureSelector(state);
    S.items[1] = buildFeatureContent(state);

    return column(.{ .style = .{ .gap = 16, .flex = 1 } }, &S.items);
}

fn buildFeatureSelector(state: *const app.AppState) VNode {
    const features = [_]app.Feature{ .motion, .location, .camera, .biometric, .haptic, .notification, .device_info };
    const S = struct {
        var items: [7]VNode = undefined;
    };

    for (features, 0..) |feature, i| {
        S.items[i] = buildFeatureTab(feature, state.current_feature == feature);
    }

    return scroll(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.symmetric(8, 8),
        },
    }, &S.items);
}

fn buildFeatureTab(feature: app.Feature, selected: bool) VNode {
    const bg = if (selected) getFeatureColor(feature) else 0;
    const text_color = if (selected) Color.text else Color.text_secondary;

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(feature.icon(), .{
        .style = .{ .color = text_color },
    });
    S.items[1] = text(feature.title(), .{
        .style = .{ .font_size = 12, .color = text_color },
    });

    return column(.{
        .style = .{
            .padding = Spacing.symmetric(12, 8),
            .background = bg,
            .border_radius = 8,
            .alignment = .center,
            .gap = 4,
        },
    }, &S.items);
}

fn getFeatureColor(feature: app.Feature) u32 {
    return switch (feature) {
        .motion => Color.motion,
        .location => Color.location,
        .camera => Color.camera,
        .biometric => Color.biometric,
        .haptic => Color.haptic,
        .notification => Color.notification,
        .device_info => Color.device,
    };
}

fn buildFeatureContent(state: *const app.AppState) VNode {
    return switch (state.current_feature) {
        .motion => buildMotionPanel(state),
        .location => buildLocationPanel(state),
        .camera => buildCameraPanel(state),
        .biometric => buildBiometricPanel(state),
        .haptic => buildHapticPanel(state),
        .notification => buildNotificationPanel(state),
        .device_info => buildDeviceInfoPanel(state),
    };
}

// Motion Panel
fn buildMotionPanel(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = buildSensorCard("Accelerometer", &.{
        buildAxisRow("X", state.accelerometer.x),
        buildAxisRow("Y", state.accelerometer.y),
        buildAxisRow("Z", state.accelerometer.z),
    });
    S.items[1] = buildSensorCard("Gyroscope", &.{
        buildAxisRow("X", state.gyroscope.x),
        buildAxisRow("Y", state.gyroscope.y),
        buildAxisRow("Z", state.gyroscope.z),
    });
    S.items[2] = buildCompassCard(state.compass_heading);
    S.items[3] = buildShakeIndicator(state.shake_detected);

    return column(.{ .style = .{ .gap = 12 } }, &S.items);
}

fn buildSensorCard(title_text: []const u8, rows: []const VNode) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = text(title_text, .{
        .style = .{ .font_size = 16, .font_weight = 600, .color = Color.text },
    });
    S.items[1] = column(.{ .style = .{ .gap = 4 } }, rows);

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 8,
        },
    }, &S.items);
}

fn buildAxisRow(axis: []const u8, value: f32) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var buf: [16]u8 = undefined;
    };

    const value_str = std.fmt.bufPrint(&S.buf, "{d:.3}", .{value}) catch "0.000";

    S.items[0] = text(axis, .{
        .style = .{ .font_size = 14, .color = Color.text_secondary, .width = 20 },
    });
    S.items[1] = progress(@abs(value) / 10.0, .{
        .style = .{ .flex = 1, .height = 8 },
    });
    S.items[2] = text(value_str, .{
        .style = .{ .font_size = 14, .color = Color.text, .width = 60, .alignment = .end },
    });

    return row(.{ .style = .{ .gap = 8, .alignment = .center } }, &S.items);
}

fn buildCompassCard(heading: f32) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
        var buf: [16]u8 = undefined;
    };

    const heading_str = std.fmt.bufPrint(&S.buf, "{d:.1}°", .{heading}) catch "0°";

    S.items[0] = iconView("location.north.fill", .{
        .style = .{ .color = Color.primary, .font_size = 48 },
    });
    S.items[1] = text(heading_str, .{
        .style = .{ .font_size = 24, .font_weight = 600, .color = Color.text },
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(24),
            .alignment = .center,
            .gap = 8,
        },
    }, &S.items);
}

fn buildShakeIndicator(detected: bool) VNode {
    const bg = if (detected) Color.warning else Color.card;
    const label = if (detected) "Shake Detected!" else "Shake to test";

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView("waveform.path", .{
        .style = .{ .color = Color.text, .font_size = 24 },
    });
    S.items[1] = text(label, .{
        .style = .{ .font_size = 16, .color = Color.text },
    });

    return row(.{
        .style = .{
            .background = bg,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 12,
            .alignment = .center,
            .justify = .center,
        },
    }, &S.items);
}

// Location Panel
fn buildLocationPanel(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = buildPermissionCard("Location", state.location_permission);
    S.items[1] = buildCoordinatesCard(state);
    S.items[2] = buildDistanceCard(state);

    return column(.{ .style = .{ .gap = 12 } }, &S.items);
}

fn buildCoordinatesCard(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var lat_buf: [24]u8 = undefined;
        var lon_buf: [24]u8 = undefined;
        var acc_buf: [16]u8 = undefined;
    };

    const lat_str = std.fmt.bufPrint(&S.lat_buf, "Lat: {d:.6}", .{state.location.latitude}) catch "Lat: 0.000000";
    const lon_str = std.fmt.bufPrint(&S.lon_buf, "Lon: {d:.6}", .{state.location.longitude}) catch "Lon: 0.000000";
    const acc_str = std.fmt.bufPrint(&S.acc_buf, "±{d:.1}m", .{state.location.accuracy}) catch "±0m";

    S.items[0] = text(lat_str, .{
        .style = .{ .font_size = 16, .color = Color.text },
    });
    S.items[1] = text(lon_str, .{
        .style = .{ .font_size = 16, .color = Color.text },
    });
    S.items[2] = text(acc_str, .{
        .style = .{ .font_size = 14, .color = Color.text_secondary },
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 8,
        },
    }, &S.items);
}

fn buildDistanceCard(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
        var buf: [32]u8 = undefined;
    };

    const dist_str = if (state.distance_traveled >= 1000)
        std.fmt.bufPrint(&S.buf, "{d:.2} km", .{state.distance_traveled / 1000}) catch "0 km"
    else
        std.fmt.bufPrint(&S.buf, "{d:.0} m", .{state.distance_traveled}) catch "0 m";

    const status = if (state.location_tracking) "Tracking Active" else "Tracking Stopped";

    S.items[0] = text(dist_str, .{
        .style = .{ .font_size = 32, .font_weight = 700, .color = Color.location },
    });
    S.items[1] = text(status, .{
        .style = .{ .font_size = 14, .color = Color.text_secondary },
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(24),
            .alignment = .center,
            .gap = 8,
        },
    }, &S.items);
}

// Camera Panel
fn buildCameraPanel(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = buildPermissionCard("Camera", state.camera_permission);
    S.items[1] = buildCameraControls(state);
    S.items[2] = buildQRResult(state);

    return column(.{ .style = .{ .gap = 12 } }, &S.items);
}

fn buildCameraControls(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var count_buf: [16]u8 = undefined;
    };

    const count_str = std.fmt.bufPrint(&S.count_buf, "{d} photos", .{state.photo_count}) catch "0 photos";

    S.items[0] = button("Take Photo", .{
        .style = .{
            .background = Color.camera,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });
    S.items[1] = button(if (state.video_recording) "Stop Recording" else "Record Video", .{
        .style = .{
            .background = if (state.video_recording) Color.error_color else Color.primary,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });
    S.items[2] = text(count_str, .{
        .style = .{ .font_size = 14, .color = Color.text_secondary },
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 12,
        },
    }, &S.items);
}

fn buildQRResult(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    const result = if (state.qr_result_len > 0) state.qr_result[0..state.qr_result_len] else "No QR code scanned";

    S.items[0] = text("QR Scanner", .{
        .style = .{ .font_size = 16, .font_weight = 600, .color = Color.text },
    });
    S.items[1] = text(result, .{
        .style = .{ .font_size = 14, .color = Color.text_secondary },
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 8,
        },
    }, &S.items);
}

// Biometric Panel
fn buildBiometricPanel(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = buildBiometricType(state);
    S.items[1] = buildBiometricStatus(state);
    S.items[2] = buildBiometricButton(state);

    return column(.{ .style = .{ .gap = 12 } }, &S.items);
}

fn buildBiometricType(state: *const app.AppState) VNode {
    const type_name = switch (state.biometric_type) {
        .none => "Not Available",
        .touch_id => "Touch ID",
        .face_id => "Face ID",
        .fingerprint => "Fingerprint",
        .face_unlock => "Face Unlock",
    };

    const icon_name = switch (state.biometric_type) {
        .none => "xmark.circle",
        .touch_id, .fingerprint => "touchid",
        .face_id, .face_unlock => "faceid",
    };

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(icon_name, .{
        .style = .{ .color = Color.biometric, .font_size = 64 },
    });
    S.items[1] = text(type_name, .{
        .style = .{ .font_size = 20, .font_weight = 600, .color = Color.text },
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(32),
            .alignment = .center,
            .gap = 16,
        },
    }, &S.items);
}

fn buildBiometricStatus(state: *const app.AppState) VNode {
    const status = if (state.auth_in_progress)
        "Authenticating..."
    else if (state.biometric_authenticated)
        "Authenticated"
    else
        "Not authenticated";

    const color = if (state.biometric_authenticated) Color.success else Color.text_secondary;

    return text(status, .{
        .style = .{
            .font_size = 16,
            .color = color,
            .alignment = .center,
        },
    });
}

fn buildBiometricButton(state: *const app.AppState) VNode {
    const enabled = state.biometric_available and !state.auth_in_progress;
    const bg = if (enabled) Color.biometric else Color.card;

    return button("Authenticate", .{
        .style = .{
            .background = bg,
            .padding = Spacing.symmetric(32, 16),
            .border_radius = 12,
        },
    });
}

// Haptic Panel
fn buildHapticPanel(state: *const app.AppState) VNode {
    const types = [_]app.HapticType{ .light, .medium, .heavy, .selection, .success, .warning, .error_feedback };
    const S = struct {
        var items: [7]VNode = undefined;
    };

    for (types, 0..) |haptic_type, i| {
        S.items[i] = buildHapticButton(haptic_type, state.last_haptic == haptic_type);
    }

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 8,
        },
    }, &S.items);
}

fn buildHapticButton(haptic_type: app.HapticType, selected: bool) VNode {
    const bg = if (selected) Color.haptic else Color.card;

    return button(haptic_type.name(), .{
        .style = .{
            .background = bg,
            .padding = Spacing.symmetric(16, 12),
            .border_radius = 8,
        },
    });
}

// Notification Panel
fn buildNotificationPanel(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = buildPermissionCard("Notifications", state.notification_permission);
    S.items[1] = buildNotificationStats(state);
    S.items[2] = buildNotificationActions();

    return column(.{ .style = .{ .gap = 12 } }, &S.items);
}

fn buildNotificationStats(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
        var sched_buf: [32]u8 = undefined;
        var badge_buf: [32]u8 = undefined;
    };

    const sched_str = std.fmt.bufPrint(&S.sched_buf, "Scheduled: {d}", .{state.scheduled_count}) catch "Scheduled: 0";
    const badge_str = std.fmt.bufPrint(&S.badge_buf, "Badge: {d}", .{state.badge_count}) catch "Badge: 0";

    S.items[0] = text(sched_str, .{
        .style = .{ .font_size = 16, .color = Color.text },
    });
    S.items[1] = text(badge_str, .{
        .style = .{ .font_size = 16, .color = Color.text },
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 8,
        },
    }, &S.items);
}

fn buildNotificationActions() VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = button("Schedule Notification", .{
        .style = .{
            .background = Color.notification,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });
    S.items[1] = button("Clear Badge", .{
        .style = .{
            .background = Color.card,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    return row(.{ .style = .{ .gap = 12 } }, &S.items);
}

// Device Info Panel
fn buildDeviceInfoPanel(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = buildPlatformInfo(state);
    S.items[1] = buildBatteryInfo(state);
    S.items[2] = buildNetworkInfo(state);

    return column(.{ .style = .{ .gap = 12 } }, &S.items);
}

fn buildPlatformInfo(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var screen_buf: [32]u8 = undefined;
    };

    const platform = if (state.platform_len > 0) state.platform[0..state.platform_len] else "Unknown";
    const version = if (state.os_version_len > 0) state.os_version[0..state.os_version_len] else "Unknown";
    const model = if (state.device_model_len > 0) state.device_model[0..state.device_model_len] else "Unknown";
    const screen_str = std.fmt.bufPrint(&S.screen_buf, "{d} x {d}", .{ state.screen_width, state.screen_height }) catch "0 x 0";

    S.items[0] = buildInfoRow("Platform", platform);
    S.items[1] = buildInfoRow("Version", version);
    S.items[2] = buildInfoRow("Model", model);
    S.items[3] = buildInfoRow("Screen", screen_str);

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 8,
        },
    }, &S.items);
}

fn buildBatteryInfo(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var level_buf: [8]u8 = undefined;
    };

    const level_str = std.fmt.bufPrint(&S.level_buf, "{d}%", .{@as(u32, @intFromFloat(state.battery_level * 100))}) catch "0%";
    const status = if (state.battery_charging) "Charging" else "Not Charging";

    const icon_name = if (state.battery_charging)
        "battery.100.bolt"
    else if (state.battery_level > 0.5)
        "battery.75"
    else if (state.battery_level > 0.2)
        "battery.25"
    else
        "battery.0";

    S.items[0] = iconView(icon_name, .{
        .style = .{ .color = if (state.battery_level < 0.2) Color.error_color else Color.success, .font_size = 32 },
    });
    S.items[1] = text(level_str, .{
        .style = .{ .font_size = 24, .font_weight = 600, .color = Color.text },
    });
    S.items[2] = text(status, .{
        .style = .{ .font_size = 14, .color = Color.text_secondary },
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .alignment = .center,
            .gap = 8,
        },
    }, &S.items);
}

fn buildNetworkInfo(state: *const app.AppState) VNode {
    const status = switch (state.network_status) {
        .unknown => "Unknown",
        .disconnected => "Disconnected",
        .wifi => "Wi-Fi",
        .cellular => "Cellular",
    };

    const icon_name = switch (state.network_status) {
        .unknown => "questionmark.circle",
        .disconnected => "wifi.slash",
        .wifi => "wifi",
        .cellular => "antenna.radiowaves.left.and.right",
    };

    const color = switch (state.network_status) {
        .unknown => Color.text_secondary,
        .disconnected => Color.error_color,
        .wifi, .cellular => Color.success,
    };

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(icon_name, .{
        .style = .{ .color = color, .font_size = 24 },
    });
    S.items[1] = text(status, .{
        .style = .{ .font_size = 16, .color = Color.text },
    });

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 12,
            .alignment = .center,
        },
    }, &S.items);
}

// Permission card helper
fn buildPermissionCard(feature_name: []const u8, permission: app.PermissionState) VNode {
    const status = switch (permission) {
        .unknown => "Not Requested",
        .granted => "Granted",
        .denied => "Denied",
        .restricted => "Restricted",
    };

    const color = switch (permission) {
        .unknown => Color.text_secondary,
        .granted => Color.success,
        .denied, .restricted => Color.error_color,
    };

    const S = struct {
        var items: [2]VNode = undefined;
        var label_buf: [64]u8 = undefined;
    };

    const label = std.fmt.bufPrint(&S.label_buf, "{s} Permission", .{feature_name}) catch "Permission";

    S.items[0] = text(label, .{
        .style = .{ .font_size = 14, .color = Color.text_secondary },
    });
    S.items[1] = text(status, .{
        .style = .{ .font_size = 16, .font_weight = 600, .color = color },
    });

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .justify = .space_between,
            .alignment = .center,
        },
    }, &S.items);
}

fn buildInfoRow(label: []const u8, value: []const u8) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = text(label, .{
        .style = .{ .font_size = 14, .color = Color.text_secondary },
    });
    S.items[1] = text(value, .{
        .style = .{ .font_size = 14, .color = Color.text },
    });

    return row(.{
        .style = .{ .justify = .space_between },
    }, &S.items);
}

// Tests
test "build app" {
    app.init();
    defer app.deinit();
    const view = buildApp(app.getState());
    try std.testing.expectEqual(Tag.column, view.tag);
}

test "feature colors" {
    try std.testing.expectEqual(Color.motion, getFeatureColor(.motion));
    try std.testing.expectEqual(Color.biometric, getFeatureColor(.biometric));
}
