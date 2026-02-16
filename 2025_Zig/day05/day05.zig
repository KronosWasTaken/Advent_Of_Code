const std = @import("std");

const Result = struct { p1: usize, p2: u64 };

const Range = struct { start: u64, end: u64 };

const Input = struct {
    ranges: []Range,
    ids: []u64,
};

pub fn solve(input: []const u8) Result {
    var parsed = parse(input);
    defer std.heap.page_allocator.free(parsed.ranges);
    defer std.heap.page_allocator.free(parsed.ids);

    return .{ .p1 = part1(&parsed), .p2 = part2(&parsed) };
}

fn parse(input: []const u8) Input {
    const allocator = std.heap.page_allocator;
    var split = std.mem.indexOf(u8, input, "\r\n\r\n");
    var sep_len: usize = 4;
    if (split == null) {
        split = std.mem.indexOf(u8, input, "\n\n");
        sep_len = 2;
    }
    const split_idx = split orelse input.len;
    const prefix = input[0..split_idx];
    const suffix = if (split_idx < input.len) input[split_idx + sep_len ..] else input[0..0];

    var ranges = std.ArrayListUnmanaged(Range){};
    var ids = std.ArrayListUnmanaged(u64){};

    parseU64Pairs(prefix, allocator, &ranges);
    parseU64List(suffix, allocator, &ids);

    std.sort.insertion(Range, ranges.items, {}, struct {
        fn lessThan(_: void, a: Range, b: Range) bool {
            return if (a.start == b.start) a.end < b.end else a.start < b.start;
        }
    }.lessThan);
    std.sort.insertion(u64, ids.items, {}, std.sort.asc(u64));

    if (ranges.items.len == 0) {
        return .{ .ranges = &[_]Range{}, .ids = ids.toOwnedSlice(allocator) catch unreachable };
    }

    var write: usize = 0;
    var current = Range{ .start = ranges.items[0].start, .end = ranges.items[0].end + 1 };
    for (ranges.items[1..]) |range| {
        if (range.start < current.end) {
            const next_end = range.end + 1;
            if (next_end > current.end) current.end = next_end;
        } else {
            ranges.items[write] = current;
            write += 1;
            current = .{ .start = range.start, .end = range.end + 1 };
        }
    }
    ranges.items[write] = current;
    write += 1;
    ranges.items.len = write;

    return .{ .ranges = ranges.toOwnedSlice(allocator) catch unreachable, .ids = ids.toOwnedSlice(allocator) catch unreachable };
}

fn parseU64Pairs(input: []const u8, allocator: std.mem.Allocator, ranges: *std.ArrayListUnmanaged(Range)) void {
    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and input[i] < '0') : (i += 1) {}
        if (i >= input.len) break;
        var from: u64 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            from = from * 10 + @as(u64, input[i] - '0');
        }
        while (i < input.len and input[i] < '0') : (i += 1) {}
        var to: u64 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            to = to * 10 + @as(u64, input[i] - '0');
        }
        ranges.append(allocator, .{ .start = from, .end = to }) catch unreachable;
    }
}

fn parseU64List(input: []const u8, allocator: std.mem.Allocator, ids: *std.ArrayListUnmanaged(u64)) void {
    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and input[i] < '0') : (i += 1) {}
        if (i >= input.len) break;
        var value: u64 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            value = value * 10 + @as(u64, input[i] - '0');
        }
        ids.append(allocator, value) catch unreachable;
    }
}

fn part1(parsed: *const Input) usize {
    var sum: usize = 0;
    for (parsed.ranges) |range| {
        sum += position(parsed.ids, range.end) - position(parsed.ids, range.start);
    }
    return sum;
}

fn position(ids: []const u64, value: u64) usize {
    var lo: usize = 0;
    var hi: usize = ids.len;
    while (lo < hi) {
        const mid = (lo + hi) / 2;
        if (ids[mid] < value) {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    return lo;
}

fn part2(parsed: *const Input) u64 {
    var total: u64 = 0;
    for (parsed.ranges) |range| {
        total += range.end - range.start;
    }
    return total;
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
