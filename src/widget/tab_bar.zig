const std = @import("std");
const vaxis = @import("vaxis");
const RichButton = @import("./rich_button.zig");
const vxfw = vaxis.vxfw;
const Border = vxfw.Border;
const Padding = vxfw.Padding;

const TabBar = @This();

btn_flasher: RichButton,
btn_iso: RichButton,

pub fn widget(self: *const TabBar) vxfw.Widget {
    return .{
        .userdata = @constCast(self),
        .eventHandler = null,
        .drawFn = drawFn,
    };
}

/// 3. Draw Function: Perform the layout and rendering
fn drawFn(ptr: *anyopaque, ctx: vxfw.DrawContext) std.mem.Allocator.Error!vxfw.Surface {
    const self: *TabBar = @ptrCast(@alignCast(ptr));
    const max_size = ctx.max.size();
    const child_max: vxfw.MaxSize = .{ .width = 15, .height = 1 };
    const two_dashed: vxfw.Text = .{
        .text = "--",
        .style = .{
            .bg = .{ .rgb = .{ 40, 40, 40 } },
        },
    };

    const flasher_btn_with_border: Border = .{
        .child = self.btn_flasher.widget(),
        .style = .{
            .bg = .{ .rgb = .{ 40, 40, 40 } },
        },
    };
    const iso_info_btn_with_border: Border = .{
        .child = self.btn_iso.widget(),
        .style = .{
            .bg = .{ .rgb = .{ 40, 40, 40 } },
        },
    };

    const flasher_surf = try flasher_btn_with_border.draw(ctx.withConstraints(
        ctx.min,
        child_max,
    ));

    const iso_surf = try iso_info_btn_with_border.draw(ctx.withConstraints(
        ctx.min,
        child_max,
    ));

    const used_width = flasher_surf.size.width + iso_surf.size.width;
    const dashes_needed = if (max_size.width > used_width) max_size.width - used_width else 0;

    const dash = "-";
    const dashes_bytes = dashes_needed * dash.len;

    var dashes_buf = try ctx.arena.alloc(u8, dashes_bytes);
    var offset: usize = 0;
    for (0..dashes_needed) |_| {
        @memcpy(dashes_buf[offset .. offset + dash.len], dash);
        offset += dash.len;
    }

    const dashes_text: vxfw.Text = .{ .text = dashes_buf, .style = .{ .bold = true, .bg = .{ .rgb = .{ 40, 40, 40 } } } };
    const dashed_text_Vpadding: vxfw.Padding = .{
        .child = dashes_text.widget(),
        .padding = Padding.vertical(1),
    };
    const two_dashed_text_Vpadding: vxfw.Padding = .{
        .child = two_dashed.widget(),
        .padding = Padding.vertical(1),
    };

    const flex_row: vxfw.FlexRow = .{ .children = &.{
        .{ .widget = two_dashed_text_Vpadding.widget(), .flex = 0 },
        .{ .widget = flasher_btn_with_border.widget() },
        .{ .widget = two_dashed_text_Vpadding.widget(), .flex = 0 },
        .{ .widget = iso_info_btn_with_border.widget() },
        .{ .widget = dashed_text_Vpadding.widget(), .flex = 0 },
    } };
    return try flex_row.widget().draw(ctx.withConstraints(ctx.min, .{ .width = ctx.max.width, .height = 3 }));
}
