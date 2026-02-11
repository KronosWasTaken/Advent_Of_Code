const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

fn solve(input: []const u8) Result {
    var count: usize = 0;
    var value: u32 = 0;
    var in_number = false;
    var last_was_cr = false;
    var p1: u32 = 0;
    var p2: u32 = 0;
    var a: u32 = 0;
    var b2: u32 = 0;
    var c: u32 = 0;
    var d: u32 = 0;

    var i: usize = 0;
    while (i <= input.len) : (i += 1) {
        const b: u8 = if (i < input.len) input[i] else '\n';
        if (last_was_cr and b == '\n') {
            last_was_cr = false;
            continue;
        }
        last_was_cr = b == '\r';
        if (b >= '0' and b <= '9') {
            value = value * 10 + (b - '0');
            in_number = true;
            continue;
        }
        if (in_number) {
            switch (count) {
                0 => a = value,
                1 => b2 = value,
                2 => c = value,
                else => d = value,
            }
            count += 1;
            value = 0;
            in_number = false;
            if (count == 4) {
                if ((a >= c and b2 <= d) or (c >= a and d <= b2)) p1 += 1;
                if (a <= d and c <= b2) p2 += 1;
                count = 0;
            }
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
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
