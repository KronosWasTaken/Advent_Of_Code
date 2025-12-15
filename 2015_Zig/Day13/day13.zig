const std = @import("std");
fn parse(input: []const u8, alloc: std.mem.Allocator) !struct { edge: [16][16]i16, n: u8 } {
    @setRuntimeSafety(false);
    var map = std.StringHashMap(u8).init(alloc);
    defer map.deinit();
    var hap: [16][16]i16 = [_][16]i16{[_]i16{0} ** 16} ** 16;
    var cnt: u8 = 0;
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        const p1_name = it.next() orelse continue;
        _ = it.next(); // "would"
        const sign_str = it.next().?;
        const val_str = it.next().?;
        _ = it.next(); // "happiness"
        _ = it.next(); // "units"
        _ = it.next(); // "by"
        _ = it.next(); // "sitting"
        _ = it.next(); // "next"
        _ = it.next(); // "to"
        var p2_name = it.next().?;
        p2_name = p2_name[0..p2_name.len - 1]; // Remove '.'
        const p1_res = try map.getOrPut(p1_name);
        if (!p1_res.found_existing) {
            p1_res.value_ptr.* = cnt;
            cnt += 1;
        }
        const p2_res = try map.getOrPut(p2_name);
        if (!p2_res.found_existing) {
            p2_res.value_ptr.* = cnt;
            cnt += 1;
        }
        const val = try std.fmt.parseInt(i16, val_str, 10);
        const sign: i16 = if (sign_str[0] == 'g') 1 else -1;
        hap[p1_res.value_ptr.*][p2_res.value_ptr.*] = sign * val;
    }
    var edge: [16][16]i16 = [_][16]i16{[_]i16{0} ** 16} ** 16;
    var a: u8 = 0;
    while (a < cnt) : (a += 1) {
        var b: u8 = 0;
        while (b < cnt) : (b += 1) {
            edge[a][b] = hap[a][b] + hap[b][a];
        }
    }
    return .{ .edge = edge, .n = cnt };
}
fn permute(perm: []u8, used: u16, pos: u8, n: u8, edge: *const [16][16]i16, best: *i32, sum: i32) void {
    @setRuntimeSafety(false);
    if (pos == n) {
        const total = sum + edge[perm[n - 1]][perm[0]];
        if (total > best.*) best.* = total;
        return;
    }
    if (pos == 0) {
        perm[0] = 0;
        permute(perm, 1, 1, n, edge, best, 0);
        return;
    }
    const prev = perm[pos - 1];
    const start: u8 = 1;
    const end: u8 = if (pos == 1 and n > 2) (n / 2 + 1) else n;
    var i: u8 = start;
    while (i < end) : (i += 1) {
        const mask: u16 = @as(u16, 1) << @intCast(i);
        if (used & mask == 0) {
            perm[pos] = i;
            permute(perm, used | mask, pos + 1, n, edge, best, sum + edge[prev][i]);
        }
    }
}
fn solvePart(edge: *const [16][16]i16, n: u8) i32 {
    @setRuntimeSafety(false);
    var perm: [16]u8 = undefined;
    var best: i32 = -999999;
    permute(&perm, 0, 0, n, edge, &best, 0);
    return best;
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const parsed = try parse(input, alloc);
    const p1 = solvePart(&parsed.edge, parsed.n);
    const p2 = solvePart(&parsed.edge, parsed.n + 1);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ p1, p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
