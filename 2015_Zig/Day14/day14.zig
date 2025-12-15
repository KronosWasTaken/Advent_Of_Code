const std = @import("std");
const Deer = struct { spd: u16, fly: u16, rest: u16 };
fn parse(input: []const u8, deer: []Deer) u8 {
    var cnt: u8 = 0;
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        var parts = std.mem.tokenizeScalar(u8, line, ' ');
        _ = parts.next(); // name
        _ = parts.next(); // "can"
        _ = parts.next(); // "fly"
        const spd = std.fmt.parseInt(u16, parts.next().?, 10) catch 0;
        _ = parts.next(); // "km/s"
        _ = parts.next(); // "for"
        const fly = std.fmt.parseInt(u16, parts.next().?, 10) catch 0;
        _ = parts.next(); // "seconds,"
        _ = parts.next(); // "but"
        _ = parts.next(); // "then"
        _ = parts.next(); // "must"
        _ = parts.next(); // "rest"
        _ = parts.next(); // "for"
        const rest = std.fmt.parseInt(u16, parts.next().?, 10) catch 0;
        deer[cnt] = .{ .spd = spd, .fly = fly, .rest = rest };
        cnt += 1;
    }
    return cnt;
}
inline fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var deer: [16]Deer = undefined;
    const n = parse(input, &deer);
    var pts: [16]u32 = [_]u32{0} ** 16;
    var dists: [16]u32 = [_]u32{0} ** 16;
    var t: u32 = 1;
    while (t <= 2503) : (t += 1) {
        var max_d: u32 = 0;
        var i: u8 = 0;
        while (i < n) : (i += 1) {
            const d = deer[i];
            const cycle = d.fly + d.rest;
            const full = t / cycle;
            const rem = t % cycle;
            const fly_rem = if (rem < d.fly) rem else d.fly;
            dists[i] = (full * d.fly + fly_rem) * d.spd;
            if (dists[i] > max_d) max_d = dists[i];
        }
        i = 0;
        while (i < n) : (i += 1) {
            if (dists[i] == max_d) pts[i] += 1;
        }
    }
    var p1: u32 = 0;
    var p2: u32 = 0;
    var i: u8 = 0;
    while (i < n) : (i += 1) {
        if (dists[i] > p1) p1 = dists[i];
        if (pts[i] > p2) p2 = pts[i];
    }
    return .{ .p1 = p1, .p2 = p2 };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
