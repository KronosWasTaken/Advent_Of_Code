const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

fn insertTop(total: u32, top: *[3]u32) void {
    if (total <= top[0]) return;
    top[0] = total;
    if (top[0] > top[1]) std.mem.swap(u32, &top[0], &top[1]);
    if (top[1] > top[2]) std.mem.swap(u32, &top[1], &top[2]);
}

fn solve(input: []const u8) Result {
    var top: [3]u32 = .{ 0, 0, 0 };
    var total: u32 = 0;
    var number: u32 = 0;
    var in_number = false;
    var blank = true;
    var last_was_cr = false;

    var i: usize = 0;
    while (i <= input.len) : (i += 1) {
        const b: u8 = if (i < input.len) input[i] else '\n';
        if (last_was_cr and b == '\n') {
            last_was_cr = false;
            continue;
        }
        last_was_cr = b == '\r';
        if (b >= '0' and b <= '9') {
            number = number * 10 + (b - '0');
            in_number = true;
            blank = false;
            continue;
        }
        if (in_number) {
            total += number;
            number = 0;
            in_number = false;
        }
        if (b == '\n' or b == '\r') {
            if (blank) {
                insertTop(total, &top);
                total = 0;
            }
            blank = true;
        } else {
            blank = false;
        }
    }

    insertTop(total, &top);
    return .{ .p1 = top[2], .p2 = top[0] + top[1] + top[2] };
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
