const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

fn parseUnsigned(token: []const u8) u32 {
    var value: u32 = 0;
    for (token) |b| {
        if (b < '0' or b > '9') break;
        value = value * 10 + (b - '0');
    }
    return value;
}

pub fn solve(input: []const u8) Result {
    var sum1: u64 = 0;
    var sum2: u64 = 0;
    var lines = std.mem.splitScalar(u8, input, '\n');
    var id: usize = 1;
    while (lines.next()) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, "\r");
        if (line.len == 0) continue;
        var max_r: u32 = 0;
        var max_g: u32 = 0;
        var max_b: u32 = 0;
        var it = std.mem.tokenizeAny(u8, line, " \t");
        _ = it.next();
        _ = it.next();
        while (true) {
            const amount_tok = it.next() orelse break;
            const color_tok = it.next() orelse break;
            const amount = parseUnsigned(amount_tok);
            switch (color_tok[0]) {
                'r' => max_r = @max(max_r, amount),
                'g' => max_g = @max(max_g, amount),
                'b' => max_b = @max(max_b, amount),
                else => {},
            }
        }
        if (max_r <= 12 and max_g <= 13 and max_b <= 14) sum1 += id;
        sum2 += @as(u64, max_r) * max_g * max_b;
        id += 1;
    }
    return .{ .p1 = sum1, .p2 = sum2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
