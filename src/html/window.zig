// Copyright (C) 2023-2024  Lightpanda (Selecy SAS)
//
// Francis Bouvier <francis@lightpanda.io>
// Pierre Tachoire <pierre@lightpanda.io>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");

const parser = @import("../netsurf.zig");
const jsruntime = @import("jsruntime");
const Callback = jsruntime.Callback;
const CallbackArg = jsruntime.CallbackArg;
const Loop = jsruntime.Loop;

const EventTarget = @import("../dom/event_target.zig").EventTarget;

const storage = @import("../storage/storage.zig");

// https://dom.spec.whatwg.org/#interface-window-extensions
// https://html.spec.whatwg.org/multipage/nav-history-apis.html#window
pub const Window = struct {
    pub const prototype = *EventTarget;
    pub const mem_guarantied = true;
    pub const global_type = true;

    // Extend libdom event target for pure zig struct.
    base: parser.EventTargetTBase = parser.EventTargetTBase{},

    document: ?*parser.DocumentHTML = null,
    target: []const u8,

    storageShelf: ?*storage.Shelf = null,

    pub fn create(target: ?[]const u8) Window {
        return Window{
            .target = target orelse "",
        };
    }

    pub fn replaceDocument(self: *Window, doc: *parser.DocumentHTML) void {
        self.document = doc;
    }

    pub fn setStorageShelf(self: *Window, shelf: *storage.Shelf) void {
        self.storageShelf = shelf;
    }

    pub fn get_window(self: *Window) *Window {
        return self;
    }

    pub fn get_self(self: *Window) *Window {
        return self;
    }

    pub fn get_parent(self: *Window) *Window {
        return self;
    }

    pub fn get_document(self: *Window) ?*parser.DocumentHTML {
        return self.document;
    }

    pub fn get_name(self: *Window) []const u8 {
        return self.target;
    }

    pub fn get_localStorage(self: *Window) !*storage.Bottle {
        if (self.storageShelf == null) return parser.DOMError.NotSupported;
        return &self.storageShelf.?.bucket.local;
    }

    pub fn get_sessionStorage(self: *Window) !*storage.Bottle {
        if (self.storageShelf == null) return parser.DOMError.NotSupported;
        return &self.storageShelf.?.bucket.session;
    }

    // TODO handle callback arguments.
    pub fn _setTimeout(_: *Window, loop: *Loop, cbk: Callback, delay: ?u32) !u32 {
        const ddelay: u63 = delay orelse 0;
        loop.timeout(ddelay * std.time.ns_per_ms, cbk);
        // TODO handle timeout ID
        return 1;
    }

    pub fn _clearTimeout(_: *Window, _: *Loop, id: u32) !void {
        _ = id;
    }
};
