const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

fn findDigit(line: []const u8, idx: usize) ?u8 {
    const b = line[idx];
    if (b >= '0' and b <= '9') return b - '0';
    const tail = line[idx..];
    return switch (b) {
        'o' => if (std.mem.startsWith(u8, tail, "one")) 1 else null,
        't' => if (std.mem.startsWith(u8, tail, "two")) 2 else if (std.mem.startsWith(u8, tail, "three")) 3 else null,
        'f' => if (std.mem.startsWith(u8, tail, "four")) 4 else if (std.mem.startsWith(u8, tail, "five")) 5 else null,
        's' => if (std.mem.startsWith(u8, tail, "six")) 6 else if (std.mem.startsWith(u8, tail, "seven")) 7 else null,
        'e' => if (std.mem.startsWith(u8, tail, "eight")) 8 else null,
        'n' => if (std.mem.startsWith(u8, tail, "nine")) 9 else null,
        else => null,
    };
}

pub fn solve(input: []const u8) Result {
    var sum1: u64 = 0;
    var sum2: u64 = 0;
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, "\r");
        if (line.len == 0) continue;
        var i: usize = 0;
        var first1: u8 = 0;
        while (i < line.len) : (i += 1) {
            const b = line[i];
            if (b >= '0' and b <= '9') {
                first1 = b - '0';
                break;
            }
        }
        var j: usize = line.len;
        var last1: u8 = 0;
        while (j > 0) {
            j -= 1;
            const b = line[j];
            if (b >= '0' and b <= '9') {
                last1 = b - '0';
                break;
            }
        }
        sum1 += @as(u64, first1) * 10 + last1;

        i = 0;
        var first2: u8 = 0;
        while (i < line.len) : (i += 1) {
            if (findDigit(line, i)) |value| {
                first2 = value;
                break;
            }
        }
        j = line.len;
        var last2: u8 = 0;
        while (j > 0) {
            j -= 1;
            if (findDigit(line, j)) |value| {
                last2 = value;
                break;
            }
        }
        sum2 += @as(u64, first2) * 10 + last2;
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
