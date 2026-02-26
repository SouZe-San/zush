const std = @import("std");
const vaxis = @import("vaxis");
const zush = @import("zush");
const header = @import("../widget/header.zig");
const vxfw = vaxis.vxfw;
// -- TYPEs
const Border = vxfw.Border;
const Button = vxfw.Button;
const Center = vxfw.Center;

const Cell = vaxis.Cell;
const TextInput = vaxis.widgets.TextInput;
const border = vaxis.widgets.border;

const drive_options = [_][]const u8{ "Network USB", "KeyBoard", "USB KingDom", "SanDisk (32 GB)" };
const boot_options = [_][]const u8{ "Zorin_OS_99.7_Ultimate_procode_LTS.iso", "Ubuntu_24.04_LTS.iso", "Windows_11_ISO.iso" };
const scheme_options = [_][]const u8{ "MBR", "GPT" };
const target_options = [_][]const u8{ "BIOS or UEFI", "UEFI (non CSM)" };
const all_options = [_][]const []const u8{ &drive_options, &boot_options, &scheme_options, &target_options };

pub const Model = struct {
    focused_row_index: usize = 0, // 0 = Devices, 1 = Boot Selection, 2 = Scheme, 3 = Target
    selected_indices: [4]usize = [_]usize{0} ** 4,
    volume_label_buf: [32]u8 = undefined,
    volume_label_len: usize = 0,
    is_started: bool = false,
    start_btn: vxfw.Button = .{
        .label = "S T A R T",
        .onClick = onClick,
    },
    const MAX_ROWS: usize = 6;

    // --- Helper Widget Interface ---
    pub fn widget(self: *Model) vxfw.Widget {
        return .{
            .userdata = self,
            .eventHandler = Model.typeErasedEventHandler,
            .drawFn = Model.typeErasedDrawFn,
        };
    }

    pub fn onClick(maybe_ptr: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
        _ = maybe_ptr orelse return;
        return ctx.consumeAndRedraw();
    }

    // --- Event Handling ---
    fn typeErasedEventHandler(ptr: *anyopaque, ctx: *vxfw.EventContext, event: vxfw.Event) anyerror!void {
        const self: *Model = @ptrCast(@alignCast(ptr));
        switch (event) {
            .init => return ctx.requestFocus(self.widget()),
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true }) or key.matches('q', .{})) {
                    ctx.quit = true;
                    return;
                }

                if (key.matches(vaxis.Key.tab, .{ .shift = true })) {
                    // Shift+Tab: Move UP, wrap to the bottom if at the top
                    if (self.focused_row_index == 0) {
                        self.focused_row_index = MAX_ROWS - 1;
                    } else {
                        self.focused_row_index -= 1;
                    }
                    ctx.consumeAndRedraw();
                    return;
                } else if (key.matches(vaxis.Key.tab, .{})) {
                    // Tab: Move DOWN, wrap to the top if at the bottom
                    self.focused_row_index = (self.focused_row_index + 1) % MAX_ROWS;
                    ctx.consumeAndRedraw();
                    return;
                }

                // Move highlight UP
                if (key.matches(vaxis.Key.up, .{})) {
                    if (self.focused_row_index > 0) self.focused_row_index -= 1;
                    ctx.consumeAndRedraw();
                    return;
                }

                // Move highlight DOWN
                if (key.matches(vaxis.Key.down, .{})) {
                    if (self.focused_row_index < MAX_ROWS - 1) self.focused_row_index += 1;
                    ctx.consumeAndRedraw();
                    return;
                }

                if (key.matches(vaxis.Key.enter, .{})) {
                    if (self.focused_row_index == 5) { // Only works if Start is highlighted
                        self.is_started = !self.is_started;
                        ctx.consumeAndRedraw();
                    }
                    return;
                }

                if (self.focused_row_index == 4) {
                    if (key.matches(vaxis.Key.backspace, .{})) {
                        // Delete last character
                        if (self.volume_label_len > 0) self.volume_label_len -= 1;
                        ctx.consumeAndRedraw();
                        return;
                    }

                    // If a printable character was typed, add it to our buffer
                    if (key.text) |text| {
                        if (self.volume_label_len + text.len <= self.volume_label_buf.len) {
                            @memcpy(self.volume_label_buf[self.volume_label_len .. self.volume_label_len + text.len], text);
                            self.volume_label_len += text.len;
                            ctx.consumeAndRedraw();
                        }
                        return;
                    }
                }

                // Select NEXT option (Right)
                if (key.matches(vaxis.Key.right, .{})) {
                    if (self.focused_row_index == 4 or self.focused_row_index == 5) return;
                    const index = self.focused_row_index;
                    self.selected_indices[index] = (self.selected_indices[index] + 1) % all_options[index].len;
                    ctx.consumeAndRedraw();
                    return;
                }

                // Select PREVIOUS option (Left)
                if (key.matches(vaxis.Key.left, .{})) {
                    if (self.focused_row_index == 4 or self.focused_row_index == 5) return;
                    const index = self.focused_row_index;
                    if (self.selected_indices[index] > 0) {
                        self.selected_indices[index] -= 1;
                    } else {
                        self.selected_indices[index] = all_options[index].len - 1;
                    }
                    ctx.consumeAndRedraw();
                    return;
                }
            },
            .focus_in => return ctx.requestFocus(self.widget()),
            else => {},
        }
    }

    // --- 3. Drawing ---
    fn typeErasedDrawFn(ptr: *anyopaque, ctx: vxfw.DrawContext) std.mem.Allocator.Error!vxfw.Surface {
        const self: *Model = @ptrCast(@alignCast(ptr));
        const max_size = ctx.max.size();
        const arena = ctx.arena;

        // Initialize using the new unmanaged .empty syntax
        var subsurfaces: std.ArrayList(vxfw.SubSurface) = .empty;
        var current_row: u16 = 0;

        // Define Styles
        const row_active: vaxis.Style = .{ .bg = .{ .rgb = .{ 220, 220, 220 } }, .fg = .{ .rgb = .{ 0, 0, 0 } }, .bold = true };
        const row_inactive: vaxis.Style = .{ .bg = .default, .fg = .default };

        // --- Draw Top UI ---
        const tabList = try header.create_headerEndingWithUnicode(arena, max_size.width, "--[ Flasher ]-- ISO Info ", "-");

        try subsurfaces.append(arena, .{ .origin = .{ .row = current_row, .col = 0 }, .surface = try tabList.draw(ctx) });
        current_row += 2;

        const drive_header = try header.create_headerStartingWithUnicode(arena, max_size.width, "Drive Properties::", ":");

        try subsurfaces.append(arena, .{ .origin = .{ .row = current_row, .col = 0 }, .surface = try drive_header.draw(ctx) });
        current_row += 2;

        const RowData = struct { label: []const u8, opt: []const u8 };
        const rows = [_]RowData{
            .{ .label = "Devices", .opt = drive_options[self.selected_indices[0]] },
            .{ .label = "Boot Selection", .opt = boot_options[self.selected_indices[1]] },
            .{ .label = "Scheme", .opt = scheme_options[self.selected_indices[2]] },
            .{ .label = "Target", .opt = target_options[self.selected_indices[3]] },
        };

        for (rows, 0..) |rd, i| {
            const is_focused = (self.focused_row_index == i);
            const current_style = if (is_focused) row_active else row_inactive;

            var arrow_style = current_style;
            var text_style = current_style;

            if (is_focused) {
                // arrow_style.fg = .{ .rgb = .{ 61, 105, 195 } }; // A nice cyan/mint color
                arrow_style.bold = true;
                text_style.bold = true;
            } else {
                text_style.fg = .{ .rgb = .{ 225, 225, 193 } };
            }

            //  The Left Label
            const lbl_w: vxfw.Text = .{ .text = rd.label };

            const left_arrow: vxfw.Text = .{ .text = if (is_focused) " <<" else "   ", .style = arrow_style };
            const right_arrow: vxfw.Text = .{ .text = if (is_focused) ">>  " else "   ", .style = arrow_style, .text_align = .right };

            const opt_text: vxfw.Text = .{ .text = rd.opt, .style = text_style, .text_align = .center };

            const tight_row: vxfw.FlexRow = .{ .children = &.{
                .{ .widget = left_arrow.widget() },
                .{ .widget = opt_text.widget() },
                .{ .widget = right_arrow.widget() },
            } };

            const centered_group: vxfw.Center = .{ .child = tight_row.widget() };

            const fr: vxfw.FlexRow = .{
                .children = &.{
                    .{ .widget = lbl_w.widget(), .flex = 1 },
                    .{ .widget = centered_group.widget(), .flex = 2 },
                },
            };

            var row_ctx = ctx;
            row_ctx.max.height = 1;
            row_ctx.min.height = 1;
            if (ctx.max.width) |w| {
                row_ctx.max.width = w -| 3;
            }
            if (@typeInfo(@TypeOf(ctx.min.width)) == .optional) {
                if (ctx.min.width) |min_w| row_ctx.min.width = min_w -| 3;
            } else {
                row_ctx.min.width = ctx.min.width -| 3;
            }
            try subsurfaces.append(arena, .{ .origin = .{ .row = current_row, .col = 3 }, .surface = try fr.draw(row_ctx) });

            current_row += 2;
        }
        current_row += 1;
        const format_header = try header.create_headerStartingWithUnicode(arena, max_size.width, "Format Options::", ":");

        try subsurfaces.append(arena, .{ .origin = .{ .row = current_row, .col = 0 }, .surface = try format_header.draw(ctx) });
        current_row += 2;

        // --- NEW: Draw Volume Label Text Input (Row 4) ---
        const is_vol_focused = (self.focused_row_index == 4);

        // Grab the string slice currently typed by the user
        const current_vol_text = self.volume_label_buf[0..self.volume_label_len];

        const vol_opt_str = if (is_vol_focused)
            try std.fmt.allocPrint(arena, "  [ {s}█ ]  ", .{current_vol_text})
        else
            try std.fmt.allocPrint(arena, "[   {s}    ]", .{current_vol_text});

        const vol_lbl_w: vxfw.Text = .{ .text = "Volume Label" };
        const vol_opt_w: vxfw.Text = .{ .text = vol_opt_str, .style = if (is_vol_focused) row_active else row_inactive, .text_align = .center };
        const vol_fr: vxfw.FlexRow = .{ .children = &.{
            .{ .widget = vol_lbl_w.widget(), .flex = 1 },
            .{ .widget = vol_opt_w.widget(), .flex = 2 },
        } };
        try subsurfaces.append(arena, .{ .origin = .{ .row = current_row, .col = 4 }, .surface = try vol_fr.draw(ctx) });

        current_row += 4;

        // --- Draw Start Button ---

        const btn_ready: vaxis.Style = .{ .fg = .{ .rgb = .{ 255, 255, 255 } } };
        const btn_active: vaxis.Style = .{ .bg = .{ .rgb = .{ 50, 200, 50 } }, .fg = .{ .rgb = .{ 0, 0, 0 } } };

        const is_start_focused = (self.focused_row_index == 5);

        const current_btn_style = if (self.is_started)
            btn_active
        else if (is_start_focused)
            row_active
        else
            btn_ready;
        self.start_btn.style.default = current_btn_style;

        const start_button_border: Border = .{
            .child = self.start_btn.widget(),
        };

        try subsurfaces.append(arena, .{
            .origin = .{ .row = current_row, .col = 0 },
            .surface = try start_button_border.draw(ctx.withConstraints(
                ctx.min,
                .{ .width = max_size.width - 10, .height = 3 },
            )),
        });

        return .{
            .size = max_size,
            .widget = self.widget(),
            .buffer = &.{},
            .children = try subsurfaces.toOwnedSlice(arena),
        };
    }
};

// pub fn onClick(maybe_ptr: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
//     _ = maybe_ptr orelse return;
//     return ctx.consumeAndRedraw();
// }
