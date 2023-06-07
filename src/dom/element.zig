const std = @import("std");

const generate = @import("../generate.zig");

const parser = @import("../parser.zig");

const Node = @import("node.zig").Node;
const HTMLElem = @import("../html/elements.zig");

pub const Element = struct {
    pub const Self = parser.Element;
    pub const prototype = *Node;
    pub const mem_guarantied = true;

    // JS funcs
    // --------

    pub fn get_localName(self: *parser.Element) []const u8 {
        return parser.elementLocalName(self);
    }
};

pub const Types = generate.Tuple(.{HTMLElem.Types});
const Generated = generate.Union.compile(Types);
pub const Union = Generated._union;
pub const Tags = Generated._enum;
