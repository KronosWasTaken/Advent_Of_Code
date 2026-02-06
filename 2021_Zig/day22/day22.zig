const std = @import("std");

const Result = struct { p1: i64, p2: i64 };

const Cube = struct {
    x1: i32,
    x2: i32,
    y1: i32,
    y2: i32,
    z1: i32,
    z2: i32,

    fn from(points: [6]i32) Cube {
        return .{
            .x1 = @min(points[0], points[1]),
            .x2 = @max(points[0], points[1]),
            .y1 = @min(points[2], points[3]),
            .y2 = @max(points[2], points[3]),
            .z1 = @min(points[4], points[5]),
            .z2 = @max(points[4], points[5]),
        };
    }

    fn intersect(self: Cube, other: Cube) ?Cube {
        const x1 = @max(self.x1, other.x1);
        const x2 = @min(self.x2, other.x2);
        const y1 = @max(self.y1, other.y1);
        const y2 = @min(self.y2, other.y2);
        const z1 = @max(self.z1, other.z1);
        const z2 = @min(self.z2, other.z2);
        if (x1 <= x2 and y1 <= y2 and z1 <= z2) {
            return Cube{ .x1 = x1, .x2 = x2, .y1 = y1, .y2 = y2, .z1 = z1, .z2 = z2 };
        }
        return null;
    }

    fn volume(self: Cube) i64 {
        const w: i64 = @as(i64, self.x2 - self.x1 + 1);
        const h: i64 = @as(i64, self.y2 - self.y1 + 1);
        const d: i64 = @as(i64, self.z2 - self.z1 + 1);
        return w * h * d;
    }
};

const RebootStep = struct { on: bool, cube: Cube };

fn parse(input: []const u8, allocator: std.mem.Allocator) []RebootStep {
    var steps = std.ArrayListUnmanaged(RebootStep){};
    defer steps.deinit(allocator);

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trimRight(u8, raw, "\r");
        if (line.len == 0) continue;
        const on = std.mem.startsWith(u8, line, "on");

        var nums: [6]i32 = undefined;
        var idx: usize = 0;
        var value: i32 = 0;
        var sign: i32 = 1;
        var in_num = false;
        for (line) |c| {
            if (c == '-') {
                sign = -1;
                continue;
            }
            if (c >= '0' and c <= '9') {
                value = value * 10 + @as(i32, c - '0');
                in_num = true;
                continue;
            }
            if (in_num) {
                nums[idx] = value * sign;
                idx += 1;
                value = 0;
                sign = 1;
                in_num = false;
            }
        }
        if (in_num and idx < 6) {
            nums[idx] = value * sign;
            idx += 1;
        }
        if (idx == 6) {
            steps.append(allocator, .{ .on = on, .cube = Cube.from(nums) }) catch unreachable;
        }
    }

    return steps.toOwnedSlice(allocator) catch unreachable;
}

fn subsets(cube: Cube, sign: i64, candidates: []const Cube) i64 {
    var total: i64 = 0;
    var i: usize = 0;
    while (i < candidates.len) : (i += 1) {
        if (cube.intersect(candidates[i])) |next| {
            total += sign * next.volume() + subsets(next, -sign, candidates[(i + 1)..]);
        }
    }
    return total;
}

fn part2(steps: []const RebootStep) i64 {
    var total: i64 = 0;
    var candidates = std.ArrayListUnmanaged(Cube){};
    defer candidates.deinit(std.heap.page_allocator);

    for (steps, 0..) |step, i| {
        if (!step.on) continue;
        candidates.clearRetainingCapacity();
        var j: usize = i + 1;
        while (j < steps.len) : (j += 1) {
            if (step.cube.intersect(steps[j].cube)) |next| {
                candidates.append(std.heap.page_allocator, next) catch unreachable;
            }
        }
        total += step.cube.volume() + subsets(step.cube, -1, candidates.items);
    }
    return total;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const steps = parse(input, allocator);
    defer allocator.free(steps);

    const region = Cube{ .x1 = -50, .x2 = 50, .y1 = -50, .y2 = 50, .z1 = -50, .z2 = 50 };
    var filtered = std.ArrayListUnmanaged(RebootStep){};
    defer filtered.deinit(allocator);
    for (steps) |step| {
        if (region.intersect(step.cube)) |next| {
            filtered.append(allocator, .{ .on = step.on, .cube = next }) catch unreachable;
        }
    }

    const p1 = part2(filtered.items);
    const p2 = part2(steps);
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
