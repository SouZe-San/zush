const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

pub const Model = struct {
    pub fn widget(self: *const Model) vxfw.Widget {
        return .{
            .userdata = @constCast(self),
            .eventHandler = Model.typeErasedEventHandler,
            .drawFn = Model.typeErasedDrawFn,
        };
    }

    fn typeErasedEventHandler(_: *anyopaque, _: *vxfw.EventContext, _: vxfw.Event) anyerror!void {
        return;
    }

    fn typeErasedDrawFn(ptr: *anyopaque, ctx: vxfw.DrawContext) std.mem.Allocator.Error!vxfw.Surface {
        const self: *Model = @ptrCast(@alignCast(ptr));

        const text = try ctx.arena.create(vxfw.Text);
        text.* = .{
            .text = "ISO checksum varification — coming soon.",
            .style = .{ .bg = .{ .rgb = .{ 40, 40, 40 } } },
        };
        const centered = try ctx.arena.create(vxfw.Center);
        centered.* = .{ .child = text.widget() };

        const inner = try centered.widget().draw(ctx);
        return .{
            .size = inner.size,
            .widget = self.widget(),
            .cursor = inner.cursor,
            .buffer = inner.buffer,
            .children = inner.children,
        };
    }
};
