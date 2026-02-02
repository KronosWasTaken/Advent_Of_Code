const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

const THRESHOLD: usize = 0x10000;
const LIMIT1: usize = 2020;
const LIMIT2: usize = 30_000_000;

fn parseNumbers(allocator: std.mem.Allocator, input: []const u8) ![]u32 {
    var list = std.ArrayListUnmanaged(u32){};
    errdefer list.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        if (input[i] < '0' or input[i] > '9') {
            i += 1;
            continue;
        }
        var value: u32 = 0;
        while (i < input.len and input[i] >= '0') : (i += 1) {
            value = value * 10 + @as(u32, input[i] - '0');
        }
        try list.append(allocator, value);
    }

    return list.toOwnedSlice(allocator);
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const numbers = parseNumbers(arena.allocator(), input) catch unreachable;

    const spoken = std.heap.page_allocator.alloc(u32, LIMIT2) catch unreachable;
    defer std.heap.page_allocator.free(spoken);
    @memset(spoken, 0);

    const seen = std.heap.page_allocator.alloc(u64, LIMIT2 / 64) catch unreachable;
    defer std.heap.page_allocator.free(seen);
    @memset(seen, 0);

    var zeroth: u32 = 0;
    var i: usize = 0;
    while (i + 1 < numbers.len) : (i += 1) {
        const value = numbers[i];
        if (value == 0) {
            zeroth = @intCast(i + 1);
        } else {
            spoken[value] = @intCast(i + 1);
        }
    }

    var last: u32 = numbers[numbers.len - 1];
    var part1: u32 = 0;

    @setRuntimeSafety(false);
    i = numbers.len;
    while (i < LIMIT2) : (i += 1) {
        if (i == LIMIT1) {
            part1 = last;
        }

        if (last == 0) {
            const prev = zeroth;
            zeroth = @intCast(i);
            last = if (prev == 0) 0 else @intCast(i - prev);
        } else if (last < THRESHOLD) {
            const prev = spoken[last];
            spoken[last] = @intCast(i);
            last = if (prev == 0) 0 else @intCast(i - prev);
        } else {
            const base = @as(usize, last) >> 6;
            const mask = @as(u64, 1) << @as(u6, @intCast(last & 63));
            if ((seen[base] & mask) == 0) {
                seen[base] |= mask;
                spoken[last] = @intCast(i);
                last = 0;
            } else {
                const prev = spoken[last];
                spoken[last] = @intCast(i);
                last = @intCast(i - prev);
            }
        }
    }

    return .{ .p1 = part1, .p2 = last };
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
