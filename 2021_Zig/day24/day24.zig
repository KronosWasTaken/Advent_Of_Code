const std = @import("std");

const Result = struct { p1: []const u8, p2: []const u8 };

const Block = union(enum) { Push: i32, Pop: i32 };

const Constraint = struct {
    index: usize,
    value: i32,

    fn min(self: Constraint) i32 {
        return @max(1, 1 + self.value);
    }

    fn max(self: Constraint) i32 {
        return @min(9, 9 + self.value);
    }
};

fn lastSpace(line: []const u8) usize {
    var i: usize = line.len;
    while (i > 0) : (i -= 1) {
        if (line[i - 1] == ' ') return i - 1;
    }
    return 0;
}

fn parse(input: []const u8, allocator: std.mem.Allocator) []Constraint {
    var lines = std.ArrayListUnmanaged([]const u8){};
    defer lines.deinit(allocator);

    var it = std.mem.splitScalar(u8, input, '\n');
    while (it.next()) |raw| {
        const line = std.mem.trimRight(u8, raw, "\r");
        if (line.len > 0) lines.append(allocator, line) catch unreachable;
    }

    const count = lines.items.len / 18;
    var blocks = allocator.alloc(Block, count) catch unreachable;
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const chunk = lines.items[i * 18 .. (i + 1) * 18];
        const div_z = std.fmt.parseInt(i32, chunk[4][lastSpace(chunk[4]) + 1 ..], 10) catch 0;
        if (div_z == 1) {
            const k1 = std.fmt.parseInt(i32, chunk[15][lastSpace(chunk[15]) + 1 ..], 10) catch 0;
            blocks[i] = .{ .Push = k1 };
        } else {
            const k2 = std.fmt.parseInt(i32, chunk[5][lastSpace(chunk[5]) + 1 ..], 10) catch 0;
            blocks[i] = .{ .Pop = k2 };
        }
    }

    var stack = std.ArrayListUnmanaged(Constraint){};
    defer stack.deinit(allocator);
    var constraints = std.ArrayListUnmanaged(Constraint){};
    defer constraints.deinit(allocator);

    i = 0;
    while (i < blocks.len) : (i += 1) {
        switch (blocks[i]) {
            .Push => |value| stack.append(allocator, .{ .index = i, .value = value }) catch unreachable,
            .Pop => |value| {
                var first = stack.pop().?;
                const delta = first.value + value;
                first.value = -delta;
                constraints.append(allocator, first) catch unreachable;
                constraints.append(allocator, .{ .index = i, .value = delta }) catch unreachable;
            },
        }
    }

    std.mem.sortUnstable(Constraint, constraints.items, {}, struct {
        fn less(_: void, a: Constraint, b: Constraint) bool {
            return a.index < b.index;
        }
    }.less);

    return constraints.toOwnedSlice(allocator) catch unreachable;
}

fn toString(constraints: []const Constraint, max: bool, allocator: std.mem.Allocator) []const u8 {
    const out = allocator.alloc(u8, constraints.len) catch unreachable;
    for (constraints, 0..) |c, i| {
        const digit = if (max) c.max() else c.min();
        out[i] = @as(u8, @intCast('0' + digit));
    }
    return out;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const constraints = parse(input, allocator);
    defer allocator.free(constraints);

    const p1 = toString(constraints, true, allocator);
    const p2 = toString(constraints, false, allocator);
    return .{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {s}\n", .{result.p1});
    std.debug.print("Part 2: {s}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
