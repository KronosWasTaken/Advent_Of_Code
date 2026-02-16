const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

const Off = struct { dx: i32, dy: i32 };
const ORTHO = [_]Off{
    .{ .dx = 1, .dy = 0 },
    .{ .dx = -1, .dy = 0 },
    .{ .dx = 0, .dy = 1 },
    .{ .dx = 0, .dy = -1 },
};

fn dfs(input: []const u8, width: usize, height: usize, stride: usize, distinct: bool, seen: []i32, id: i32, x: i32, y: i32) u32 {
    var result: u32 = 0;
    const base_idx = @as(usize, @intCast(y)) * stride + @as(usize, @intCast(x));
    const current = input[base_idx];

    for (ORTHO) |off| {
        const nx = x + off.dx;
        const ny = y + off.dy;
        if (nx < 0 or ny < 0 or nx >= @as(i32, @intCast(width)) or ny >= @as(i32, @intCast(height))) continue;
        const nidx_input = @as(usize, @intCast(ny)) * stride + @as(usize, @intCast(nx));
        const nidx_seen = @as(usize, @intCast(ny)) * width + @as(usize, @intCast(nx));
        const next = input[nidx_input];
        if (next + 1 != current) continue;
        if (!distinct and seen[nidx_seen] == id) continue;
        seen[nidx_seen] = id;
        if (next == '0') {
            result += 1;
        } else {
            result += dfs(input, width, height, stride, distinct, seen, id, nx, ny);
        }
    }

    return result;
}

fn solve(input: []const u8, distinct: bool) !u32 {
    const line_end = std.mem.indexOfScalar(u8, input, '\n') orelse 0;
    var width = line_end;
    var stride = line_end + 1;
    if (line_end > 0 and input[line_end - 1] == '\r') {
        width = line_end - 1;
        stride = line_end + 1;
    }
    const height = if (stride > 0) input.len / stride else 0;

    const size = width * height;
    const allocator = std.heap.page_allocator;
    const seen = try allocator.alloc(i32, size);
    defer allocator.free(seen);
    @memset(seen, -1);

    var result: u32 = 0;
    for (0..height) |y| {
        for (0..width) |x| {
            const idx = y * stride + x;
            if (input[idx] == '9') {
                const id: i32 = @intCast(y * width + x);
                result += dfs(input, width, height, stride, distinct, seen, id, @intCast(x), @intCast(y));
            }
        }
    }

    return result;
}

fn solveBoth(input: []const u8) !Result {
    const p1 = try solve(input, false);
    const p2 = try solve(input, true);
    return .{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solveBoth(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
