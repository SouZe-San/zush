const std = @import("std");
const vaxis = @import("vaxis");

const vxfw = vaxis.vxfw;

const Allocator = std.mem.Allocator;
const TextSpan = vaxis.Segment;
const Center = vxfw.Center;
const RichText = vxfw.RichText;

const RichButton = @This();

// User supplied values
label: []const TextSpan,
onClick: *const fn (?*anyopaque, ctx: *vxfw.EventContext) anyerror!void,
userdata: ?*anyopaque = null,

// Styles
style: struct {
    default: vaxis.Style = .{ .bg = .{ .rgb = .{ 40, 40, 40 } } },
    mouse_down: vaxis.Style = .{ .bg = .{ .rgb = .{ 40, 40, 40 } } },
    hover: vaxis.Style = .{ .bg = .{ .rgb = .{ 40, 40, 40 } } },
    focus: vaxis.Style = .{ .bg = .{ .rgb = .{ 40, 40, 40 } } },
} = .{},

// State
mouse_down: bool = false,
has_mouse: bool = false,
focused: bool = false,

pub fn widget(self: *RichButton) vxfw.Widget {
    return .{
        .userdata = self,
        .eventHandler = typeErasedEventHandler,
        .drawFn = typeErasedDrawFn,
    };
}

fn typeErasedEventHandler(ptr: *anyopaque, ctx: *vxfw.EventContext, event: vxfw.Event) anyerror!void {
    const self: *RichButton = @ptrCast(@alignCast(ptr));
    return self.handleEvent(ctx, event);
}

pub fn handleEvent(self: *RichButton, ctx: *vxfw.EventContext, event: vxfw.Event) anyerror!void {
    switch (event) {
        .key_press => |key| {
            if (key.matches(vaxis.Key.enter, .{}) or key.matches('j', .{ .ctrl = true })) {
                return self.doClick(ctx);
            }
        },
        .mouse => |mouse| {
            if (self.mouse_down and mouse.type == .release) {
                self.mouse_down = false;
                return self.doClick(ctx);
            }
            if (mouse.type == .press and mouse.button == .left) {
                self.mouse_down = true;
                return ctx.consumeAndRedraw();
            }
            return ctx.consumeEvent();
        },
        .mouse_enter => {
            // implicit redraw
            self.has_mouse = true;
            try ctx.setMouseShape(.pointer);
            return ctx.consumeAndRedraw();
        },
        .mouse_leave => {
            self.has_mouse = false;
            self.mouse_down = false;
            // implicit redraw
            try ctx.setMouseShape(.default);
        },
        .focus_in => {
            self.focused = true;
            ctx.redraw = true;
        },
        .focus_out => {
            self.focused = false;
            ctx.redraw = true;
        },
        else => {},
    }
}

fn typeErasedDrawFn(ptr: *anyopaque, ctx: vxfw.DrawContext) Allocator.Error!vxfw.Surface {
    const self: *RichButton = @ptrCast(@alignCast(ptr));
    return self.draw(ctx);
}

pub fn draw(self: *RichButton, ctx: vxfw.DrawContext) Allocator.Error!vxfw.Surface {
    const style: vaxis.Style = if (self.mouse_down)
        self.style.mouse_down
    else if (self.has_mouse)
        self.style.hover
    else if (self.focused)
        self.style.focus
    else
        self.style.default;

    const text: RichText = .{
        .text = self.label,
        .text_align = .center,
    };

    const center: Center = .{ .child = text.widget() };
    const surf = try center.draw(ctx);

    const button_surf = try vxfw.Surface.initWithChildren(ctx.arena, self.widget(), surf.size, surf.children);
    @memset(button_surf.buffer, .{ .style = style });
    return button_surf;
}

fn doClick(self: *RichButton, ctx: *vxfw.EventContext) anyerror!void {
    try self.onClick(self.userdata, ctx);
    ctx.consume_event = true;
}
