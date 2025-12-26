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
pub const edge = @import("edge/edge.zig");
pub const perf = @import("perf/perf.zig");
pub const markdown = @import("markdown/markdown.zig");
pub const buffer = @import("buffer/buffer.zig");
pub const editor = @import("editor/editor.zig");

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

// Re-export Edge types
pub const EdgePlatform = edge.Platform;
pub const EdgeRequest = edge.EdgeRequest;
pub const EdgeResponse = edge.EdgeResponse;
pub const UnifiedAdapter = edge.UnifiedAdapter;
pub const CloudflareAdapter = edge.CloudflareAdapter;
pub const VercelAdapter = edge.VercelAdapter;
pub const LambdaAdapter = edge.LambdaAdapter;
pub const AzureAdapter = edge.AzureAdapter;
pub const DenoAdapter = edge.DenoAdapter;
pub const GCPAdapter = edge.GCPAdapter;
pub const FastlyAdapter = edge.FastlyAdapter;

// Re-export Performance types
pub const PerfConfig = perf.PerfConfig;
pub const PerfMetrics = perf.PerfMetrics;
pub const Profiler = perf.Profiler;
pub const VDomOptimizer = perf.VDomOptimizer;
pub const MemoryPool = perf.MemoryPool;
pub const RenderBatcher = perf.RenderBatcher;
pub const FrameScheduler = perf.FrameScheduler;
pub const ErrorBoundary = perf.ErrorBoundary;
pub const CrashReporter = perf.CrashReporter;
pub const AnalyticsHook = perf.AnalyticsHook;
pub const BundleAnalyzer = perf.BundleAnalyzer;
pub const TreeShaker = perf.TreeShaker;

// Re-export Markdown types
pub const MarkdownParser = markdown.MarkdownParser;
pub const MarkdownNode = markdown.Node;
pub const MarkdownOptions = markdown.ParserOptions;
pub const MarkdownRenderer = markdown.HtmlRenderer;

// Re-export Buffer types
pub const TextBuffer = buffer.TextBuffer;

// Re-export Editor types
pub const SyntaxHighlighter = editor.SyntaxHighlighter;
pub const TokenType = editor.TokenType;
pub const TokenSpan = editor.TokenSpan;
pub const Theme = editor.Theme;
pub const LanguageId = editor.LanguageId;

// Re-export Vim types
pub const VimMode = editor.VimMode;
pub const VimState = editor.VimState;
pub const VimAction = editor.VimAction;

// Force the abi module to be analyzed (which triggers @export)
comptime {
    _ = abi;
    _ = @import("buffer/abi.zig");
}

test {
    std.testing.refAllDecls(@This());
}
