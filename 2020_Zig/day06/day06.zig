const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

fn solve(input: []const u8) Result {
    var total_or: u32 = 0;
    var total_and: u32 = 0;

    var group_or: u32 = 0;
    var group_and: u32 = 0xffffffff;

    var mask: u32 = 0;
    var last_newline = true;

    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        var c = input[i];
        if (c == '\r') {
            if (i + 1 < input.len and input[i + 1] == '\n') {
                i += 1;
            }
            c = '\n';
        }

        if (c >= 'a' and c <= 'z') {
            mask |= @as(u32, 1) << @intCast(c - 'a');
            last_newline = false;
            continue;
        }

        if (c == '\n') {
            if (!last_newline) {
                group_or |= mask;
                group_and &= mask;
                mask = 0;
            } else {
                total_or += @popCount(group_or);
                total_and += @popCount(group_and);
                group_or = 0;
                group_and = 0xffffffff;
            }
            last_newline = true;
        }
    }

    if (!last_newline) {
        group_or |= mask;
        group_and &= mask;
    }
    if (group_or != 0 or group_and != 0xffffffff) {
        total_or += @popCount(group_or);
        total_and += @popCount(group_and);
    }

    return .{ .p1 = total_or, .p2 = total_and };
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
