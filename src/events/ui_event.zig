const std = @import("std");

const jsruntime = @import("jsruntime");
const Case = jsruntime.test_utils.Case;
const checkCases = jsruntime.test_utils.checkCases;

const parser = @import("../netsurf.zig");

const Event = @import("event.zig").Event;
const Window = @import("../html/window.zig").Window;

pub const UIEvent = struct {
    pub const Self = parser.UIEvent;
    pub const mem_guarantied = true;

    pub const UIEventInit = parser.UIEventInit;

    // JS
    // --

    pub fn constructor(typ: []const u8, opts: ?UIEventInit) !*parser.UIEvent {
        const evt = try parser.uiEventCreate();
        try parser.uiEventInit(evt, typ, opts orelse UIEventInit{});
        return evt;
    }

    pub fn get_detail(self: *parser.UIEvent) !i32 {
        return try parser.uiEventDetail(self);
    }

    pub fn get_view(self: *parser.UIEvent) !?Window {
        return try parser.uiEventView(self);
    }
};

pub fn testExecFn(
    _: std.mem.Allocator,
    js_env: *jsruntime.Env,
) anyerror!void {
    var ui_event = [_]Case{
        .{ .src = "let content = document.getElementById('content')", .ex = "undefined" },
        .{ .src = "var evt", .ex = "undefined" },
        .{ .src = "content.addEventListener('evt', function(e) {evt = e})", .ex = "undefined" },
        .{ .src = "content.dispatchEvent(new UIEvent('evt'))", .ex = "true" },
        .{ .src = "evt instanceof UIEvent", .ex = "true" },
        .{ .src = "evt.__proto__.constructor.name", .ex = "UIEvent" },
        .{ .src = "evt.detail", .ex = "0" },
        .{ .src = "evt.view", .ex = "null" },
    };
    try checkCases(js_env, &ui_event);
}
