const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

fn decodeSeatId(line: []const u8) u16 {
    var id: u16 = 0;
    for (line) |c| {
        id <<= 1;
        id |= @intFromBool(c == 'B' or c == 'R');
    }
    return id;
}

fn xorUpTo(n: u16) u16 {
    return (n & (((n << 1) & 2) - 1)) ^ ((n >> 1) & 1);
}

fn solve(input: []const u8) Result {
    var min_id: u16 = 0x3ff;
    var max_id: u16 = 0;
    var xor_all: u16 = 0;

    var i: usize = 0;
    while (i + 9 < input.len) {
        if (input[i] < ' ') {
            i += 1;
            continue;
        }
        const id = decodeSeatId(input[i .. i + 10]);
        min_id = @min(min_id, id);
        max_id = @max(max_id, id);
        xor_all ^= id;
        i += 10;
        if (i < input.len and input[i] == '\r') i += 1;
        if (i < input.len and input[i] == '\n') i += 1;
    }

    const part1: usize = max_id;
    const part2: usize = xor_all ^ xorUpTo(min_id - 1) ^ xorUpTo(max_id);

    return .{ .p1 = part1, .p2 = part2 };
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
