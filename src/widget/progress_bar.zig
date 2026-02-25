const std = @import("std");
const zush = @import("zush");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;
const Cell = vaxis.Cell;

const Allocator = std.mem.Allocator;

const ProgressBar = @This();

progress: u8,

pub fn widget(self: *const ProgressBar) vxfw.Widget {
    return .{
        .userdata = @constCast(self),
        .eventHandler = typeErasedEventHandler,
        .drawFn = typeErasedDrawFn,
    };
}

fn typeErasedEventHandler(_: *anyopaque, _: *vxfw.EventContext, _: vxfw.Event) anyerror!void {
    return;
}

fn typeErasedDrawFn(ptr: *anyopaque, ctx: vxfw.DrawContext) Allocator.Error!vxfw.Surface {
    const self: *ProgressBar = @ptrCast(@alignCast(ptr));
    return self.draw(ctx);
}

pub fn draw(self: *const ProgressBar, ctx: vxfw.DrawContext) Allocator.Error!vxfw.Surface {
    const ProgressBar_surface = try vxfw.Surface.init(ctx.arena, self.widget(), .{ .height = 1, .width = 10 });
    for (0..ProgressBar_surface.size.width) |i| {
        ProgressBar_surface.writeCell(@intCast(i), 0, .{ .char = Cell.Character{ .grapheme = "░" } });
        if (i < self.progress) ProgressBar_surface.writeCell(@intCast(i), 0, .{ .char = Cell.Character{ .grapheme = "█" } });
    }
    return ProgressBar_surface;
}
