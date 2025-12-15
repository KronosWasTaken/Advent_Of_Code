const std = @import("std");
const NCR = [_][6]u32{
    .{ 1, 0, 0, 0, 0, 0 },
    .{ 1, 1, 0, 0, 0, 0 },
    .{ 1, 2, 1, 0, 0, 0 },
    .{ 1, 3, 3, 1, 0, 0 },
    .{ 1, 4, 6, 4, 1, 0 },
    .{ 1, 5, 10, 10, 5, 1 },
};
fn combinations(sizes: []const u8, freqs: []const u8, idx: u8, containers: u8, litres: u8, factor: u32, result: []u32) void {
    const n = freqs[idx];
    const size = sizes[idx];
    const is_last = idx >= sizes.len - 1;
    var next = litres;
    var r: u8 = 0;
    while (r <= n) : (r += 1) {
        const new_factor = factor * NCR[n][r];
        if (next < 150) {
            if (!is_last) {
                combinations(sizes, freqs, idx + 1, containers + r, next, new_factor, result);
            }
        } else {
            if (next == 150) {
                result[containers + r] += new_factor;
            }
            break;
        }
        next += size;
    }
}
fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var containers: [20]u8 = undefined;
    var count: u8 = 0;
    var idx: usize = 0;
    while (idx < input.len) {
        if (input[idx] >= '0' and input[idx] <= '9') {
            var val: u8 = 0;
            while (idx < input.len and input[idx] >= '0' and input[idx] <= '9') : (idx += 1) {
                val = val * 10 + (input[idx] - '0');
            }
            containers[count] = val;
            count += 1;
        } else {
            idx += 1;
        }
    }
    var i: u8 = 0;
    while (i < count - 1) : (i += 1) {
        var j: u8 = i + 1;
        while (j < count) : (j += 1) {
            if (containers[j] > containers[i]) {
                const tmp = containers[i];
                containers[i] = containers[j];
                containers[j] = tmp;
            }
        }
    }
    var sizes: [20]u8 = undefined;
    var freqs: [20]u8 = undefined;
    var unique_count: u8 = 0;
    i = 0;
    while (i < count) {
        sizes[unique_count] = containers[i];
        var freq: u8 = 1;
        while (i + freq < count and containers[i + freq] == containers[i]) : (freq += 1) {}
        freqs[unique_count] = freq;
        i += freq;
        unique_count += 1;
    }
    var result: [20]u32 = [_]u32{0} ** 20;
    combinations(sizes[0..unique_count], freqs[0..unique_count], 0, 0, 0, 1, &result);
    var p1: u32 = 0;
    for (result) |val| {
        p1 += val;
    }
    var p2: u32 = 0;
    for (result) |val| {
        if (val > 0) {
            p2 = val;
            break;
        }
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
