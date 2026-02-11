const std = @import("std");

const Result = struct { p1: u32, p2: u64 };

const Entry = struct { key: []const u8, value: u32, bit: u32 };

fn nextToken(line: []const u8, idx: *usize) ?[]const u8 {
    var i = idx.*;
    while (i < line.len and (line[i] < 'a' or line[i] > 'z')) : (i += 1) {}
    if (i >= line.len) {
        idx.* = i;
        return null;
    }
    const start = i;
    while (i < line.len and line[i] >= 'a' and line[i] <= 'z') : (i += 1) {}
    idx.* = i;
    return line[start..i];
}

fn parse(input: []const u8, alloc: std.mem.Allocator) [4]u32 {
    var node = std.StringHashMapUnmanaged([]const []const u8){};
    var kind = std.StringHashMapUnmanaged(bool){};

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, "\r");
        if (line.len == 0) continue;
        var tokens = std.ArrayListUnmanaged([]const u8){};
        defer tokens.deinit(alloc);
        var idx: usize = 0;
        while (nextToken(line, &idx)) |tok| tokens.append(alloc, tok) catch {};
        if (tokens.items.len == 0) continue;
        const key = tokens.items[0];
        const children = tokens.items[1..];
        const owned = alloc.dupe([]const u8, children) catch &[_][]const u8{};
        node.put(alloc, key, owned) catch {};
        kind.put(alloc, key, !std.mem.startsWith(u8, line, "&")) catch {};
    }

    var todo = std.ArrayListUnmanaged(Entry){};
    defer todo.deinit(alloc);
    var numbers = std.ArrayListUnmanaged(u32){};
    defer numbers.deinit(alloc);

    const broadcaster = node.get("broadcaster") orelse &[_][]const u8{};
    for (broadcaster) |start| {
        todo.append(alloc, .{ .key = start, .value = 0, .bit = 1 }) catch {};
    }

    while (todo.items.len > 0) {
        const item = todo.pop() orelse break;
        const children = node.get(item.key) orelse &[_][]const u8{};
        var next_key: ?[]const u8 = null;
        for (children) |child| {
            if (kind.get(child) orelse false) {
                next_key = child;
                break;
            }
        }
        if (next_key) |next| {
            var value = item.value;
            if (children.len == 2) value |= item.bit;
            todo.append(alloc, .{ .key = next, .value = value, .bit = item.bit << 1 }) catch {};
        } else {
            numbers.append(alloc, item.value | item.bit) catch {};
        }
    }

    return .{ numbers.items[0], numbers.items[1], numbers.items[2], numbers.items[3] };
}

pub fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const numbers = parse(input, alloc);

    var pairs: [4][2]u32 = undefined;
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        pairs[i] = .{ numbers[i], 13 - @popCount(numbers[i]) };
    }

    var low: u32 = 5000;
    var high: u32 = 0;
    var n: u32 = 0;
    while (n < 1000) : (n += 1) {
        const rising: u32 = ~n & (n + 1);
        high += 4 * @popCount(rising);
        const falling: u32 = n & ~(n + 1);
        low += 4 * @popCount(falling);
        i = 0;
        while (i < 4) : (i += 1) {
            const number = pairs[i][0];
            const feedback = pairs[i][1];
            var factor = @popCount(rising & number);
            high += factor * (feedback + 3);
            low += factor;
            factor = @popCount(falling & number);
            high += factor * (feedback + 2);
            low += 2 * factor;
        }
    }

    var p2: u64 = 1;
    for (numbers) |v| p2 *= @as(u64, v);
    return .{ .p1 = low * high, .p2 = p2 };
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
