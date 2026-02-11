const std = @import("std");

const Move = struct {
    amount: usize,
    from: usize,
    to: usize,
};

const Result = struct {
    p1: []const u8,
    p2: []const u8,
};

const Line = struct { start: usize, end: usize };

fn findSplit(input: []const u8) usize {
    var line_start: usize = 0;
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
            if (i == line_start) return i + newline_len;
            line_start = i + newline_len;
            i += newline_len;
            continue;
        }
        i += 1;
    }
    return input.len;
}

fn parseStacks(prefix: []const u8, allocator: std.mem.Allocator) ![]std.ArrayListUnmanaged(u8) {
    var lines = std.ArrayListUnmanaged(Line){};
    defer lines.deinit(allocator);

    var line_start: usize = 0;
    var i: usize = 0;
    while (i < prefix.len) {
        const b = prefix[i];
        var newline_len: usize = 0;
        if (b == '\r') {
            newline_len = if (i + 1 < prefix.len and prefix[i + 1] == '\n') 2 else 1;
        } else if (b == '\n') {
            newline_len = 1;
        }
        if (newline_len > 0) {
            if (i > line_start) {
                try lines.append(allocator, .{ .start = line_start, .end = i });
            }
            line_start = i + newline_len;
            i += newline_len;
            continue;
        }
        i += 1;
    }
    if (line_start < prefix.len) {
        try lines.append(allocator, .{ .start = line_start, .end = prefix.len });
    }

    const width: usize = if (lines.items.len > 0) ((lines.items[0].end - lines.items[0].start + 1) / 4) else 0;
    var stacks = try allocator.alloc(std.ArrayListUnmanaged(u8), width);
    for (stacks) |*stack| stack.* = .{};

    if (lines.items.len <= 1) return stacks;
    var row_index: usize = lines.items.len - 2;
    while (true) {
        const line = lines.items[row_index];
        const row = prefix[line.start..line.end];
        var col: usize = 0;
        var pos: usize = 1;
        while (pos < row.len) : (pos += 4) {
            const ch = row[pos];
            if (ch >= 'A' and ch <= 'Z') {
                try stacks[col].append(allocator, ch);
            }
            col += 1;
        }
        if (row_index == 0) break;
        row_index -= 1;
    }

    return stacks;
}

fn countLines(input: []const u8) usize {
    var count: usize = 0;
    var line_start: usize = 0;
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
            if (i > line_start) count += 1;
            line_start = i + newline_len;
            i += newline_len;
            continue;
        }
        i += 1;
    }
    if (line_start < input.len) count += 1;
    return count;
}

fn parseMoves(suffix: []const u8, allocator: std.mem.Allocator) ![]Move {
    const move_count = countLines(suffix);
    var moves = try allocator.alloc(Move, move_count);
    var move_index: usize = 0;

    var value: usize = 0;
    var in_number = false;
    var count: usize = 0;
    var temp: [3]usize = .{ 0, 0, 0 };
    var last_was_cr = false;

    var i: usize = 0;
    while (i <= suffix.len) : (i += 1) {
        const b: u8 = if (i < suffix.len) suffix[i] else '\n';
        if (last_was_cr and b == '\n') {
            last_was_cr = false;
            continue;
        }
        last_was_cr = b == '\r';
        if (b >= '0' and b <= '9') {
            value = value * 10 + (b - '0');
            in_number = true;
            continue;
        }
        if (in_number) {
            temp[count] = value;
            count += 1;
            value = 0;
            in_number = false;
            if (count == 3) {
                moves[move_index] = .{ .amount = temp[0], .from = temp[1] - 1, .to = temp[2] - 1 };
                move_index += 1;
                count = 0;
            }
        }
    }

    return moves[0..move_index];
}

fn cloneStacks(stacks: []std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator) ![]std.ArrayListUnmanaged(u8) {
    var clone = try allocator.alloc(std.ArrayListUnmanaged(u8), stacks.len);
    for (stacks, 0..) |stack, i| {
        clone[i] = .{};
        try clone[i].ensureTotalCapacity(allocator, stack.items.len);
        try clone[i].appendSlice(allocator, stack.items);
    }
    return clone;
}

fn play(stacks: []std.ArrayListUnmanaged(u8), moves: []const Move, reverse: bool, allocator: std.mem.Allocator) ![]u8 {
    for (moves) |mv| {
        const from = &stacks[mv.from];
        const to = &stacks[mv.to];
        const start = from.items.len - mv.amount;
        if (reverse) {
            var idx: usize = from.items.len;
            while (idx > start) {
                idx -= 1;
                try to.append(allocator, from.items[idx]);
            }
            from.shrinkRetainingCapacity(start);
        } else {
            try to.appendSlice(allocator, from.items[start..]);
            from.shrinkRetainingCapacity(start);
        }
    }

    var out = try allocator.alloc(u8, stacks.len);
    for (stacks, 0..) |stack, i| {
        out[i] = if (stack.items.len > 0) stack.items[stack.items.len - 1] else ' ';
    }
    return out;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const split = findSplit(input);
    const prefix = input[0..split];
    const suffix = if (split < input.len) input[split..] else input[0..0];

    const stacks = parseStacks(prefix, allocator) catch unreachable;
    defer {
        for (stacks) |*stack| stack.deinit(allocator);
        allocator.free(stacks);
    }

    const moves = parseMoves(suffix, allocator) catch unreachable;
    defer allocator.free(moves);

    const stack1 = cloneStacks(stacks, allocator) catch unreachable;
    defer {
        for (stack1) |*stack| stack.deinit(allocator);
        allocator.free(stack1);
    }
    const stack2 = cloneStacks(stacks, allocator) catch unreachable;
    defer {
        for (stack2) |*stack| stack.deinit(allocator);
        allocator.free(stack2);
    }

    const p1 = play(stack1, moves, true, allocator) catch unreachable;
    const p2 = play(stack2, moves, false, allocator) catch unreachable;

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
