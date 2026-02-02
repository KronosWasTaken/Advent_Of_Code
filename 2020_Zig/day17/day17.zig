const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

const Input = struct {
    allocator: std.mem.Allocator,
    initial: [][]bool,
    width: usize,
    height: usize,

    fn init(allocator: std.mem.Allocator, initial: [][]bool) Input {
        const height = initial.len;
        const width = if (height > 0) initial[0].len else 0;
        return .{ .allocator = allocator, .initial = initial, .width = width, .height = height };
    }

    fn deinit(self: Input) void {
        for (self.initial) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.initial);
    }
};

const X: i32 = 22;
const Y: i32 = 22;
const Z: i32 = 15;
const W: i32 = 15;

const STRIDE_X: i32 = 1;
const STRIDE_Y: i32 = X * STRIDE_X;
const STRIDE_Z: i32 = Y * STRIDE_Y;
const STRIDE_W: i32 = Z * STRIDE_Z;

fn parseInput(allocator: std.mem.Allocator, input: []const u8) !Input {
    var initial = std.ArrayListUnmanaged([]bool){};
    errdefer initial.deinit(allocator);

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line_raw| {
        const line = if (line_raw.len > 0 and line_raw[line_raw.len - 1] == '\r')
            line_raw[0 .. line_raw.len - 1]
        else
            line_raw;
        if (line.len == 0) continue;

        var row = std.ArrayListUnmanaged(bool){};
        errdefer row.deinit(allocator);

        for (line) |char| {
            try row.append(allocator, char == '#');
        }

        try initial.append(allocator, try row.toOwnedSlice(allocator));
    }

    return Input.init(allocator, try initial.toOwnedSlice(allocator));
}

fn three_dimensions(allocator: std.mem.Allocator, input: Input) usize {
    const size = @as(usize, @intCast(X * Y * Z));
    const base = STRIDE_X + STRIDE_Y + STRIDE_Z;
    return boot_process(allocator, input, size, base, &[_]i32{0});
}

fn four_dimensions(allocator: std.mem.Allocator, input: Input) usize {
    const size = @as(usize, @intCast(X * Y * Z * W));
    const base = STRIDE_X + STRIDE_Y + STRIDE_Z + STRIDE_W;
    return boot_process(allocator, input, size, base, &[_]i32{ -1, 0, 1 });
}

fn boot_process(allocator: std.mem.Allocator, input: Input, size: usize, base: i32, fourth_dimension: []const i32) usize {
    const dimension = [_]i32{ -1, 0, 1 };

    var neighbors = std.ArrayListUnmanaged(usize){};
    defer neighbors.deinit(allocator);

    for (dimension) |x| {
        for (dimension) |y| {
            for (dimension) |z| {
                for (fourth_dimension) |w| {
                    const offset_i32 = x * STRIDE_X + y * STRIDE_Y + z * STRIDE_Z + w * STRIDE_W;
                    if (offset_i32 != 0) {
                        const offset_isize: isize = @intCast(offset_i32);
                        neighbors.append(allocator, @bitCast(offset_isize)) catch unreachable;
                    }
                }
            }
        }
    }

    var active = std.ArrayListUnmanaged(usize){};
    var candidates = std.ArrayListUnmanaged(usize){};
    var next_active = std.ArrayListUnmanaged(usize){};
    defer active.deinit(allocator);
    defer candidates.deinit(allocator);
    defer next_active.deinit(allocator);

    active.ensureTotalCapacity(allocator, 5_000) catch unreachable;
    candidates.ensureTotalCapacity(allocator, 5_000) catch unreachable;
    next_active.ensureTotalCapacity(allocator, 5_000) catch unreachable;

    for (input.initial, 0..) |row, y| {
        for (row, 0..) |cell, x| {
            if (cell) {
                const index = 7 * base + @as(i32, @intCast(x)) + @as(i32, @intCast(y)) * STRIDE_Y;
                active.append(allocator, @as(usize, @intCast(index))) catch unreachable;
            }
        }
    }

    var state = allocator.alloc(u8, size) catch unreachable;
    defer allocator.free(state);

    var round: usize = 0;
    while (round < 6) : (round += 1) {
        @memset(state, 0);

        for (active.items) |cube| {
            for (neighbors.items) |offset| {
                const index = cube +% offset;
                const count = state[index] + 1;
                state[index] = count;
                if (count == 3) {
                    candidates.append(allocator, index) catch unreachable;
                }
            }
        }

        for (active.items) |cube| {
            if (state[cube] == 2) {
                next_active.append(allocator, cube) catch unreachable;
            }
        }

        for (candidates.items) |cube| {
            if (state[cube] == 3) {
                next_active.append(allocator, cube) catch unreachable;
            }
        }

        std.mem.swap(std.ArrayListUnmanaged(usize), &active, &next_active);
        candidates.clearRetainingCapacity();
        next_active.clearRetainingCapacity();
    }

    return active.items.len;
}

fn solve(input_data: []const u8) Result {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var input = parseInput(allocator, input_data) catch unreachable;
    defer input.deinit();

    const p1 = three_dimensions(allocator, input);
    const p2 = four_dimensions(allocator, input);

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
