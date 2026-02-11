const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

const Input = struct {
    grid: []u8,
    seen: []usize,
    parts: []u32,
    width: usize,
    height: usize,
    stride: usize,
};

fn parseInput(alloc: std.mem.Allocator, input: []const u8) !Input {
    var width: usize = 0;
    var height: usize = 0;
    var cur: usize = 0;
    for (input) |b| {
        if (b == '\r') continue;
        if (b == '\n') {
            if (cur > 0) {
                if (width == 0) width = cur;
                height += 1;
                cur = 0;
            }
        } else {
            cur += 1;
        }
    }
    if (cur > 0) {
        if (width == 0) width = cur;
        height += 1;
    }
    if (width == 0 or height == 0) {
        return Input{ .grid = &[_]u8{}, .seen = &[_]usize{}, .parts = &[_]u32{}, .width = 0, .height = 0, .stride = 0 };
    }

    const stride = width + 2;
    const total = (height + 2) * stride;
    var grid = try alloc.alloc(u8, total);
    var seen = try alloc.alloc(usize, total);
    @memset(grid, '.');
    @memset(seen, 0);

    var parts: std.ArrayListUnmanaged(u32) = .{};
    try parts.append(alloc, 0);

    var y: usize = 0;
    var x: usize = 0;
    var number: u32 = 0;
    var current_index: usize = 0;
    for (input) |b| {
        if (b == '\r') continue;
        if (b == '\n') {
            if (x == 0) continue;
            if (number > 0) {
                try parts.append(alloc, number);
                number = 0;
            }
            y += 1;
            x = 0;
            continue;
        }
        const idx = (y + 1) * stride + (x + 1);
        grid[idx] = b;
        if (b >= '0' and b <= '9') {
            if (number == 0) current_index = parts.items.len;
            seen[idx] = current_index;
            number = number * 10 + (b - '0');
        } else if (number > 0) {
            try parts.append(alloc, number);
            number = 0;
        }
        x += 1;
    }
    if (number > 0) {
        try parts.append(alloc, number);
    }

    return .{
        .grid = grid,
        .seen = seen,
        .parts = parts.items,
        .width = width,
        .height = height,
        .stride = stride,
    };
}

pub fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const parsed = parseInput(alloc, input) catch return .{ .p1 = 0, .p2 = 0 };
    if (parsed.width == 0) return .{ .p1 = 0, .p2 = 0 };

    const stride_i: isize = @intCast(parsed.stride);
    const offsets = [_]isize{
        -stride_i - 1,
        -stride_i,
        -stride_i + 1,
        -1,
        1,
        stride_i - 1,
        stride_i,
        stride_i + 1,
    };

    var parts_copy = alloc.alloc(u32, parsed.parts.len) catch return .{ .p1 = 0, .p2 = 0 };
    @memcpy(parts_copy, parsed.parts);

    var sum1: u64 = 0;
    for (0..parsed.height) |y| {
        for (0..parsed.width) |x| {
            const idx = (y + 1) * parsed.stride + (x + 1);
            const idx_i: isize = @intCast(idx);
            const b = parsed.grid[idx];
            if (!((b >= '0' and b <= '9') or b == '.')) {
                for (offsets) |off| {
                    const nidx = @as(usize, @intCast(idx_i + off));
                    const part_index = parsed.seen[nidx];
                    if (part_index != 0 and parts_copy[part_index] != 0) {
                        sum1 += parts_copy[part_index];
                        parts_copy[part_index] = 0;
                    }
                }
            }
        }
    }

    var sum2: u64 = 0;
    for (0..parsed.height) |y| {
        for (0..parsed.width) |x| {
            const idx = (y + 1) * parsed.stride + (x + 1);
            const idx_i: isize = @intCast(idx);
            if (parsed.grid[idx] == '*') {
                var previous: usize = 0;
                var distinct: u8 = 0;
                var subtotal: u64 = 1;
                for (offsets) |off| {
                    const nidx = @as(usize, @intCast(idx_i + off));
                    const part_index = parsed.seen[nidx];
                    if (part_index != 0 and part_index != previous) {
                        previous = part_index;
                        distinct += 1;
                        subtotal *= parsed.parts[part_index];
                    }
                }
                if (distinct == 2) sum2 += subtotal;
            }
        }
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
