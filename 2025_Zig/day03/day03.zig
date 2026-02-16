const std = @import("std");

const Result = struct { p1: u64, p2: u64 };

pub fn solve(input: []const u8) Result {
    var sum2: u64 = 0;
    var sum12: u64 = 0;

    var start: usize = 0;
    var i: usize = 0;
    while (i <= input.len) : (i += 1) {
        if (i == input.len or input[i] == '\n') {
            var end = i;
            if (end > start and input[end - 1] == '\r') end -= 1;
            if (end > start) {
                const line = input[start..end];
                sum2 += solveLine(line, 2);
                if (line.len >= 12) sum12 += solveLine(line, 12);
            }
            start = i + 1;
        }
    }

    return .{ .p1 = sum2, .p2 = sum12 };
}

fn solveLine(line: []const u8, comptime n: usize) u64 {
    var batteries: [n]u8 = undefined;
    const end = line.len - n;
    std.mem.copyForwards(u8, batteries[0..], line[end..]);

    var idx: usize = end;
    while (idx > 0) {
        idx -= 1;
        var next = line[idx];
        var b: usize = 0;
        while (b < n) : (b += 1) {
            if (next < batteries[b]) break;
            const prev = batteries[b];
            batteries[b] = next;
            next = prev;
        }
    }

    var joltage: u64 = 0;
    for (batteries) |b| {
        joltage = 10 * joltage + @as(u64, b - '0');
    }
    return joltage;
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
