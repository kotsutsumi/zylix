//! Whisper Backend Stub Module
//!
//! Provides stub types for platforms without native C support.

const std = @import("std");

/// Stub - platform not supported
pub fn isAvailable() bool {
    return false;
}
