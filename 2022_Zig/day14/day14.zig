const std = @import("std");

const Kind = enum(u8) { Air, Falling, Stopped };

const Cave = struct {
    width: usize,
    height: usize,
    kind: []Kind,
};

const Result = struct {
    p1: u32,
    p2: u32,
};

fn parseNumbers(line: []const u8, out: []usize) usize {
    var count: usize = 0;
    var value: usize = 0;
    var in_number = false;
    for (line) |b| {
        if (b >= '0' and b <= '9') {
            value = value * 10 + (b - '0');
            in_number = true;
        } else if (in_number) {
            out[count] = value;
            count += 1;
            value = 0;
            in_number = false;
        }
    }
    if (in_number) {
        out[count] = value;
        count += 1;
    }
    return count;
}

fn parse(input: []const u8, allocator: std.mem.Allocator) !Cave {
    var lines = std.ArrayListUnmanaged([]const u8){};
    defer lines.deinit(allocator);

    var start: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        const b = input[i];
        var newline_len: usize = 0;
        if (b == '\r') {
            newline_len = if (i + 1 < input.len and input[i + 1] == '\n') 2 else 1;
        } else if (b == '\n') {
            newline_len = 1;
        }
        if (newline_len > 0) {
            if (i > start) lines.append(allocator, input[start..i]) catch unreachable;
            start = i + newline_len;
            i += newline_len;
            continue;
        }
        i += 1;
    }
    if (start < input.len) lines.append(allocator, input[start..]) catch unreachable;

    var points = std.ArrayListUnmanaged([]usize){};
    defer {
        for (points.items) |row| allocator.free(row);
        points.deinit(allocator);
    }

    var max_y: usize = 0;
    for (lines.items) |line| {
        var buffer: [64]usize = undefined;
        const count = parseNumbers(line, &buffer);
        const row = try allocator.alloc(usize, count);
        for (row, 0..) |*slot, idx| slot.* = buffer[idx];
        var yi: usize = 1;
        while (yi < row.len) : (yi += 2) {
            const y = row[yi];
            if (y > max_y) max_y = y;
        }
        points.append(allocator, row) catch unreachable;
    }

    const height = max_y + 2;
    const width = 2 * height + 1;
    var kind = try allocator.alloc(Kind, width * height);
    @memset(kind, .Air);

    for (points.items) |row| {
        var idx: usize = 0;
        while (idx + 3 < row.len) : (idx += 2) {
            const x1 = row[idx];
            const y1 = row[idx + 1];
            const x2 = row[idx + 2];
            const y2 = row[idx + 3];
            if (x1 == x2) {
                var y = if (y1 < y2) y1 else y2;
                const y_end = if (y1 > y2) y1 else y2;
                while (y <= y_end) : (y += 1) {
                    kind[width * y + x1 + height - 500] = .Stopped;
                }
            } else {
                var x = if (x1 < x2) x1 else x2;
                const x_end = if (x1 > x2) x1 else x2;
                while (x <= x_end) : (x += 1) {
                    kind[width * y1 + x + height - 500] = .Stopped;
                }
            }
        }
    }

    return .{ .width = width, .height = height, .kind = kind };
}

fn simulate(input: Cave, floor: Kind) u32 {
    var cave = input;
    defer std.heap.page_allocator.free(cave.kind);
    var count: u32 = 0;
    const max_stack = cave.kind.len;
    var stack = std.heap.page_allocator.alloc(usize, max_stack) catch unreachable;
    defer std.heap.page_allocator.free(stack);
    var stack_len: usize = 0;
    stack[stack_len] = cave.height;
    stack_len += 1;

    while (stack_len > 0) {
        stack_len -= 1;
        const index = stack[stack_len];
        const down = index + cave.width;
        const left = down - 1;
        const right = down + 1;
        const nexts = [_]usize{ down, left, right };
        var blocked = true;
        for (nexts) |next| {
            const tile = if (next >= cave.kind.len) floor else cave.kind[next];
            if (tile == .Air) {
                stack[stack_len] = index;
                stack_len += 1;
                stack[stack_len] = next;
                stack_len += 1;
                blocked = false;
                break;
            }
            if (tile == .Falling) {
                cave.kind[index] = .Falling;
                blocked = false;
                break;
            }
        }
        if (!blocked) continue;
        cave.kind[index] = .Stopped;
        count += 1;
    }

    return count;
}

fn cloneCave(cave: Cave, allocator: std.mem.Allocator) Cave {
    const kind = allocator.alloc(Kind, cave.kind.len) catch unreachable;
    std.mem.copyForwards(Kind, kind, cave.kind);
    return .{ .width = cave.width, .height = cave.height, .kind = kind };
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const cave = parse(input, allocator) catch unreachable;
    defer allocator.free(cave.kind);

    const p1 = simulate(cloneCave(cave, allocator), .Falling);
    const p2 = simulate(cloneCave(cave, allocator), .Stopped);
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
