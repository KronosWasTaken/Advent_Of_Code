const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

const Pos = struct { x: i32, y: i32 };
const Dir = struct { dx: i32, dy: i32 };
const ORTHO = [_]Dir{
    .{ .dx = 1, .dy = 0 },
    .{ .dx = -1, .dy = 0 },
    .{ .dx = 0, .dy = 1 },
    .{ .dx = 0, .dy = -1 },
};

fn add(a: Pos, d: Dir) Pos {
    return .{ .x = a.x + d.dx, .y = a.y + d.dy };
}

fn clockwise(d: Dir) Dir {
    return .{ .dx = -d.dy, .dy = d.dx };
}

fn counterClockwise(d: Dir) Dir {
    return .{ .dx = d.dy, .dy = -d.dx };
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    const line_end = std.mem.indexOfScalar(u8, input, '\n') orelse 0;
    var width = line_end;
    var stride = line_end + 1;
    if (line_end > 0 and input[line_end - 1] == '\r') {
        width = line_end - 1;
        stride = line_end + 1;
    }
    const height = if (stride > 0) input.len / stride else 0;

    const size = width * height;
    var seen = try allocator.alloc(bool, size);
    defer allocator.free(seen);
    @memset(seen, false);

    var todo: std.ArrayListUnmanaged(Pos) = .{};
    defer todo.deinit(allocator);
    var edge: std.ArrayListUnmanaged(struct { pos: Pos, dir: Dir }) = .{};
    defer edge.deinit(allocator);

    var p1: usize = 0;
    var p2: usize = 0;

    for (0..height) |y| {
        for (0..width) |x| {
            const idx = y * width + x;
            if (seen[idx]) continue;

            const kind = input[y * stride + x];
            const check = struct {
                fn f(input_: []const u8, width_: usize, height_: usize, stride_: usize, kind_: u8, pos: Pos) bool {
                    if (pos.x < 0 or pos.y < 0) return false;
                    if (pos.x >= @as(i32, @intCast(width_)) or pos.y >= @as(i32, @intCast(height_))) return false;
                    const i = @as(usize, @intCast(pos.y)) * stride_ + @as(usize, @intCast(pos.x));
                    return input_[i] == kind_;
                }
            }.f;

            var area: usize = 0;
            var perimeter: usize = 0;
            var sides: usize = 0;

            try todo.append(allocator, .{ .x = @intCast(x), .y = @intCast(y) });
            seen[idx] = true;

            while (area < todo.items.len) : (area += 1) {
                const pos = todo.items[area];
                for (ORTHO) |dir| {
                    const next = add(pos, dir);
                    if (check(input, width, height, stride, kind, next)) {
                        const nidx = @as(usize, @intCast(next.y)) * width + @as(usize, @intCast(next.x));
                        if (!seen[nidx]) {
                            try todo.append(allocator, next);
                            seen[nidx] = true;
                        }
                    } else {
                        try edge.append(allocator, .{ .pos = pos, .dir = dir });
                        perimeter += 1;
                    }
                }
            }

            for (edge.items) |entry| {
                const pos = entry.pos;
                const dir = entry.dir;
                const r = clockwise(dir);
                const l = counterClockwise(dir);

                const left_ok = check(input, width, height, stride, kind, add(pos, l));
                const left_far = check(input, width, height, stride, kind, add(add(pos, l), dir));
                if (!left_ok or left_far) sides += 1;

                const right_ok = check(input, width, height, stride, kind, add(pos, r));
                const right_far = check(input, width, height, stride, kind, add(add(pos, r), dir));
                if (!right_ok or right_far) sides += 1;
            }

            todo.clearRetainingCapacity();
            edge.clearRetainingCapacity();

            p1 += area * perimeter;
            p2 += area * (sides / 2);
        }
    }

    return .{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, std.heap.page_allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
