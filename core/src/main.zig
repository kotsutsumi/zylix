//! Zylix Core - Cross-platform application runtime
//!
//! This is the central brain of Zylix applications.
//! It manages state, handles events, and provides C ABI exports
//! for platform shells (iOS/Android/Desktop).

const std = @import("std");
pub const state = @import("state.zig");
pub const events = @import("events.zig");
pub const abi = @import("abi.zig");
pub const ai = @import("ai/ai.zig");
pub const animation = @import("animation/animation.zig");
pub const graphics3d = @import("graphics3d/graphics3d.zig");
pub const integration = @import("integration/integration.zig");
pub const tooling = @import("tooling/tooling.zig");
pub const nodeflow = @import("nodeflow/nodeflow.zig");
pub const pdf = @import("pdf/pdf.zig");
pub const excel = @import("excel/excel.zig");
pub const mbaas = @import("mbaas/mbaas.zig");
pub const server = @import("server/server.zig");

// Re-export types for internal use
pub const State = state.State;
pub const AppState = state.AppState;
pub const UIState = state.UIState;
pub const EventType = events.EventType;

// Re-export AI types
pub const ModelType = ai.ModelType;
pub const ModelConfig = ai.ModelConfig;
pub const ModelFormat = ai.ModelFormat;

// Re-export Graphics3D types
pub const Vec3 = graphics3d.Vec3;
pub const Mat4 = graphics3d.Mat4;
pub const Camera = graphics3d.Camera;
pub const Scene = graphics3d.Scene;
pub const Mesh = graphics3d.Mesh;

// Re-export PDF types
pub const PdfDocument = pdf.Document;
pub const PdfPage = pdf.Page;
pub const PageSize = pdf.PageSize;

// Re-export Excel types
pub const ExcelWorkbook = excel.Workbook;
pub const ExcelWorksheet = excel.Worksheet;
pub const ExcelCell = excel.Cell;

// Re-export mBaaS types
pub const MbaasClient = mbaas.Client;
pub const MbaasProvider = mbaas.Provider;
pub const FirebaseClient = mbaas.FirebaseClient;
pub const SupabaseClient = mbaas.SupabaseClient;
pub const AmplifyClient = mbaas.AmplifyClient;

// Re-export Server types
pub const Zylix = server.Zylix;
pub const HttpRequest = server.Request;
pub const HttpResponse = server.Response;
pub const HttpRouter = server.Router;
pub const HttpContext = server.Context;
pub const HttpHandler = server.Handler;
pub const RpcServer = server.RpcServer;

// Force the abi module to be analyzed (which triggers @export)
comptime {
    _ = abi;
}

test {
    std.testing.refAllDecls(@This());
}
