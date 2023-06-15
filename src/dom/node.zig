const std = @import("std");

const jsruntime = @import("jsruntime");
const Case = jsruntime.test_utils.Case;
const checkCases = jsruntime.test_utils.checkCases;
const generate = @import("../generate.zig");

const parser = @import("../parser.zig");

const EventTarget = @import("event_target.zig").EventTarget;
const CData = @import("character_data.zig");
const HTMLDocument = @import("../html/document.zig").HTMLDocument;
const HTMLElem = @import("../html/elements.zig");

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

    pub fn toInterface(node: *parser.Node) Union {
        return switch (parser.nodeType(node)) {
            .element => HTMLElem.toInterface(Union, @ptrCast(*parser.Element, node)),
            .comment => .{ .Comment = @ptrCast(*parser.Comment, node) },
            .text => .{ .Text = @ptrCast(*parser.Text, node) },
            .document => .{ .HTMLDocument = @ptrCast(*parser.DocumentHTML, node) },
            else => @panic("node type not handled"),
        };
    }

    // JS funcs
    // --------

    // Read-only attributes

    // pub fn get_baseURI(_: *parser.Node) void {
    //     // TODO
    // }

    // pub fn get_childNodes(_: *parser.Node) void {
    //     // TODO
    // }

    pub fn get_firstChild(self: *parser.Node) ?Union {
        if (self.first_child == null) {
            return null;
        }
        return Node.toInterface(self.first_child);
    }

    pub fn get_lastChild(self: *parser.Node) ?Union {
        if (self.last_child == null) {
            return null;
        }
        return Node.toInterface(self.last_child);
    }

    pub fn get_nextSibling(self: *parser.Node) ?Union {
        if (self.next == null) {
            return null;
        }
        return Node.toInterface(self.next);
    }

    pub fn get_previousSibling(self: *parser.Node) ?Union {
        if (self.prev == null) {
            return null;
        }
        return Node.toInterface(self.prev);
    }

    pub fn get_parentNode(self: *parser.Node) ?Union {
        if (self.parent == null) {
            return null;
        }
        return Node.toInterface(self.parent);
    }

    pub fn get_parentElement(self: *parser.Node) ?HTMLElem.Union {
        if (self.parent == null) {
            return null;
        }
        if (parser.nodeType(self.parent) != .element) {
            return null;
        }
        return HTMLElem.toInterface(HTMLElem.Union, @ptrCast(*parser.Element, self.parent));
    }

    pub fn get_nodeName(self: *parser.Node) []const u8 {
        return parser.nodeName(self);
    }

    pub fn get_nodeType(self: *parser.Node) u8 {
        return @enumToInt(parser.nodeType(self));
    }

    pub fn get_ownerDocument(self: *parser.Node) ?*parser.DocumentHTML {
        if (parser.nodeType(self) == .document) {
            return null;
        }
        return @ptrCast(*parser.DocumentHTML, self.owner_document);
    }

    pub fn get_isConnected(self: *parser.Node) bool {
        // TODO: handle Shadow DOM
        if (parser.nodeType(self) == .document) {
            return true;
        }
        return Node.get_parentNode(self) != null;
    }

    // Read/Write attributes

    pub fn get_nodeValue(self: *parser.Node) ?[]const u8 {
        return switch (parser.nodeType(self)) {
            // TODO: attribute
            .cdata_section, .comment, .text => parser.characterDataValue(self),
            else => null,
        };
    }

    pub fn set_nodeValue(self: *parser.Node, data: []u8) void {
        switch (parser.nodeType(self)) {
            // TODO: attribute
            .cdata_section, .comment, .text => parser.characterDataValueSet(self, data),
            else => {},
        }
    }

    // pub fn get_textContent(_: *parser.Node) void {
    //     // TODO
    // }

    // pub fn set_textContent(_: *parser.Node) void {
    //     // TODO
    // }
};

