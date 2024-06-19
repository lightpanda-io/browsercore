const std = @import("std");

// pub const MaxStdOutSize = 512; // ensure debug msg are not too long

/// MsgBuffer return messages from a raw text read stream,
/// according to the following format `<msg_size>:<msg>`.
/// It handles both:
/// - combined messages in one read
/// - single message in several read (multipart)
/// It is safe (and good practice) to reuse the same MsgBuffer
/// on several reads of the same stream.
pub const MsgBuffer = struct {
    size: usize = 0,
    buf: []u8,
    pos: usize = 0,

    pub fn init(alloc: std.mem.Allocator, size: usize) std.mem.Allocator.Error!MsgBuffer {
        const buf = try alloc.alloc(u8, size);
        return .{ .buf = buf };
    }

    pub fn deinit(self: MsgBuffer, alloc: std.mem.Allocator) void {
        alloc.free(self.buf);
    }

    fn isFinished(self: *MsgBuffer) bool {
        return self.pos >= self.size;
    }

    fn isEmpty(self: MsgBuffer) bool {
        return self.size == 0 and self.pos == 0;
    }

    fn reset(self: *MsgBuffer) void {
        self.size = 0;
        self.pos = 0;
    }

    // read input
    // - `do_func` is a callback to execute on each message of the input
    // - `data` is a arbitrary payload that will be passed to the callback along with
    // the message itself
    pub fn read(
        self: *MsgBuffer,
        alloc: std.mem.Allocator,
        input: []const u8,
        data: anytype,
        comptime do_func: fn (data: @TypeOf(data), msg: []const u8) anyerror!void,
    ) !void {
        var _input = input; // make input writable

        while (true) {
            var msg: []const u8 = undefined;

            // msg size
            var msg_size: usize = undefined;
            if (self.isEmpty()) {
                // parse msg size metadata
                const size_pos = std.mem.indexOfScalar(u8, _input, ':').?;
                const size_str = _input[0..size_pos];
                msg_size = try std.fmt.parseInt(u32, size_str, 10);
                _input = _input[size_pos + 1 ..];
            } else {
                msg_size = self.size;
            }

            // multipart
            const is_multipart = !self.isEmpty() or _input.len < msg_size;
            if (is_multipart) {

                // set msg size on empty MsgBuffer
                if (self.isEmpty()) {
                    self.size = msg_size;
                }

                // get the new position of the cursor
                const new_pos = self.pos + _input.len;

                // check if the current input can fit in MsgBuffer
                if (new_pos > self.buf.len) {
                    // max_size is the max between msg size and current new cursor position
                    const max_size = @max(self.size, new_pos);
                    // resize the MsgBuffer to fit
                    self.buf = try alloc.realloc(self.buf, max_size);
                }

                // copy the current input into MsgBuffer
                @memcpy(self.buf[self.pos..new_pos], _input[0..]);

                // set the new cursor position
                self.pos = new_pos;

                // if multipart is not finished, go fetch the next input
                if (!self.isFinished()) return;

                // otherwhise multipart is finished, use its buffer as input
                _input = self.buf[0..self.pos];
                self.reset();
            }

            // handle several JSON msg in 1 read
            const is_combined = _input.len > msg_size;
            msg = _input[0..msg_size];
            if (is_combined) {
                _input = _input[msg_size..];
            }

            try @call(.auto, do_func, .{ data, msg });

            if (!is_combined) break;
        }
    }
};

fn doTest(nb: *u8, _: []const u8) anyerror!void {
    nb.* += 1;
}

test "MsgBuffer" {
    const Case = struct {
        input: []const u8,
        nb: u8,
    };
    const alloc = std.testing.allocator;
    const cases = [_]Case{
        // simple
        .{ .input = "2:ok", .nb = 1 },
        // combined
        .{ .input = "2:ok3:foo7:bar2:ok", .nb = 3 }, // "bar2:ok" is a message, no need to escape "2:" here
        // multipart
        .{ .input = "9:multi", .nb = 0 },
        .{ .input = "part", .nb = 1 },
        // multipart & combined
        .{ .input = "9:multi", .nb = 0 },
        .{ .input = "part2:ok", .nb = 2 },
        // several multipart
        .{ .input = "23:multi", .nb = 0 },
        .{ .input = "several", .nb = 0 },
        .{ .input = "complex", .nb = 0 },
        .{ .input = "part", .nb = 1 },
        // combined & multipart
        .{ .input = "2:ok9:multi", .nb = 1 },
        .{ .input = "part", .nb = 1 },
    };
    var nb: u8 = undefined;
    var msg_buf = try MsgBuffer.init(alloc, 10);
    defer msg_buf.deinit(alloc);
    for (cases) |case| {
        nb = 0;
        try msg_buf.read(alloc, case.input, &nb, doTest);
        try std.testing.expect(nb == case.nb);
    }
}
