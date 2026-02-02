const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

fn parseNumbers(allocator: std.mem.Allocator, input: []const u8) ![]u16 {
    var list = std.ArrayListUnmanaged(u16){};
    errdefer list.deinit(allocator);
    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and (input[i] == '\n' or input[i] == '\r')) : (i += 1) {}
        if (i >= input.len) break;
        var value: u16 = 0;
        while (i < input.len and input[i] >= '0') : (i += 1) {
            value = value * 10 + @as(u16, input[i] - '0');
        }
        try list.append(allocator, value);
    }
    return list.toOwnedSlice(allocator);
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const adapters = parseNumbers(arena.allocator(), input) catch unreachable;

    std.sort.heap(u16, adapters, {}, comptime std.sort.asc(u16));

    var diffs = [_]u64{0} ** 4;
    diffs[3] = 1;
    var prev: u16 = 0;
    for (adapters) |value| {
        const diff = value - prev;
        prev = value;
        diffs[diff] += 1;
    }

    const max_value = adapters[adapters.len - 1];
    var ways = arena.allocator().alloc(u64, max_value + 1) catch unreachable;
    @memset(ways, 0);
    ways[0] = 1;

    for (adapters) |value| {
        const idx = @as(usize, value);
        const a = if (idx >= 1) ways[idx - 1] else 0;
        const b = if (idx >= 2) ways[idx - 2] else 0;
        const c = if (idx >= 3) ways[idx - 3] else 0;
        ways[idx] = a + b + c;
    }

    return .{ .p1 = diffs[1] * diffs[3], .p2 = ways[max_value] };
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
