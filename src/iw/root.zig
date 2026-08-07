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
    if (mime == null) return error.MagicFileFailed;
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

pub fn findIsoImages(allocator: Allocator, dir_path: []const u8) ![][]const u8 {
    var results: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (results.items) |name| allocator.free(name);
        results.deinit(allocator);
    }

    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return results.toOwnedSlice(allocator),
        else => return err,
    };
    defer dir.close();

    // Scratch space for building full paths and holding the MIME-type strings checkMIME returns
    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();
    const scratch_alloc = scratch.allocator();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        if (entry.name.len < 4) continue;
        if (!std.ascii.eqlIgnoreCase(entry.name[entry.name.len - 4 ..], ".iso")) continue;

        const full_path = std.fs.path.joinZ(scratch_alloc, &.{ dir_path, entry.name }) catch continue;

        const mime = checkMIME(full_path, scratch_alloc) catch continue; // unreadable, skip it
        const looks_like_iso = std.mem.indexOf(u8, mime, "iso9660") != null or
            std.mem.eql(u8, mime, "application/x-cd-image");
        if (!looks_like_iso) continue;

        const owned_name = try allocator.dupe(u8, entry.name);
        try results.append(allocator, owned_name);
    }

    return results.toOwnedSlice(allocator);
}
