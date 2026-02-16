const std = @import("std");

const Result = struct {
    p1: u32,

    p2: u32,
};

const Pos = struct {
    x: i32,

    y: i32,
};

fn solve(input: []const u8) !Result {
    const line_end = std.mem.indexOfScalar(u8, input, '\n') orelse 0;

    var width = line_end;

    var stride = line_end + 1;

    if (line_end > 0 and input[line_end - 1] == '\r') {
        width = line_end - 1;

        stride = line_end + 1;
    }

    const height = if (stride > 0) input.len / stride else 0;

    const allocator = std.heap.page_allocator;

    var lists: [256]std.ArrayListUnmanaged(Pos) = undefined;

    for (&lists) |*list| list.* = .{};

    defer for (&lists) |*list| list.deinit(allocator);

    for (0..height) |y| {
        const row = input[y * stride ..][0..width];

        for (row, 0..) |ch, x| {
            if (ch == '.') continue;

            lists[ch].append(allocator, .{ .x = @intCast(x), .y = @intCast(y) }) catch unreachable;
        }
    }

    const size = width * height;

    var anti1 = try allocator.alloc(bool, size);

    defer allocator.free(anti1);

    var anti2 = try allocator.alloc(bool, size);

    defer allocator.free(anti2);

    @memset(anti1, false);

    @memset(anti2, false);

    for (lists) |list| {
        for (list.items) |pos| {
            const idx = @as(usize, @intCast(pos.y)) * width + @as(usize, @intCast(pos.x));

            anti2[idx] = true;
        }

        for (list.items, 0..) |a, i| {
            for (list.items[i + 1 ..]) |b| {
                const dx = b.x - a.x;

                const dy = b.y - a.y;

                const p1x = a.x - dx;

                const p1y = a.y - dy;

                if (p1x >= 0 and p1y >= 0 and p1x < @as(i32, @intCast(width)) and p1y < @as(i32, @intCast(height))) {
                    anti1[@as(usize, @intCast(p1y)) * width + @as(usize, @intCast(p1x))] = true;
                }

                const p2x = b.x + dx;

                const p2y = b.y + dy;

                if (p2x >= 0 and p2y >= 0 and p2x < @as(i32, @intCast(width)) and p2y < @as(i32, @intCast(height))) {
                    anti1[@as(usize, @intCast(p2y)) * width + @as(usize, @intCast(p2x))] = true;
                }

                var cx = a.x - dx;

                var cy = a.y - dy;

                while (cx >= 0 and cy >= 0 and cx < @as(i32, @intCast(width)) and cy < @as(i32, @intCast(height))) {
                    anti2[@as(usize, @intCast(cy)) * width + @as(usize, @intCast(cx))] = true;

                    cx -= dx;

                    cy -= dy;
                }

                cx = b.x + dx;

                cy = b.y + dy;

                while (cx >= 0 and cy >= 0 and cx < @as(i32, @intCast(width)) and cy < @as(i32, @intCast(height))) {
                    anti2[@as(usize, @intCast(cy)) * width + @as(usize, @intCast(cx))] = true;

                    cx += dx;

                    cy += dy;
                }
            }
        }
    }

    var p1: u32 = 0;

    var p2: u32 = 0;

    for (anti1) |v| {
        if (v) p1 += 1;
    }

    for (anti2) |v| {
        if (v) p2 += 1;
    }

    return Result{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");

    var timer = try std.time.Timer.start();

    const start = timer.read();

    const result = try solve(input);

    const elapsed_ns = timer.read() - start;

    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;

    std.debug.print("Part 1: {}\n", .{result.p1});

    std.debug.print("Part 2: {}\n", .{result.p2});

    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
