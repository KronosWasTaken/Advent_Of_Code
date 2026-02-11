const std = @import("std");

const ONES: u64 = 0x0041041041041041;
const MASK: u64 = 0x0fffffffffffffc0;

const Result = struct {
    p1: usize,
    p2: u64,
};

const Input = struct {
    width: usize,
    height: usize,
    digits: []i8,
};

fn parse(input: []const u8, allocator: std.mem.Allocator) !Input {
    var width: usize = 0;
    var height: usize = 0;
    var current_width: usize = 0;
    var i: usize = 0;

    while (i < input.len) {
        const b = input[i];
        if (b == '\r' or b == '\n') {
            if (current_width > 0) {
                if (width == 0) width = current_width;
                height += 1;
                current_width = 0;
            }
            if (b == '\r' and i + 1 < input.len and input[i + 1] == '\n') i += 1;
        } else if (b >= '0' and b <= '9') {
            current_width += 1;
        }
        i += 1;
    }
    if (current_width > 0) {
        if (width == 0) width = current_width;
        height += 1;
    }

    const total = width * height;
    var digits = try allocator.alloc(i8, total);

    var index: usize = 0;
    i = 0;
    while (i < input.len) {
        const b = input[i];
        if (b == '\r' or b == '\n') {
            if (b == '\r' and i + 1 < input.len and input[i + 1] == '\n') i += 1;
        } else if (b >= '0' and b <= '9') {
            digits[index] = @intCast(6 * (b - '0'));
            index += 1;
        }
        i += 1;
    }

    return .{ .width = width, .height = height, .digits = digits };
}

fn part1(input: Input, visible: []bool) usize {
    const width = input.width;
    const height = input.height;
    const digits = input.digits;
    if (width == 0) return 0;
    @memset(visible, false);

    var i: usize = 1;
    while (i + 1 < width) : (i += 1) {
        var left_max: i8 = -1;
        var right_max: i8 = -1;
        var top_max: i8 = -1;
        var bottom_max: i8 = -1;

        var j: usize = 0;
        while (j + 1 < width) : (j += 1) {
            const left = (i * width) + j;
            if (digits[left] > left_max) {
                visible[left] = true;
                left_max = digits[left];
            }

            const right = (i * width) + (width - j - 1);
            if (digits[right] > right_max) {
                visible[right] = true;
                right_max = digits[right];
            }

            const top = (j * width) + i;
            if (digits[top] > top_max) {
                visible[top] = true;
                top_max = digits[top];
            }

            const bottom = (width - j - 1) * width + i;
            if (digits[bottom] > bottom_max) {
                visible[bottom] = true;
                bottom_max = digits[bottom];
            }
        }
    }

    var count: usize = 4;
    for (visible) |v| {
        if (v) count += 1;
    }
    if (height == 1 or width == 1) return width * height;
    return count;
}

fn part2(input: Input, scenic: []u64) u64 {
    const width = input.width;
    const digits = input.digits;
    if (width == 0) return 0;
    @memset(scenic, 1);

    var i: usize = 1;
    while (i + 1 < width) : (i += 1) {
        var left_max: u64 = ONES;
        var right_max: u64 = ONES;
        var top_max: u64 = ONES;
        var bottom_max: u64 = ONES;

        var j: usize = 1;
        while (j + 1 < width) : (j += 1) {
            const left = (i * width) + j;
            const shift_left: u6 = @intCast(digits[left]);
            scenic[left] *= (left_max >> shift_left) & 0x3f;
            left_max = (left_max & (MASK << shift_left)) + ONES;

            const right = (i * width) + (width - j - 1);
            const shift_right: u6 = @intCast(digits[right]);
            scenic[right] *= (right_max >> shift_right) & 0x3f;
            right_max = (right_max & (MASK << shift_right)) + ONES;

            const top = (j * width) + i;
            const shift_top: u6 = @intCast(digits[top]);
            scenic[top] *= (top_max >> shift_top) & 0x3f;
            top_max = (top_max & (MASK << shift_top)) + ONES;

            const bottom = (width - j - 1) * width + i;
            const shift_bottom: u6 = @intCast(digits[bottom]);
            scenic[bottom] *= (bottom_max >> shift_bottom) & 0x3f;
            bottom_max = (bottom_max & (MASK << shift_bottom)) + ONES;
        }
    }

    var best: u64 = 0;
    for (scenic) |score| {
        if (score > best) best = score;
    }
    return best;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const parsed = parse(input, allocator) catch unreachable;
    defer allocator.free(parsed.digits);

    const total = parsed.width * parsed.height;
    const visible = allocator.alloc(bool, total) catch unreachable;
    defer allocator.free(visible);
    const scenic = allocator.alloc(u64, total) catch unreachable;
    defer allocator.free(scenic);

    return .{ .p1 = part1(parsed, visible), .p2 = part2(parsed, scenic) };
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
