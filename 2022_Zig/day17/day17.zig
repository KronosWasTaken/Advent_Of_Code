const std = @import("std");

const FLOOR: u8 = 0xff;
const WALLS: u32 = 0x01010101;
const Rock = struct { size: usize, shape: u32 };
const ROCKS = [_]Rock{
    .{ .size = 1, .shape = 0x0000003c },
    .{ .size = 3, .shape = 0x00103810 },
    .{ .size = 3, .shape = 0x00080838 },
    .{ .size = 4, .shape = 0x20202020 },
    .{ .size = 2, .shape = 0x00003030 },
};

const State = struct {
    jets: []const u8,
    tower: []u8,
    height: usize,
    rock_idx: usize,
    jet_idx: usize,

    fn init(input: []const u8, allocator: std.mem.Allocator) !State {
        var jets = try allocator.alloc(u8, input.len);
        var jet_count: usize = 0;
        for (input) |b| {
            if (b == '<' or b == '>') {
                jets[jet_count] = b;
                jet_count += 1;
            }
        }
        jets = jets[0..jet_count];
        var tower = try allocator.alloc(u8, 13_000);
        @memset(tower, 0);
        tower[0] = FLOOR;
        return .{ .jets = jets, .tower = tower, .height = 0, .rock_idx = 0, .jet_idx = 0 };
    }

    fn next(self: *State) usize {
        const rock = ROCKS[self.rock_idx];
        self.rock_idx = (self.rock_idx + 1) % ROCKS.len;
        var shape = rock.shape;
        var chunk: u32 = WALLS;
        var index = self.height + 3;

        while (true) {
            const jet = self.jets[self.jet_idx];
            self.jet_idx = (self.jet_idx + 1) % self.jets.len;
            const candidate = if (jet == '<') std.math.rotl(u32, shape, 1) else std.math.rotr(u32, shape, 1);
            if (candidate & chunk == 0) shape = candidate;

            chunk = (chunk << 8) | WALLS | @as(u32, self.tower[index]);
            if (shape & chunk == 0) {
                index -= 1;
            } else {
                const bytes = std.mem.toBytes(shape);
                self.tower[index + 1] |= bytes[0];
                self.tower[index + 2] |= bytes[1];
                self.tower[index + 3] |= bytes[2];
                self.tower[index + 4] |= bytes[3];
                self.height = @max(self.height, index + rock.size);
                return self.height;
            }
        }
    }
};

const Result = struct {
    p1: usize,
    p2: usize,
};

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    var state = State.init(input, allocator) catch unreachable;
    defer {
        allocator.free(state.jets);
        allocator.free(state.tower);
    }

    var heights = allocator.alloc(usize, 5000) catch unreachable;
    defer allocator.free(heights);
    for (0..5000) |i| heights[i] = state.next();

    const p1 = heights[2021];

    const guess: usize = 1000;
    var deltas = allocator.alloc(usize, 5000) catch unreachable;
    defer allocator.free(deltas);
    var prev: usize = 0;
    for (heights, 0..) |h, i| {
        deltas[i] = h - prev;
        prev = h;
    }

    const end = deltas.len - guess;
    const needle = deltas[end..];
    var start: usize = 0;
    for (0..end - guess) |i| {
        if (std.mem.eql(usize, deltas[i .. i + guess], needle)) {
            start = i;
            break;
        }
    }

    const cycle_height = heights[end] - heights[start];
    const cycle_width = end - start;
    const offset = 1_000_000_000_000 - 1 - start;
    const quotient = offset / cycle_width;
    const remainder = offset % cycle_width;
    const p2 = (quotient * cycle_height) + heights[start + remainder];

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
