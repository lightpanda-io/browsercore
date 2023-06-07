const std = @import("std");

const jsruntime = @import("jsruntime");
const Case = jsruntime.test_utils.Case;
const checkCases = jsruntime.test_utils.checkCases;
const generate = @import("../generate.zig");

const parser = @import("../parser.zig");

const EventTarget = @import("event_target.zig").EventTarget;
const Element = @import("element.zig").Element;
const E = @import("../html/elements.zig");

pub fn create_tree(node: ?*parser.Node, _: ?*anyopaque) callconv(.C) parser.Action {
    if (node == null) {
        return parser.ActionStop;
    }
    const node_type = parser.nodeType(node.?);
    const node_name = parser.nodeName(node.?);
    std.debug.print("type: {any}, name: {s}\n", .{ node_type, node_name });
    if (node_type == parser.NodeType.element) {
        std.debug.print("yes\n", .{});
    }
    return parser.ActionOk;
}

pub const Node = struct {
    pub const Self = parser.Node;
    pub const prototype = *EventTarget;
    pub const mem_guarantied = true;

    pub fn make_tree(self: *parser.Node) !void {
        try parser.nodeWalk(self, create_tree);
    }

    pub fn toInterface(node: *parser.Node) Nodes {
        return switch (parser.nodeType(node)) {
            .element => E.toInterface(Nodes, @ptrCast(*parser.Element, node)),
            else => @panic("unknown element"),
        };
    }

    // JS funcs
    // --------

    pub fn get_firstChild(self: *parser.Node) ?Nodes {
        if (self.first_child == null) {
            return null;
        }
        return Node.toInterface(self.first_child);
    }

    pub fn get_lastChild(self: *parser.Node) ?Nodes {
        if (self.last_child == null) {
            return null;
        }
        return Node.toInterface(self.last_child);
    }
};

pub const NodesTypes = generate.Tuple(.{E.HTMLElementsTypes});
const NodesGenerated = generate.Union.compile(NodesTypes);
pub const Nodes = NodesGenerated._union;
pub const NodesTags = NodesGenerated._enum;

// Tests
// -----

pub fn testExecFn(
    _: std.mem.Allocator,
    js_env: *jsruntime.Env,
    comptime _: []jsruntime.API,
) !void {
    var first_child = [_]Case{
        .{ .src = "let first_child = document.body.firstChild", .ex = "undefined" },
        .{ .src = "first_child.localName", .ex = "div" },
        .{ .src = "first_child.__proto__.constructor.name", .ex = "HTMLDivElement" },
        .{ .src = "document.getElementById('last').firstChild", .ex = "null" },
    };
    try checkCases(js_env, &first_child);

    var last_child = [_]Case{
        .{ .src = "let last_child = document.getElementById('content').lastChild", .ex = "undefined" },
        .{ .src = "last_child.localName", .ex = "p" },
        .{ .src = "last_child.__proto__.constructor.name", .ex = "HTMLParagraphElement" },
    };
    try checkCases(js_env, &last_child);
}
