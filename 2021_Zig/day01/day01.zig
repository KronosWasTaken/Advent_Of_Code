const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

fn solve(input: []const u8) Result {
    var p1: usize = 0;
    var p2: usize = 0;

    var prev: ?u32 = null;
    var buf: [4]u32 = undefined;
    var count: usize = 0;

    const process = struct {
        fn run(value: u32, p1_ptr: *usize, p2_ptr: *usize, prev_ptr: *?u32, buf_ptr: *[4]u32, count_ptr: *usize) void {
            if (prev_ptr.*) |p| {
                if (p < value) p1_ptr.* += 1;
            }
            if (count_ptr.* >= 3) {
                const old_idx = (count_ptr.* - 3) & 3;
                if (buf_ptr.*[old_idx] < value) p2_ptr.* += 1;
            }
            const idx = count_ptr.* & 3;
            buf_ptr.*[idx] = value;
            count_ptr.* += 1;
            prev_ptr.* = value;
        }
    }.run;

    var value: u32 = 0;
    var in_number = false;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            value = value * 10 + @as(u32, c - '0');
            in_number = true;
            continue;
        }
        if (!in_number) continue;
        process(value, &p1, &p2, &prev, &buf, &count);
        value = 0;
        in_number = false;
    }

    if (in_number) {
        process(value, &p1, &p2, &prev, &buf, &count);
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