pub const Types = generate.Tuple(.{
    CData.Types,
    HTMLElem.Types,
    HTMLDocument,
});
const Generated = generate.Union.compile(Types);
pub const Union = Generated._union;
pub const Tags = Generated._enum;

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
        .{ .src = "document.getElementById('para').firstChild", .ex = "null" },
    };
    try checkCases(js_env, &first_child);

    var last_child = [_]Case{
        .{ .src = "let last_child = document.getElementById('content').lastChild", .ex = "undefined" },
        .{ .src = "last_child.__proto__.constructor.name", .ex = "Comment" },
    };
    try checkCases(js_env, &last_child);

    var next_sibling = [_]Case{
        .{ .src = "let next_sibling = document.getElementById('link').nextSibling", .ex = "undefined" },
        .{ .src = "next_sibling.localName", .ex = "p" },
        .{ .src = "next_sibling.__proto__.constructor.name", .ex = "HTMLParagraphElement" },
        .{ .src = "document.getElementById('content').nextSibling", .ex = "null" },
    };
    try checkCases(js_env, &next_sibling);

    var prev_sibling = [_]Case{
        .{ .src = "let prev_sibling = document.getElementById('para').previousSibling", .ex = "undefined" },
        .{ .src = "prev_sibling.localName", .ex = "a" },
        .{ .src = "prev_sibling.__proto__.constructor.name", .ex = "HTMLAnchorElement" },
        .{ .src = "document.getElementById('content').previousSibling", .ex = "null" },
    };
    try checkCases(js_env, &prev_sibling);

    var parent = [_]Case{
        .{ .src = "let parent = document.getElementById('para').parentElement", .ex = "undefined" },
        .{ .src = "parent.localName", .ex = "div" },
        .{ .src = "parent.__proto__.constructor.name", .ex = "HTMLDivElement" },
        .{ .src = "let h = document.getElementById('content').parentElement.parentElement", .ex = "undefined" },
        .{ .src = "h.parentElement", .ex = "null" },
        .{ .src = "h.parentNode.__proto__.constructor.name", .ex = "HTMLDocument" },
    };
    try checkCases(js_env, &parent);

    var node_name = [_]Case{
        .{ .src = "document.getElementById('content').firstChild.nodeName === 'A'", .ex = "true" },
        .{ .src = "document.getElementById('link').firstChild.nodeName === '#text'", .ex = "true" },
        .{ .src = "document.getElementById('content').lastChild.nodeName === '#comment'", .ex = "true" },
        .{ .src = "document.nodeName === '#document'", .ex = "true" },
    };
    try checkCases(js_env, &node_name);

    var node_type = [_]Case{
        .{ .src = "document.getElementById('content').firstChild.nodeType === 1", .ex = "true" },
        .{ .src = "document.getElementById('link').firstChild.nodeType === 3", .ex = "true" },
        .{ .src = "document.getElementById('content').lastChild.nodeType === 8", .ex = "true" },
        .{ .src = "document.nodeType === 9", .ex = "true" },
    };
    try checkCases(js_env, &node_type);

    var owner = [_]Case{
        .{ .src = "let owner = document.getElementById('content').ownerDocument", .ex = "undefined" },
        .{ .src = "owner.__proto__.constructor.name", .ex = "HTMLDocument" },
        .{ .src = "document.ownerDocument", .ex = "null" },
        .{ .src = "let owner2 = document.createElement('div').ownerDocument", .ex = "undefined" },
        .{ .src = "owner2.__proto__.constructor.name", .ex = "HTMLDocument" },
    };
    try checkCases(js_env, &owner);

    var connected = [_]Case{
        .{ .src = "document.getElementById('content').isConnected", .ex = "true" },
        .{ .src = "document.isConnected", .ex = "true" },
        .{ .src = "document.createElement('div').isConnected", .ex = "false" },
    };
    try checkCases(js_env, &connected);

    var node_value = [_]Case{
        .{ .src = "document.getElementById('content').lastChild.nodeValue === 'comment'", .ex = "true" },
        .{ .src = "document.getElementById('link').nodeValue === null", .ex = "true" },
        .{ .src = "let text = document.getElementById('link').firstChild", .ex = "undefined" },
        .{ .src = "text.nodeValue === 'OK'", .ex = "true" },
        .{ .src = "text.nodeValue = 'OK modified'", .ex = "OK modified" },
        .{ .src = "text.nodeValue === 'OK modified'", .ex = "true" },
        .{ .src = "document.getElementById('link').nodeValue = 'nothing'", .ex = "nothing" },
    };
    try checkCases(js_env, &node_value);
}
