const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

fn solve(input: []const u8) Result {
    var rules = [_]u128{0} ** 100;
    var p1: u32 = 0;
    var p2: u32 = 0;

    var in_updates = false;
    var line_it = std.mem.splitScalar(u8, input, '\n');
    while (line_it.next()) |raw| {
        var line = raw;
        if (line.len > 0 and line[line.len - 1] == '\r') {
            line = line[0 .. line.len - 1];
        }
        if (line.len == 0) {
            in_updates = true;
            continue;
        }

        if (!in_updates) {
            const left = (line[0] - '0') * 10 + (line[1] - '0');
            const right = (line[3] - '0') * 10 + (line[4] - '0');
            rules[left] |= @as(u128, 1) << @intCast(right);
            continue;
        }

        var buf: [24]u8 = undefined;
        var len: usize = 0;
        var mask: u128 = 0;
        var valid = true;

        var i: usize = 0;
        while (i + 1 < line.len) : (i += 3) {
            const n = (line[i] - '0') * 10 + (line[i + 1] - '0');
            buf[len] = n;
            len += 1;
            if ((rules[n] & mask) != 0) valid = false;
            mask |= @as(u128, 1) << @intCast(n);
        }

        if (valid) {
            p1 += buf[len / 2];
            continue;
        }

        for (buf[0..len]) |n| {
            const succs = rules[n] & mask;
            if (@popCount(succs) == len / 2) {
                p2 += n;
                break;
            }
        }
    }

    return Result{ .p1 = p1, .p2 = p2 };
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
