const std = @import("std");

const server = @import("../server.zig");
const Ctx = server.Cmd;
const result = @import("cdp.zig").result;
const getParams = @import("cdp.zig").getParams;

const BrowserMethods = enum {
    getVersion,
    setDownloadBehavior,
};

pub fn browser(
    alloc: std.mem.Allocator,
    id: u64,
    action: []const u8,
    scanner: *std.json.Scanner,
    ctx: *Ctx,
) ![]const u8 {
    const method = std.meta.stringToEnum(BrowserMethods, action) orelse
        return error.UnknownMethod;
    return switch (method) {
        .getVersion => browserGetVersion(alloc, id, scanner, ctx),
        .setDownloadBehavior => browserSetDownloadBehavior(alloc, id, scanner, ctx),
    };
}

const ProtocolVersion = "1.3";
const Product = "Chrome/124.0.6367.29";
const Revision = "@9e6ded5ac1ff5e38d930ae52bd9aec09bd1a68e4";
const UserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";
const JsVersion = "12.4.254.8";

fn browserGetVersion(
    alloc: std.mem.Allocator,
    id: u64,
    _: *std.json.Scanner,
    _: *Ctx,
) ![]const u8 {
    const Res = struct {
        protocolVersion: []const u8,
        product: []const u8,
        revision: []const u8,
        userAgent: []const u8,
        jsVersion: []const u8,
    };

    const res = Res{
        .protocolVersion = ProtocolVersion,
        .product = Product,
        .revision = Revision,
        .userAgent = UserAgent,
        .jsVersion = JsVersion,
    };
    return result(alloc, id, Res, res, null);
}

fn browserSetDownloadBehavior(
    alloc: std.mem.Allocator,
    id: u64,
    scanner: *std.json.Scanner,
    _: *Ctx,
) ![]const u8 {
    const Params = struct {
        behavior: []const u8,
        browserContextId: ?[]const u8 = null,
        downloadPath: ?[]const u8 = null,
        eventsEnabled: ?bool = null,
    };
    const params = try getParams(alloc, Params, scanner);
    std.log.debug("params {any}", .{params});
    return result(alloc, id, null, null, null);
}
