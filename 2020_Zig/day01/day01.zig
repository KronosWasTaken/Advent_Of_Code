const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

fn parseNumbers(allocator: std.mem.Allocator, input: []const u8) ![]usize {
    var list = std.ArrayListUnmanaged(usize){};
    errdefer list.deinit(allocator);
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        var value: usize = 0;
        while (i < input.len and input[i] >= '0') : (i += 1) {
            value = value * 10 + (input[i] - '0');
        }
        if (value != 0 or (i > 0 and input[i - 1] >= '0')) {
            try list.append(allocator, value);
        }
    }
    return list.toOwnedSlice(allocator);
}

fn twoSum(slice: []const usize, target: usize, hash: []u32, round: u32) ?usize {
    for (slice) |value| {
        if (value < target) {
            const complement = target - value;
            if (hash[value] == round) {
                return value * complement;
            }
            hash[complement] = round;
        }
    }
    return null;
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const numbers = parseNumbers(arena.allocator(), input) catch unreachable;

    var hash = [_]u32{0} ** 2020;
    const p1 = twoSum(numbers, 2020, &hash, 1) orelse unreachable;

    var p2: usize = 0;
    var i: usize = 0;
    while (i + 2 < numbers.len) : (i += 1) {
        const first = numbers[i];
        const round = @as(u32, @intCast(i + 1));
        const target = 2020 - first;
        if (twoSum(numbers[i + 1 ..], target, &hash, round)) |prod| {
            p2 = first * prod;
            break;
        }
    }

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
