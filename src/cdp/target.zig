const std = @import("std");

const server = @import("../server.zig");
const Ctx = server.Cmd;
const cdp = @import("cdp.zig");
const result = cdp.result;
const getMsg = cdp.getMsg;
const stringify = cdp.stringify;

const TargetMethods = enum {
    setDiscoverTargets,
    setAutoAttach,
    getTargetInfo,
    getBrowserContexts,
    createBrowserContext,
    createTarget,
};

pub fn target(
    alloc: std.mem.Allocator,
    id: ?u16,
    action: []const u8,
    scanner: *std.json.Scanner,
    ctx: *Ctx,
) ![]const u8 {
    const method = std.meta.stringToEnum(TargetMethods, action) orelse
        return error.UnknownMethod;
    return switch (method) {
        .setDiscoverTargets => targetSetDiscoverTargets(alloc, id, scanner, ctx),
        .setAutoAttach => tagetSetAutoAttach(alloc, id, scanner, ctx),
        .getTargetInfo => tagetGetTargetInfo(alloc, id, scanner, ctx),
        .getBrowserContexts => getBrowserContexts(alloc, id, scanner, ctx),
        .createBrowserContext => createBrowserContext(alloc, id, scanner, ctx),
        .createTarget => createTarget(alloc, id, scanner, ctx),
    };
}

const PageTargetID = "CFCD6EC01573CF29BB638E9DC0F52DDC";
const BrowserTargetID = "2d2bdef9-1c95-416f-8c0e-83f3ab73a30c";
const BrowserContextID = "65618675CB7D3585A95049E9DFE95EA9";

fn targetSetDiscoverTargets(
    alloc: std.mem.Allocator,
    id: ?u16,
    scanner: *std.json.Scanner,
    _: *Ctx,
) ![]const u8 {
    const msg = try getMsg(alloc, void, scanner);

    return result(alloc, id orelse msg.id.?, null, null, msg.sessionID);
}

const AttachToTarget = struct {
    sessionId: []const u8,
    targetInfo: struct {
        targetId: []const u8,
        type: []const u8 = "page",
        title: []const u8,
        url: []const u8,
        attached: bool = true,
        canAccessOpener: bool = false,
        browserContextId: []const u8,
    },
    waitingForDebugger: bool = false,
};

const TargetFilter = struct {
    type: ?[]const u8 = null,
    exclude: ?bool = null,
};

fn tagetSetAutoAttach(
    alloc: std.mem.Allocator,
    id: ?u16,
    scanner: *std.json.Scanner,
    ctx: *Ctx,
) ![]const u8 {
    const Params = struct {
        autoAttach: bool,
        waitForDebuggerOnStart: bool,
        flatten: bool = true,
        filter: ?[]TargetFilter = null,
    };
    const msg = try getMsg(alloc, Params, scanner);
    std.log.debug("params {any}", .{msg.params});

    if (msg.sessionID == null) {
        const attached = AttachToTarget{
            .sessionId = cdp.SessionID,
            .targetInfo = .{
                .targetId = PageTargetID,
                .title = "New Incognito tab",
                .url = cdp.URLBase,
                .browserContextId = BrowserContextID,
            },
        };
        try cdp.sendEvent(alloc, ctx, "Target.attachedToTarget", AttachToTarget, attached, null);
    }

    return result(alloc, id orelse msg.id.?, null, null, msg.sessionID);
}

fn tagetGetTargetInfo(
    alloc: std.mem.Allocator,
    id: ?u16,
    scanner: *std.json.Scanner,
    _: *Ctx,
) ![]const u8 {

    // input
    const Params = struct {
        targetId: ?[]const u8 = null,
    };
    const msg = try getMsg(alloc, Params, scanner);

    // output
    const TargetInfo = struct {
        targetId: []const u8,
        type: []const u8,
        title: []const u8 = "",
        url: []const u8 = "",
        attached: bool = true,
        openerId: ?[]const u8 = null,
        canAccessOpener: bool = false,
        openerFrameId: ?[]const u8 = null,
        browserContextId: ?[]const u8 = null,
        subtype: ?[]const u8 = null,
    };
    const targetInfo = TargetInfo{
        .targetId = BrowserTargetID,
        .type = "browser",
    };
    return result(alloc, id orelse msg.id.?, TargetInfo, targetInfo, null);
}

// Browser context are not handled and not in the roadmap for now
// The following methods are "fake"

fn getBrowserContexts(
    alloc: std.mem.Allocator,
    id: ?u16,
    scanner: *std.json.Scanner,
    ctx: *Ctx,
) ![]const u8 {
    const msg = try getMsg(alloc, void, scanner);

    // ouptut
    const Resp = struct {
        browserContextIds: [][]const u8,
    };
    var resp: Resp = undefined;
    if (ctx.state.contextID) |contextID| {
        var contextIDs = [1][]const u8{contextID};
        resp = .{ .browserContextIds = &contextIDs };
    } else {
        const contextIDs = [0][]const u8{};
        resp = .{ .browserContextIds = &contextIDs };
    }
    return result(alloc, id orelse msg.id.?, Resp, resp, null);
}

const ContextID = "22648B09EDCCDD11109E2D4FEFBE4F89";
const ContextSessionID = "4FDC2CB760A23A220497A05C95417CF4";

fn createBrowserContext(
    alloc: std.mem.Allocator,
    id: ?u16,
    scanner: *std.json.Scanner,
    ctx: *Ctx,
) ![]const u8 {

    // input
    const Params = struct {
        disposeOnDetach: bool = false,
        proxyServer: ?[]const u8 = null,
        proxyBypassList: ?[]const u8 = null,
        originsWithUniversalNetworkAccess: ?[][]const u8 = null,
    };
    const msg = try getMsg(alloc, Params, scanner);

    ctx.state.contextID = ContextID;

    // output
    const Resp = struct {
        browserContextId: []const u8 = ContextID,
    };
    return result(alloc, id orelse msg.id.?, Resp, Resp{}, msg.sessionID);
}

const TargetID = "57356548460A8F29706A2ADF14316298";

fn createTarget(
    alloc: std.mem.Allocator,
    id: ?u16,
    scanner: *std.json.Scanner,
    ctx: *Ctx,
) ![]const u8 {

    // input
    const Params = struct {
        url: []const u8,
        width: ?u64 = null,
        height: ?u64 = null,
        browserContextId: []const u8,
        enableBeginFrameControl: bool = false,
        newWindow: bool = false,
        background: bool = false,
        forTab: ?bool = null,
    };
    const msg = try getMsg(alloc, Params, scanner);

    // change CDP state
    ctx.state.frameID = TargetID;
    ctx.state.url = "about:blank";
    ctx.state.securityOrigin = "://";
    ctx.state.secureContextType = "InsecureScheme";
    ctx.state.loaderID = "DD4A76F842AA389647D702B4D805F49A";

    // send attachToTarget event
    const attached = AttachToTarget{
        .sessionId = ContextSessionID,
        .targetInfo = .{
            .targetId = ctx.state.frameID,
            .title = "",
            .url = ctx.state.url,
            .browserContextId = ContextID,
        },
        .waitingForDebugger = true,
    };
    try cdp.sendEvent(alloc, ctx, "Target.attachedToTarget", AttachToTarget, attached, msg.sessionID);

    // output
    const Resp = struct {
        targetId: []const u8 = TargetID,
    };
    return result(alloc, id orelse msg.id.?, Resp, Resp{}, msg.sessionID);
}
