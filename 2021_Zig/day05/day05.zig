const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

fn sign(value: i32) i32 {
    if (value > 0) return 1;
    if (value < 0) return -1;
    return 0;
}

fn absI32(value: i32) i32 {
    return if (value < 0) -value else value;
}

fn countLines(input: []const u8) usize {
    var count: usize = 0;
    for (input) |c| {
        if (c == '\n') count += 1;
    }
    if (input.len > 0 and input[input.len - 1] != '\n') count += 1;
    return count;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const line_count = countLines(input);
    const lines = allocator.alloc([4]i32, line_count) catch unreachable;
    defer allocator.free(lines);

    var line_idx: usize = 0;
    var number_idx: usize = 0;
    var current: [4]i32 = undefined;
    var value: i32 = 0;
    var in_number = false;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            value = value * 10 + @as(i32, c - '0');
            in_number = true;
            continue;
        }
        if (!in_number) continue;
        current[number_idx] = value;
        number_idx += 1;
        if (number_idx == 4) {
            lines[line_idx] = current;
            line_idx += 1;
            number_idx = 0;
        }
        value = 0;
        in_number = false;
    }
    if (in_number) {
        current[number_idx] = value;
        number_idx += 1;
        if (number_idx == 4) {
            lines[line_idx] = current;
            line_idx += 1;
        }
    }

    var grid: [1_000_000]u8 = [_]u8{0} ** 1_000_000;
    var overlaps: usize = 0;
    var overlaps_diag: usize = 0;

    var i: usize = 0;
    while (i < line_idx) : (i += 1) {
        const line = lines[i];
        if (line[0] != line[2] and line[1] != line[3]) continue;

        const x1 = line[0];
        const y1 = line[1];
        const x2 = line[2];
        const y2 = line[3];
        const dx = sign(x2 - x1);
        const dy = sign(y2 - y1);
        const delta_x = absI32(x2 - x1);
        const delta_y = absI32(y2 - y1);
        const count = if (delta_x > delta_y) delta_x else delta_y;
        const delta = dy * 1000 + dx;
        var index = y1 * 1000 + x1;

        var step: i32 = 0;
        while (step <= count) : (step += 1) {
            const idx = @as(usize, @intCast(index));
            if (grid[idx] == 1) overlaps += 1;
            grid[idx] += 1;
            index += delta;
        }
    }

    i = 0;
    while (i < line_idx) : (i += 1) {
        const line = lines[i];
        if (line[0] == line[2] or line[1] == line[3]) continue;

        const x1 = line[0];
        const y1 = line[1];
        const x2 = line[2];
        const y2 = line[3];
        const dx = sign(x2 - x1);
        const dy = sign(y2 - y1);
        const delta_x = absI32(x2 - x1);
        const delta_y = absI32(y2 - y1);
        const count = if (delta_x > delta_y) delta_x else delta_y;
        const delta = dy * 1000 + dx;
        var index = y1 * 1000 + x1;

        var step: i32 = 0;
        while (step <= count) : (step += 1) {
            const idx = @as(usize, @intCast(index));
            if (grid[idx] == 1) overlaps_diag += 1;
            grid[idx] += 1;
            index += delta;
        }
    }

    return .{ .p1 = overlaps, .p2 = overlaps + overlaps_diag };
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
