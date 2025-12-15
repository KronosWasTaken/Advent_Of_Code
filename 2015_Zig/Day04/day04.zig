const std = @import("std");
const KEY = "iwrupvqb";
inline fn formatInt(buf: []u8, n: u32) usize {
    @setRuntimeSafety(false);
    if (n == 0) {
        buf[0] = '0';
        return 1;
    }
    var num = n;
    var len: usize = 0;
    var temp: [10]u8 = undefined;
    while (num > 0) {
        temp[len] = @intCast('0' + (num % 10));
        num /= 10;
        len += 1;
    }
    for (0..len) |i| {
        buf[i] = temp[len - 1 - i];
    }
    return len;
}
inline fn hasLeadingZeros(hash: *const [16]u8, count: u8) bool {
    @setRuntimeSafety(false);
    if (count >= 5) {
        if (hash[0] != 0 or hash[1] != 0) return false;
    }
    if (count == 5) {
        return hash[2] < 0x10;
    } else if (count == 6) {
        return hash[2] == 0;
    }
    return true;
}
const ThreadContext = struct {
    start: u32,
    end: u32,
    target_zeros: u8,
    result: ?u32,
    found: *std.atomic.Value(bool),
};
fn threadWork(ctx: *ThreadContext) void {
    @setRuntimeSafety(false);
    var buf: [32]u8 = undefined;
    @memcpy(buf[0..KEY.len], KEY);
    var i = ctx.start;
    const check_interval = 2000;
    var next_check = i + check_interval;
    const unroll_factor = 4;
    const end_unrolled = ctx.end - (ctx.end - i) % unroll_factor;
    while (i < end_unrolled) : (i += unroll_factor) {
        if (i >= next_check) {
            if (ctx.found.load(.acquire)) return;
            next_check = i + check_interval;
        }
        inline for (0..unroll_factor) |offset| {
            const num = i + @as(u32, @intCast(offset));
            const len = KEY.len + formatInt(buf[KEY.len..], num);
            var hash: [16]u8 = undefined;
            std.crypto.hash.Md5.hash(buf[0..len], &hash, .{});
            if (hasLeadingZeros(&hash, ctx.target_zeros)) {
                ctx.result = num;
                ctx.found.store(true, .release);
                return;
            }
        }
    }
    while (i < ctx.end) : (i += 1) {
        if (ctx.found.load(.acquire)) return;
        const len = KEY.len + formatInt(buf[KEY.len..], i);
        var hash: [16]u8 = undefined;
        std.crypto.hash.Md5.hash(buf[0..len], &hash, .{});
        if (hasLeadingZeros(&hash, ctx.target_zeros)) {
            ctx.result = i;
            ctx.found.store(true, .release);
            return;
        }
    }
}
fn solveWithThreads(target_zeros: u8, start_from: u32, num_threads: usize) u32 {
    const chunk_size = 50000;
    var offset: u32 = start_from;
    while (true) {
        var found = std.atomic.Value(bool).init(false);
        var threads: [16]std.Thread = undefined;
        var contexts: [16]ThreadContext = undefined;
        for (0..num_threads) |i| {
            const start = offset + @as(u32, @intCast(i)) * chunk_size;
            const end = start + chunk_size;
            contexts[i] = .{
                .start = start,
                .end = end,
                .target_zeros = target_zeros,
                .result = null,
                .found = &found,
            };
            threads[i] = std.Thread.spawn(.{}, threadWork, .{&contexts[i]}) catch unreachable;
        }
        var min_result: ?u32 = null;
        for (0..num_threads) |i| {
            threads[i].join();
            if (contexts[i].result) |res| {
                if (min_result == null or res < min_result.?) {
                    min_result = res;
                }
            }
        }
        if (min_result) |res| return res;
        offset += @as(u32, @intCast(num_threads)) * chunk_size;
    }
}
pub fn main() !void {
    var part1 = solveWithThreads(5, 1, 8);
    var part2 = solveWithThreads(6, part1 + 1, 16);
    const iters: u32 = 10;
    var timer = try std.time.Timer.start();
    const start = timer.read();
    for (0..iters) |_| {
        part1 = solveWithThreads(5, 1, 8);
        part2 = solveWithThreads(6, part1 + 1, 16);
    }
    const elapsed_us = @as(f64, @floatFromInt(timer.read() - start)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ part1, part2 });
    std.debug.print("Total: {d:.2} microseconds\n", .{elapsed_us});
    std.debug.print("Average: {d:.2} microseconds\n", .{elapsed_us / @as(f64, @floatFromInt(iters))});
}
