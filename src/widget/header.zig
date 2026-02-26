const std = @import("std");
const vaxis = @import("vaxis");

pub fn create_headerEndingWithUnicode(arena: std.mem.Allocator, max_width: u16, title: []const u8, unicode: []const u8) !vaxis.vxfw.Text {
    const base_title = title;
    const title_cells = std.unicode.utf8CountCodepoints(base_title) catch unreachable;
    const dashes_needed = if (max_width > title_cells) max_width - title_cells else 0;
    const total_bytes = base_title.len + (dashes_needed * unicode.len);
    var header_buf = try arena.alloc(u8, total_bytes);
    @memcpy(header_buf[0..base_title.len], base_title);
    var offset: usize = base_title.len;
    for (0..dashes_needed) |_| {
        @memcpy(header_buf[offset .. offset + unicode.len], unicode);
        offset += unicode.len;
    }
    return .{ .text = header_buf, .style = .{ .bold = true } };
}

pub fn create_headerStartingWithUnicode(arena: std.mem.Allocator, max_width: u16, title: []const u8, unicode: []const u8) !vaxis.vxfw.Text {
    const title_cells = std.unicode.utf8CountCodepoints(title) catch unreachable;
    const dashes_needed = if (max_width > title_cells) max_width - title_cells else 0;
    const total_bytes = title.len + (dashes_needed * unicode.len);
    var header_buf = try arena.alloc(u8, total_bytes);
    var offset: usize = 0;
    for (0..dashes_needed) |_| {
        @memcpy(header_buf[offset .. offset + unicode.len], unicode);
        offset += unicode.len;
    }
    @memcpy(header_buf[offset .. offset + title.len], title);
    return .{ .text = header_buf, .style = .{ .bold = true } };
}
