const std = @import("std");
const libmagic = @cImport({
    @cInclude("magic.h");
});
const Allocator = std.mem.Allocator;

pub fn checkMIME(filename: [:0]const u8, arena: Allocator) ![:0]u8 {
    const magic_cookie = libmagic.magic_open(libmagic.MAGIC_MIME_TYPE);
    defer libmagic.magic_close(magic_cookie);

    _ = libmagic.magic_load(magic_cookie, 0); // 0 -> use default magic database
    const mime = libmagic.magic_file(magic_cookie, filename);

    const d_verbose: bool = false;
    if (comptime d_verbose) {
        const cwd: std.fs.Dir = std.fs.cwd();
        var path: [1024]u8 = undefined;
        const rp = try cwd.realpath(".", &path);
        std.debug.print("Current directory: {s}\n", .{rp});
        std.debug.print("Detected filetype: {s}\n", .{mime});
    }

    const cstr_as_zig_slice_on_stack = std.mem.span(mime);
    const mime_copy_on_heap = try arena.dupeZ(u8, cstr_as_zig_slice_on_stack);
    return mime_copy_on_heap;
}
