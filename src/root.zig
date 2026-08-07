pub const iw = @import("iw/root.zig");

pub const widgets = struct {
    pub const header = @import("widget/header.zig");
    pub const ProgressBar = @import("widget/progress_bar.zig");
    pub const RichButton = @import("widget/rich_button.zig");
    pub const TabBar = @import("widget/tab_bar.zig");
};

pub const views = struct {
    pub const Flasher = @import("views/flasher.zig");
    pub const Home = @import("views/home.zig");
};
