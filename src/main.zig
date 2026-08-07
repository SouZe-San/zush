const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const zush = @import("zush");
const flasher = zush.views.Flasher;
const home = zush.views.Home;
const TabBar = zush.widgets.TabBar;
// const iw = @import("iw/root.zig");
// iw.d_verbose = false,

const Tab = enum(u1) { flasher, iso_info };

//  active/inactive colors for TAB button
const tab_active_color: vaxis.Color = .{ .rgb = .{ 220, 40, 40 } }; // red
const tab_inactive_color: vaxis.Color = .{ .rgb = .{ 45, 198, 22 } }; // green

// app state
const Model = struct {
    activeTab: Tab = .flasher,
    flasher_model: flasher.Model = .{},
    home_model: home.Model = .{},

    flasher_label: [2]vaxis.Segment = .{
        .{
            .text = "F",
            .style = .{
                .fg = tab_active_color, // .flasher is the default active tab
                .bg = .{ .rgb = .{ 40, 40, 40 } },
            },
        },
        .{ .text = "lasher", .style = .{
            .fg = .{ .rgb = .{ 255, 255, 255 } },
            .bg = .{ .rgb = .{ 40, 40, 40 } },
        } },
    },
    iso_label: [2]vaxis.Segment = .{
        .{ .text = "I", .style = .{
            .fg = tab_inactive_color,
            .bg = .{ .rgb = .{ 40, 40, 40 } },
        } },
        .{ .text = "SO Info", .style = .{
            .fg = .{ .rgb = .{ 255, 255, 255 } },
            .bg = .{ .rgb = .{ 40, 40, 40 } },
        } },
    },

    tab_bar: TabBar = .{
        .btn_flasher = .{
            .label = undefined, // latter defined
            .onClick = Model.onClickFlasher,
        },
        .btn_iso = .{
            .label = undefined, //  &iso_label in main()
            .onClick = Model.onClickIsoInfo,
        },
    },

    // helper widget
    pub fn widget(self: *Model) vxfw.Widget {
        return .{
            .userdata = self,
            .eventHandler = Model.typeErasedEventHandler,
            .drawFn = Model.typeErasedDrawFn,
        };
    }

    // update tab color on active and inctive
    fn syncTabColors(self: *Model) void {
        self.flasher_label[0].style.fg = if (self.activeTab == .flasher)
            tab_active_color
        else
            tab_inactive_color;

        self.iso_label[0].style.fg = if (self.activeTab == .iso_info)
            tab_active_color
        else
            tab_inactive_color;
    }

    pub fn onClickIsoInfo(maybe_ptr: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
        const ptr = maybe_ptr orelse return;
        const self: *Model = @ptrCast(@alignCast(ptr));
        self.activeTab = .iso_info;
        self.syncTabColors();
        try ctx.requestFocus(self.home_model.widget());
        return ctx.consumeAndRedraw();
    }

    pub fn onClickFlasher(maybe_ptr: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
        const ptr = maybe_ptr orelse return;
        const self: *Model = @ptrCast(@alignCast(ptr));
        self.activeTab = .flasher;
        self.syncTabColors();
        try ctx.requestFocus(self.flasher_model.widget());
        return ctx.consumeAndRedraw();
    }
    fn typeErasedEventHandler(ptr: *anyopaque, ctx: *vxfw.EventContext, event: vxfw.Event) anyerror!void {
        // const flasher_w: flasher.Model = .{};
        const self: *Model = @ptrCast(@alignCast(ptr));
        switch (event) {
            // The root widget is always sent an init event as the first event. Users of the
            // library can also send this event to other widgets they create if they need to do
            // some initialization.
            .init => return ctx.requestFocus(self.flasher_model.widget()),
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true }) or key.matches('q', .{})) {
                    ctx.quit = true;
                    return;
                }
            },
            .focus_in => return ctx.requestFocus(switch (self.activeTab) {
                .flasher => self.flasher_model.widget(),
                .iso_info => self.home_model.widget(),
            }),
            else => {},
        }
    }

    fn typeErasedDrawFn(ptr: *anyopaque, ctx: vxfw.DrawContext) std.mem.Allocator.Error!vxfw.Surface {
        const self: *Model = @ptrCast(@alignCast(ptr));

        const current_tab: vxfw.Widget = switch (self.activeTab) {
            .flasher => self.flasher_model.widget(),
            .iso_info => self.home_model.widget(),
        };
        const tab_bar_surface: vxfw.SubSurface = .{
            .origin = .{ .row = 0, .col = 0 },
            .surface = try self.tab_bar.widget().draw(ctx),
        };
        const body_surface: vxfw.SubSurface = .{
            .origin = .{ .row = 3, .col = 0 },
            .surface = try current_tab.draw(ctx),
        };

        const children = try ctx.arena.alloc(vxfw.SubSurface, 2);
        children[0] = tab_bar_surface;
        children[1] = body_surface;

        const size = ctx.max.size();
        const total_cells: usize = @as(usize, size.width) * size.height;
        const bg_buffer = try ctx.arena.alloc(vaxis.Cell, total_cells);
        const custom_bg = vaxis.Color{ .rgb = .{ 40, 40, 40 } };

        @memset(bg_buffer, vaxis.Cell{ .style = .{ .bg = custom_bg } });

        return .{
            .size = size,
            .widget = self.widget(),
            .buffer = bg_buffer,
            .children = children,
        };
    }
};

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try vxfw.App.init(allocator);
    defer app.deinit();

    // We heap allocate our model because we will require a stable pointer to it in our Button
    // widget
    const model = try allocator.create(Model);
    defer allocator.destroy(model);
    // defer _ = gpa.detectLeaks();

    // Set the initial state of our button
    model.* = .{};
    model.tab_bar.btn_flasher.userdata = model;
    model.tab_bar.btn_iso.userdata = model;
    model.tab_bar.btn_flasher.label = &model.flasher_label;
    model.tab_bar.btn_iso.label = &model.iso_label;

    try app.run(model.widget(), .{});
}
