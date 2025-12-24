//! Zylix PDF - Cross-Platform PDF Document Handling
//!
//! Comprehensive PDF support for generating, reading, and editing PDF documents.
//! Inspired by pdf-nano and the PDF 1.7 specification.
//!
//! ## Features
//!
//! - **Generation**: Create PDFs with text, images, and vector graphics
//! - **Reading**: Parse PDFs and extract content
//! - **Editing**: Modify existing PDFs, merge, split
//! - **Cross-Platform**: Works on iOS, Android, macOS, Windows, Linux, Web
//!
//! ## Example
//!
//! ```zig
//! const pdf = @import("pdf");
//!
//! // Create a new document
//! var doc = try pdf.Document.create(allocator);
//! defer doc.deinit();
//!
//! // Add a page
//! var page = try doc.addPage(pdf.PageSize.A4);
//!
//! // Draw text
//! try page.setFont(.helvetica, 12);
//! try page.drawText("Hello, World!", 72, 720);
//!
//! // Save to file
//! try doc.saveToFile("output.pdf");
//! ```

const std = @import("std");

// Public type exports
pub const types = @import("types.zig");
pub const PageSize = types.PageSize;
pub const Orientation = types.Orientation;
pub const Rectangle = types.Rectangle;
pub const Point = types.Point;
pub const Color = types.Color;
pub const LineCap = types.LineCap;
pub const LineJoin = types.LineJoin;
pub const TextAlign = types.TextAlign;
pub const StandardFont = types.StandardFont;
pub const Metadata = types.Metadata;
pub const Margins = types.Margins;
pub const PdfVersion = types.PdfVersion;
pub const PdfError = types.PdfError;
pub const Compression = types.Compression;
pub const BlendMode = types.BlendMode;

// Module imports
pub const document = @import("document.zig");
pub const page = @import("page.zig");
pub const writer = @import("writer.zig");
pub const text = @import("text.zig");
pub const graphics = @import("graphics.zig");
pub const image = @import("image.zig");
pub const font = @import("font.zig");

// Main types
pub const Document = document.Document;
pub const Page = page.Page;
pub const Writer = writer.Writer;
pub const TextStyle = text.TextStyle;
pub const GraphicsState = graphics.GraphicsState;
pub const Path = graphics.Path;
pub const Image = image.Image;
pub const Font = font.Font;

/// Module version
pub const version = "0.18.0";

/// Create a new PDF document
pub fn createDocument(allocator: std.mem.Allocator) !*Document {
    return Document.create(allocator);
}

/// Open an existing PDF document
pub fn openDocument(allocator: std.mem.Allocator, data: []const u8) !*Document {
    return Document.open(allocator, data);
}

/// Open a PDF document from file
pub fn openFile(allocator: std.mem.Allocator, path: []const u8) !*Document {
    return Document.openFile(allocator, path);
}

// Unit tests
test "module imports" {
    _ = types;
    _ = document;
    _ = page;
    _ = writer;
    _ = text;
    _ = graphics;
    _ = image;
    _ = font;
}

test "version check" {
    try std.testing.expectEqualStrings("0.18.0", version);
}
