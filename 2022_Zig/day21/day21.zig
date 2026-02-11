const std = @import("std");

const Operation = enum { Add, Sub, Mul, Div };

const Monkey = union(enum) {
    Number: i64,
    Result: struct { left: usize, op: Operation, right: usize },
};

const Input = struct {
    root: usize,
    monkeys: []Monkey,
    yell: []i64,
    unknown: []bool,
};

const Result = struct {
    p1: i64,
    p2: i64,
};

fn parse(input: []const u8, allocator: std.mem.Allocator) !Input {
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

    var indices = std.StringHashMap(usize).init(allocator);
    defer indices.deinit();
    for (lines.items, 0..) |line, idx| {
        try indices.put(line[0..4], idx);
    }

    var monkeys = try allocator.alloc(Monkey, lines.items.len);
    const yell = try allocator.alloc(i64, lines.items.len);
    const unknown = try allocator.alloc(bool, lines.items.len);
    @memset(yell, 0);
    @memset(unknown, false);

    for (lines.items, 0..) |line, idx| {
        const expr = line[6..];
        if (expr.len < 11) {
            const value = std.fmt.parseInt(i64, expr, 10) catch 0;
            monkeys[idx] = .{ .Number = value };
        } else {
            const left = indices.get(expr[0..4]).?;
            const right = indices.get(expr[7..11]).?;
            const op = switch (expr[5]) {
                '+' => Operation.Add,
                '-' => Operation.Sub,
                '*' => Operation.Mul,
                '/' => Operation.Div,
                else => unreachable,
            };
            monkeys[idx] = .{ .Result = .{ .left = left, .op = op, .right = right } };
        }
    }

    const root = indices.get("root").?;
    const humn = indices.get("humn").?;

    var input_struct = Input{ .root = root, .monkeys = monkeys, .yell = yell, .unknown = unknown };
    _ = compute(&input_struct, root);
    _ = findUnknown(&input_struct, humn, root);
    return input_struct;
}

fn compute(input: *Input, index: usize) i64 {
    const result = switch (input.monkeys[index]) {
        .Number => |n| n,
        .Result => |r| switch (r.op) {
            .Add => compute(input, r.left) + compute(input, r.right),
            .Sub => compute(input, r.left) - compute(input, r.right),
            .Mul => compute(input, r.left) * compute(input, r.right),
            .Div => @divTrunc(compute(input, r.left), compute(input, r.right)),
        },
    };
    input.yell[index] = result;
    return result;
}

fn findUnknown(input: *Input, humn: usize, index: usize) bool {
    const result = switch (input.monkeys[index]) {
        .Number => humn == index,
        .Result => |r| findUnknown(input, humn, r.left) or findUnknown(input, humn, r.right),
    };
    input.unknown[index] = result;
    return result;
}

fn inverse(input: *const Input, index: usize, value: i64) i64 {
    const root = input.root;
    return switch (input.monkeys[index]) {
        .Number => value,
        .Result => |r| if (index == root) blk: {
            if (input.unknown[r.left]) break :blk inverse(input, r.left, input.yell[r.right]);
            break :blk inverse(input, r.right, input.yell[r.left]);
        } else if (input.unknown[r.left]) switch (r.op) {
            .Add => inverse(input, r.left, value - input.yell[r.right]),
            .Sub => inverse(input, r.left, value + input.yell[r.right]),
            .Mul => inverse(input, r.left, @divTrunc(value, input.yell[r.right])),
            .Div => inverse(input, r.left, value * input.yell[r.right]),
        } else switch (r.op) {
            .Add => inverse(input, r.right, value - input.yell[r.left]),
            .Sub => inverse(input, r.right, input.yell[r.left] - value),
            .Mul => inverse(input, r.right, @divTrunc(value, input.yell[r.left])),
            .Div => inverse(input, r.right, @divTrunc(input.yell[r.left], value)),
        },
    };
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    var parsed = parse(input, allocator) catch unreachable;
    defer {
        allocator.free(parsed.monkeys);
        allocator.free(parsed.yell);
        allocator.free(parsed.unknown);
    }

    return .{ .p1 = parsed.yell[parsed.root], .p2 = inverse(&parsed, parsed.root, -1) };
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
