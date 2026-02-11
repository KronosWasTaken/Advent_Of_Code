const std = @import("std");

const OpKind = enum { Square, Multiply, Add };

const Operation = struct {
    kind: OpKind,
    value: u64,
};

const MonkeyDef = struct {
    items: []u64,
    operation: Operation,
    divisor: u64,
    yes: usize,
    no: usize,
};

const Result = struct {
    p1: u64,
    p2: u64,
};

const Queue = struct {
    list: std.ArrayListUnmanaged(u64),
    start: usize,

    fn init(allocator: std.mem.Allocator, items: []const u64) !Queue {
        var list = std.ArrayListUnmanaged(u64){};
        try list.ensureTotalCapacity(allocator, items.len);
        try list.appendSlice(allocator, items);
        return .{ .list = list, .start = 0 };
    }

    fn deinit(self: *Queue, allocator: std.mem.Allocator) void {
        self.list.deinit(allocator);
    }

    fn len(self: *const Queue) usize {
        return self.list.items.len - self.start;
    }

    fn push(self: *Queue, allocator: std.mem.Allocator, value: u64) void {
        self.list.append(allocator, value) catch unreachable;
    }

    fn compact(self: *Queue) void {
        if (self.start == 0) return;
        const remaining = self.list.items.len - self.start;
        if (remaining > 0) {
            std.mem.copyForwards(u64, self.list.items[0..remaining], self.list.items[self.start..]);
        }
        self.list.shrinkRetainingCapacity(remaining);
        self.start = 0;
    }
};

fn parseNumbers(line: []const u8, out: []u64) usize {
    var count: usize = 0;
    var value: u64 = 0;
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

fn parse(input: []const u8, allocator: std.mem.Allocator) ![]MonkeyDef {
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
            try lines.append(allocator, input[start..i]);
            start = i + newline_len;
            i += newline_len;
            continue;
        }
        i += 1;
    }
    if (start < input.len) try lines.append(allocator, input[start..]);

    var filtered = std.ArrayListUnmanaged([]const u8){};
    defer filtered.deinit(allocator);
    for (lines.items) |line| {
        if (line.len > 0) try filtered.append(allocator, line);
    }

    const monkey_count = (filtered.items.len + 5) / 6;
    var defs = try allocator.alloc(MonkeyDef, monkey_count);

    var m: usize = 0;
    var idx: usize = 0;
    while (idx + 5 < filtered.items.len) : (idx += 6) {
        var buffer: [16]u64 = undefined;
        const item_count = parseNumbers(filtered.items[idx + 1], &buffer);
        const items = try allocator.alloc(u64, item_count);
        for (items, 0..) |*slot, j| slot.* = buffer[j];

        const op_line = filtered.items[idx + 2];
        var operation: Operation = .{ .kind = .Square, .value = 0 };
        if (std.mem.indexOf(u8, op_line, "* old") != null) {
            operation = .{ .kind = .Square, .value = 0 };
        } else if (std.mem.indexOfScalar(u8, op_line, '*') != null) {
            _ = parseNumbers(op_line, &buffer);
            operation = .{ .kind = .Multiply, .value = buffer[0] };
        } else {
            _ = parseNumbers(op_line, &buffer);
            operation = .{ .kind = .Add, .value = buffer[0] };
        }

        _ = parseNumbers(filtered.items[idx + 3], &buffer);
        const divisor = buffer[0];
        _ = parseNumbers(filtered.items[idx + 4], &buffer);
        const yes = @as(usize, @intCast(buffer[0]));
        _ = parseNumbers(filtered.items[idx + 5], &buffer);
        const no = @as(usize, @intCast(buffer[0]));

        defs[m] = .{ .items = items, .operation = operation, .divisor = divisor, .yes = yes, .no = no };
        m += 1;
    }

    return defs[0..m];
}

fn initMonkeys(defs: []const MonkeyDef, allocator: std.mem.Allocator) ![]Queue {
    var monkeys = try allocator.alloc(Queue, defs.len);
    for (defs, 0..) |def, i| {
        monkeys[i] = try Queue.init(allocator, def.items);
    }
    return monkeys;
}

fn play(defs: []const MonkeyDef, rounds: usize, divide: bool, allocator: std.mem.Allocator) u64 {
    var monkeys = initMonkeys(defs, allocator) catch unreachable;
    defer {
        for (monkeys) |*m| m.deinit(allocator);
        allocator.free(monkeys);
    }

    var counts = allocator.alloc(u64, defs.len) catch unreachable;
    defer allocator.free(counts);
    @memset(counts, 0);

    var modulus: u64 = 1;
    if (!divide) {
        for (defs) |def| modulus *= def.divisor;
    }

    var round: usize = 0;
    while (round < rounds) : (round += 1) {
        for (defs, 0..) |def, mi| {
            var queue = &monkeys[mi];
            const start_len = queue.len();
            var idx: usize = 0;
            while (idx < start_len) : (idx += 1) {
                var worry = queue.list.items[queue.start + idx];
                worry = switch (def.operation.kind) {
                    .Square => worry * worry,
                    .Multiply => worry * def.operation.value,
                    .Add => worry + def.operation.value,
                };
                if (divide) {
                    worry /= 3;
                } else {
                    worry %= modulus;
                }

                const to = if (worry % def.divisor == 0) def.yes else def.no;
                monkeys[to].push(allocator, worry);
                counts[mi] += 1;
            }

            queue.start += start_len;
            if (queue.start * 2 >= queue.list.items.len) {
                queue.compact();
            }
        }
    }

    var best1: u64 = 0;
    var best2: u64 = 0;
    for (counts) |c| {
        if (c > best1) {
            best2 = best1;
            best1 = c;
        } else if (c > best2) {
            best2 = c;
        }
    }
    return best1 * best2;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const defs = parse(input, allocator) catch unreachable;
    defer {
        for (defs) |def| allocator.free(def.items);
        allocator.free(defs);
    }

    return .{ .p1 = play(defs, 20, true, allocator), .p2 = play(defs, 10_000, false, allocator) };
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
